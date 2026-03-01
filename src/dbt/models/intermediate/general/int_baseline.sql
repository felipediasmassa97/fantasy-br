/*
Baseline Ability (True Talent Level)

Calculates expected baseline points per player using Bayesian shrinkage:
  weight_this_season = matches_this_season / (matches_this_season + k)
  baseline = weight_this * player_pts_avg_this_season + (1 - weight_this) * prior

Prior:
- Returning players (>=5 matches, >30% availability last season): player_pts_avg_last_season
- Rookies / insufficient history: position_pts_avg_last_season
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- This season averages per player up to each round
player_avg_this_season as (
    select
        r.as_of_round_id,
        p.id,
        p.name,
        p.club,
        p.club_logo_url,
        p.position,
        avg(if(p.has_played, p.pts_round, null)) as player_pts_avg_this_season,
        countif(p.has_played = true) as matches_this_season,
        count(*) as rounds_listed_this_season
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where p.season = 2026 and p.round_id <= r.as_of_round_id
    group by r.as_of_round_id, p.id, p.name, p.club, p.club_logo_url, p.position
),

-- Last season averages per player (full season 2025)
player_avg_last_season as (
    select
        id,
        position,
        avg(if(has_played, pts_round, null)) as player_pts_avg_last_season,
        countif(has_played = true) as matches_last_season,
        countif(has_played = true) / count(*) as availability_last_season
    from {{ ref('int_players') }}
    where season = 2025
    group by id, position
),

-- Position average from last season (for rookies)
-- Only include players with >= 5 matches AND > 30% availability
position_avg_last_season as (
    select
        position,
        avg(player_pts_avg_last_season) as position_pts_avg_last_season
    from player_avg_last_season
    where matches_last_season >= 5 and availability_last_season > 0.30
    group by position
),


-- Combine and calculate stabilized points using shrinkage (baseline)
combined as (
    select
        ts.as_of_round_id,
        ts.id,
        ts.name,
        ts.club,
        ts.club_logo_url,
        ts.position,
        ts.player_pts_avg_this_season,
        ts.matches_this_season,
        ts.rounds_listed_this_season,
        ls.player_pts_avg_last_season,
        ls.matches_last_season,
        ls.availability_last_season,
        pa.position_pts_avg_last_season,
        -- Flag: player qualifies as having last season data
        (ls.matches_last_season >= 5 and ls.availability_last_season > 0.30) as has_last_season_data
    from player_avg_this_season as ts
    left join player_avg_last_season as ls on ts.id = ls.id
    left join position_avg_last_season as pa on ts.position = pa.position
)

select
    as_of_round_id,
    id,
    name,
    club,
    club_logo_url,
    position,
    player_pts_avg_this_season,
    matches_this_season,
    rounds_listed_this_season,
    player_pts_avg_last_season,
    matches_last_season,
    availability_last_season,
    position_pts_avg_last_season,
    has_last_season_data,
    -- Stabilized points using shrinkage (baseline)
    -- See macros/shrink_blend.sql
    -- prior = last_season_avg (returning) or position_avg (rookie)
    case
        when has_last_season_data
            then {{ shrink_blend('matches_this_season', 'player_pts_avg_this_season', 'player_pts_avg_last_season') }}
        else
            {{
                shrink_blend(
                    'matches_this_season',
                    'player_pts_avg_this_season',
                    'coalesce(position_pts_avg_last_season, player_pts_avg_this_season)'
                )
            }}
    end as baseline_pts,
    case
        when has_last_season_data then 'weighted_seasons'
        else 'rookie_shrinkage'
    end as shrinking_method,
    -- Shrinkage weight: grows from 0 toward 1 as matches_this_season increases
    case
        when player_pts_avg_this_season is null then 0.0
        else {{ shrink_weight('matches_this_season') }}
    end as shrinking_weight_this_season
from combined
