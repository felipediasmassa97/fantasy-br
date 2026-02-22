{{ config(materialized='view') }}

/*
MAP Component 1: Baseline Ability

Calculates expected baseline points per player:
- Returning players (>=5 matches, >30% availability last season):
  - With this season data: 0.6 * last_season_avg + 0.4 * this_season_avg
  - Without this season data: last_season_avg
- Rookies:
  - With this season data: 0.7 * this_season_avg + 0.3 * position_avg_last_season
  - Without this season data: position_avg_last_season
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Last season averages per player (full season 2025)
last_season_player_avg as (
    select
        id,
        position,
        avg(if(has_played, pts_round, null)) as pts_avg_last_season,
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
        avg(pts_avg_last_season) as position_pts_avg
    from last_season_player_avg
    where matches_last_season >= 5 and availability_last_season > 0.30
    group by position
),

-- This season averages per player up to each round
this_season_player_avg as (
    select
        r.as_of_round_id,
        p.id,
        p.name,
        p.club,
        p.club_logo_url,
        p.position,
        avg(if(p.has_played, p.pts_round, null)) as pts_avg_this_season,
        countif(p.has_played = true) as matches_this_season
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026 and p.round_id <= r.as_of_round_id
    group by r.as_of_round_id, p.id, p.name, p.club, p.club_logo_url, p.position
),

-- Combine and calculate baseline
combined as (
    select
        ts.as_of_round_id,
        ts.id,
        ts.name,
        ts.club,
        ts.club_logo_url,
        ts.position,
        ts.pts_avg_this_season,
        ts.matches_this_season,
        ls.pts_avg_last_season,
        ls.matches_last_season,
        ls.availability_last_season,
        pa.position_pts_avg,
        -- Flag: player qualifies as having last season data
        (ls.matches_last_season >= 5 and ls.availability_last_season > 0.30) as has_last_season_data
    from this_season_player_avg ts
    left join last_season_player_avg ls on ts.id = ls.id
    left join position_avg_last_season pa on ts.position = pa.position
)

select
    as_of_round_id,
    id,
    name,
    club,
    club_logo_url,
    position,
    pts_avg_this_season,
    matches_this_season,
    pts_avg_last_season,
    matches_last_season,
    availability_last_season,
    position_pts_avg,
    has_last_season_data,
    case
        when has_last_season_data then
            case
                when pts_avg_this_season is null then pts_avg_last_season
                else 0.6 * pts_avg_last_season + 0.4 * pts_avg_this_season
            end
        else
            case
                when pts_avg_this_season is null then position_pts_avg
                else 0.7 * pts_avg_this_season + 0.3 * position_pts_avg
            end
    end as baseline_pts,
    case
        when has_last_season_data then 'weighted_seasons'
        else 'rookie_shrinkage'
    end as baseline_method
from combined
