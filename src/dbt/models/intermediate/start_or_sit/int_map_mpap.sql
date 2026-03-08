/*
MAP Component 4: MPAP (Matchup Points Allowed by Position)

MPAP measures how many fantasy points the upcoming opponent allows to a specific position.
Not "is this defense good?" but "How well does this club defend against this type of player?"
Uses both this-season and last-season data, blended via sample-size shrinkage.

Calculation:
1. This season: avg points conceded by opponent to position (all matches up to as_of_round)
2. Last season: avg points conceded by opponent to position (full season 2025)
3. Blended: shrinkage-weighted average (k=5 threshold for full this-season confidence)
4. mpap_ratio = blended / league_avg (pre-clamp)
5. mpap_multiplier = clamp(mpap_ratio, 0.85, 1.20) (asymmetric to favor weak opponents)
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

player_clubs as (
    select
        id as player_id,
        any_value(club_id having max round_id) as club_id
    from {{ ref('int_players') }}
    where season = 2026
    group by id
),

-- Next match for each club at each as_of_round (looking at as_of_round_id + 1)
next_match as (
    select
        r.as_of_round_id,
        m.club_home_id as club_id,
        m.club_away_id as opponent_id,
        true as is_home_next
    from all_rounds as r
    inner join {{ ref('int_matches') }} as m
        on m.season = 2026 and m.round_id = r.as_of_round_id + 1
    union all
    select
        r.as_of_round_id,
        m.club_away_id as club_id,
        m.club_home_id as opponent_id,
        false as is_home_next
    from all_rounds as r
    inner join {{ ref('int_matches') }} as m
        on m.season = 2026 and m.round_id = r.as_of_round_id + 1
),

-- This season: avg points conceded per opponent per position (all matches up to as_of_round)
-- "conceding club" = the opponent that allowed the points
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

-- Last season: avg points conceded per opponent per position (full season 2025)
conceded_last_season as (
    select
        p.opponent_id as conceding_club_id,
        p.position,
        avg(if(p.has_played, p.pts_round, null)) as pts_allowed_last_season_avg,
        count(distinct if(p.has_played, p.round_id, null)) as matches_last_season
    from {{ ref('int_players') }} as p
    where
        p.season = 2025
        and p.opponent_id is not null
    group by p.opponent_id, p.position
),

-- League average points per position (this season up to each round)
league_avg_by_position as (
    select
        r.as_of_round_id,
        p.position,
        avg(if(p.has_played, p.pts_round, null)) as league_avg_pts
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where p.season = 2026 and p.round_id <= r.as_of_round_id
    group by r.as_of_round_id, p.position
)

select
    b.as_of_round_id,
    b.id,
    b.position,
    nm.opponent_id,
    nm.is_home_next,
    -- Opponent club name for display
    oc.abbreviation as opponent_club,
    oc.logo_url as opponent_logo_url,
    -- Concession data (this season, last season and league average)
    ct.pts_allowed_this_season_avg,
    cl.pts_allowed_last_season_avg,
    lap.league_avg_pts,
    coalesce(ct.matches_this_season, 0) as matches_this_season,
    coalesce(cl.matches_last_season, 0) as matches_last_season,
    -- Blended concession average with shrinkage (k=5 matches for full this-season confidence)
    case
        when ct.pts_allowed_this_season_avg is null and cl.pts_allowed_last_season_avg is null then null
        when cl.pts_allowed_last_season_avg is null then ct.pts_allowed_this_season_avg
        when ct.pts_allowed_this_season_avg is null then cl.pts_allowed_last_season_avg
        else
            -- If player has 5 or more matches this season, use this season avg
            -- If no matches this season, use last season avg
            -- If in between, blend them with a shrinkage factor that increases with more matches this season
            least(coalesce(ct.matches_this_season, 0) / 5.0, 1.0) * ct.pts_allowed_this_season_avg
            + (1.0 - least(coalesce(ct.matches_this_season, 0) / 5.0, 1.0)) * cl.pts_allowed_last_season_avg
    end as pts_allowed_avg,
    -- MPAP ratio: blended / league_avg (pre-clamp, for debugging)
    case
        when lap.league_avg_pts is null or lap.league_avg_pts = 0 then null
        when ct.pts_allowed_this_season_avg is null and cl.pts_allowed_last_season_avg is null then null
        else (
            case
                when cl.pts_allowed_last_season_avg is null then ct.pts_allowed_this_season_avg
                when ct.pts_allowed_this_season_avg is null then cl.pts_allowed_last_season_avg
                else
                    least(coalesce(ct.matches_this_season, 0) / 5.0, 1.0) * ct.pts_allowed_this_season_avg
                    + (1.0 - least(coalesce(ct.matches_this_season, 0) / 5.0, 1.0)) * cl.pts_allowed_last_season_avg
            end
        ) / lap.league_avg_pts
    end as mpap_ratio,
    -- MPAP multiplier: clamped 0.85 to 1.20 (post-clamp)
    case
        when lap.league_avg_pts is null or lap.league_avg_pts = 0 then null
        when ct.pts_allowed_this_season_avg is null and cl.pts_allowed_last_season_avg is null then null
        else greatest(0.85, least(1.20, (
            case
                when cl.pts_allowed_last_season_avg is null then ct.pts_allowed_this_season_avg
                when ct.pts_allowed_this_season_avg is null then cl.pts_allowed_last_season_avg
                else
                    least(coalesce(ct.matches_this_season, 0) / 5.0, 1.0) * ct.pts_allowed_this_season_avg
                    + (1.0 - least(coalesce(ct.matches_this_season, 0) / 5.0, 1.0)) * cl.pts_allowed_last_season_avg
            end
        ) / lap.league_avg_pts))
    end as mpap_multiplier
from {{ ref('int_baseline') }} as b
-- Get player's current club to find next opponent
left join player_clubs as plc on b.id = plc.player_id
left join next_match as nm
    on b.as_of_round_id = nm.as_of_round_id and plc.club_id = nm.club_id
-- Opponent name
left join {{ ref('stg_clubs') }} as oc on nm.opponent_id = oc.id
-- This-season concession
left join conceded_this_season as ct
    on
        b.as_of_round_id = ct.as_of_round_id
        and nm.opponent_id = ct.conceding_club_id
        and b.position = ct.position
-- Last-season concession
left join conceded_last_season as cl
    on
        nm.opponent_id = cl.conceding_club_id
        and b.position = cl.position
-- League average
left join league_avg_by_position as lap
    on
        b.as_of_round_id = lap.as_of_round_id
        and b.position = lap.position
