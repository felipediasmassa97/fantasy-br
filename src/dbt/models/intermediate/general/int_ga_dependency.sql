/*
G/A Dependency: Goal/Assist Share of Total Points

Measures how reliant a player's scoring is on goals and assists (volatile events)
vs. consistent base actions (tackles, fouls, saves, etc.).

High G/A dependency = points are more volatile and regression-prone.
Low G/A dependency = points come from stable base actions.

Computed per player per as_of_round (this season only).
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Aggregate per player: total points vs G/A points
player_ga as (
    select
        r.as_of_round_id,
        p.id,
        sum(if(p.has_played, p.pts_round, null)) as total_pts,
        sum(if(p.has_played, p.pts_round - p.base_round, null)) as ga_pts,
        sum(if(p.has_played, p.base_round, null)) as base_pts,
        countif(p.has_played) as games_played
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where
        p.season = 2026
        and p.round_id <= r.as_of_round_id
    group by r.as_of_round_id, p.id
)

select
    as_of_round_id,
    id,
    total_pts,
    ga_pts,
    base_pts,
    games_played,
    -- G/A share: fraction of total points from goals + assists
    -- Range 0-1 (can exceed 1 if base_pts is negative and total is still positive)
    case
        when total_pts is null or total_pts = 0 then null
        else ga_pts / total_pts
    end as ga_share
from player_ga
