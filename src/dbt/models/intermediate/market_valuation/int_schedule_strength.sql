{{ config(materialized='view') }}
/*
Schedule Strength (MPAP-based)

For each player at each as_of_round, evaluates upcoming opponents
using blended MPAP (Matchup Points Allowed by Position):
  - Overall: next 10 matches (any venue)
  - Home:    next 5 home matches
  - Away:    next 5 away matches

A higher schedule_strength means easier upcoming opponents (they allow
more fantasy points to this player's position).

Calculation per future opponent:
1. This season: avg points conceded by that club to position (up to as_of_round)
2. Last season: full-season average for same club and position
3. Blended: shrinkage-weighted (k=5)
4. Average blended MPAP across the window = schedule_strength
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

-- All future matches in the season (no round limit — ranking handles windows)
future_matches as (
    select
        r.as_of_round_id,
        m.club_home_id as club_id,
        m.club_away_id as opponent_id,
        m.round_id as future_round_id,
        true as is_home
    from all_rounds as r
    inner join {{ ref('int_matches') }} as m
        on
            m.season = 2026
            and r.as_of_round_id < m.round_id
    union all
    select
        r.as_of_round_id,
        m.club_away_id as club_id,
        m.club_home_id as opponent_id,
        m.round_id as future_round_id,
        false as is_home
    from all_rounds as r
    inner join {{ ref('int_matches') }} as m
        on
            m.season = 2026
            and r.as_of_round_id < m.round_id
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
),

-- Rank opponents: overall (next N) and within venue (next N home / away)
opponent_mpap_ranked as (
    select
        *,
        row_number() over (
            partition by as_of_round_id, id
            order by future_round_id
        ) as overall_rank,
        row_number() over (
            partition by as_of_round_id, id, is_home
            order by future_round_id
        ) as venue_rank
    from opponent_mpap_detail
    where opponent_mpap is not null
)

select
    as_of_round_id,
    id,
    position,
    -- Overall: next 10 matches
    avg(if(overall_rank <= 10, opponent_mpap, null)) as schedule_strength,
    countif(overall_rank <= 10) as opponents_evaluated,
    string_agg(
        if(
            overall_rank <= 10,
            opponent_club || ' (R' || cast(future_round_id as string) || ')',
            null
        ),
        ', '
        order by future_round_id
    ) as upcoming_opponents,
    -- Home: next 5 home matches
    avg(
        if(is_home and venue_rank <= 5, opponent_mpap, null)
    ) as schedule_strength_home,
    countif(is_home and venue_rank <= 5) as opponents_evaluated_home,
    string_agg(
        if(
            is_home and venue_rank <= 5,
            opponent_club || ' (R' || cast(future_round_id as string) || ')',
            null
        ),
        ', '
        order by future_round_id
    ) as upcoming_opponents_home,
    -- Away: next 5 away matches
    avg(
        if(not is_home and venue_rank <= 5, opponent_mpap, null)
    ) as schedule_strength_away,
    countif(not is_home and venue_rank <= 5) as opponents_evaluated_away,
    string_agg(
        if(
            not is_home and venue_rank <= 5,
            opponent_club || ' (R' || cast(future_round_id as string) || ')',
            null
        ),
        ', '
        order by future_round_id
    ) as upcoming_opponents_away
from opponent_mpap_ranked
group by as_of_round_id, id, position
