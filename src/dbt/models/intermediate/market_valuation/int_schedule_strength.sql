{{ config(materialized='view') }}
/*
Schedule Strength (MPAP-based)

For each player at each as_of_round, evaluates the next 10 opponents
using blended MPAP (Matchup Points Allowed by Position).

A higher schedule_strength means easier upcoming opponents (they allow
more fantasy points to this player's position).

Calculation per future opponent:
1. This season: avg points conceded by that club to position (up to as_of_round)
2. Last season: full-season average for same club and position
3. Blended: shrinkage-weighted (k=5)
4. Average blended MPAP across up to 10 future opponents = schedule_strength

# fixit materialize as ephemeral, not view
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

player_clubs as (
    select distinct
        id as player_id,
        club_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Future matches: for each as_of_round, list opponents for rounds +1 to +10
future_matches as (
    select
        r.as_of_round_id,
        m.club_home_id as club_id,
        m.club_away_id as opponent_id,
        m.round_id as future_round_id,
        true as is_home
    from all_rounds as r
    inner join {{ ref('stg_matches') }} as m
        on
            m.season = 2026
            and r.as_of_round_id < m.round_id
            and m.round_id <= r.as_of_round_id + 10
    union all
    select
        r.as_of_round_id,
        m.club_away_id as club_id,
        m.club_home_id as opponent_id,
        m.round_id as future_round_id,
        false as is_home
    from all_rounds as r
    inner join {{ ref('stg_matches') }} as m
        on
            m.season = 2026
            and r.as_of_round_id < m.round_id
            and m.round_id <= r.as_of_round_id + 10
),

-- This season: avg points conceded per opponent per position
conceded_this_season as (
    select
        r.as_of_round_id,
        p.opponent_id as conceding_club_id,
        p.position,
        avg(if(p.has_played, p.pts_round, null)) as pts_allowed_this_season_avg,
        count(distinct if(p.has_played, p.round_id, null)) as matches_this_season
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where
        p.season = 2026
        and p.round_id <= r.as_of_round_id
        and p.opponent_id is not null
    group by r.as_of_round_id, p.opponent_id, p.position
),

-- Last season: avg points conceded per opponent per position
conceded_last_season as (
    select
        p.opponent_id as conceding_club_id,
        p.position,
        avg(if(p.has_played, p.pts_round, null)) as pts_allowed_last_season_avg
    from {{ ref('int_players') }} as p
    where
        p.season = 2025
        and p.opponent_id is not null
    group by p.opponent_id, p.position
),

-- Per-opponent MPAP for each player's future matchups
opponent_mpap_detail as (
    select
        b.as_of_round_id,
        b.id,
        b.position,
        fm.future_round_id,
        fm.opponent_id,
        fm.is_home,
        oc.abbreviation as opponent_club,
        -- Blended MPAP (same shrinkage as int_map_mpap, k=5)
        case
            when
                ct.pts_allowed_this_season_avg is null
                and cl.pts_allowed_last_season_avg is null
                then null
            when cl.pts_allowed_last_season_avg is null
                then ct.pts_allowed_this_season_avg
            when ct.pts_allowed_this_season_avg is null
                then cl.pts_allowed_last_season_avg
            else
                least(coalesce(ct.matches_this_season, 0) / 5.0, 1.0)
                * ct.pts_allowed_this_season_avg
                + (1.0 - least(coalesce(ct.matches_this_season, 0) / 5.0, 1.0))
                * cl.pts_allowed_last_season_avg
        end as opponent_mpap
    from {{ ref('int_baseline') }} as b
    left join player_clubs as plc on b.id = plc.player_id
    inner join future_matches as fm
        on b.as_of_round_id = fm.as_of_round_id and plc.club_id = fm.club_id
    left join {{ ref('stg_clubs') }} as oc on fm.opponent_id = oc.id
    left join conceded_this_season as ct
        on
            b.as_of_round_id = ct.as_of_round_id
            and fm.opponent_id = ct.conceding_club_id
            and b.position = ct.position
    left join conceded_last_season as cl
        on
            fm.opponent_id = cl.conceding_club_id
            and b.position = cl.position
)

select
    as_of_round_id,
    id,
    position,
    -- Average blended MPAP across future opponents (higher = easier schedule)
    avg(opponent_mpap) as schedule_strength,
    count(*) as opponents_evaluated,
    -- Detail: concatenated list of upcoming opponents for display
    string_agg(
        opponent_club || ' (R' || cast(future_round_id as string) || ')',
        ', '
        order by future_round_id
    ) as upcoming_opponents
from opponent_mpap_detail
where opponent_mpap is not null
group by as_of_round_id, id, position
