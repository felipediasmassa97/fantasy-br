/*
MAP Component 3: Home/Away Context

Calculates venue adjustments based on historical home/away performance:
- With both seasons: 0.7 * last_season_split + 0.3 * this_season_split
- Only last season: last_season_split (or overall last season avg)
- Only this season: this_season_split (or overall this season avg)
- venue_multiplier = [home|away]_avg / baseline_pts
- Clamped between 0.85 and 1.15 (+-15% max impact)

# fixit as player has more this season data, increase weight of this season avg - use factor like shrinkage factor, which ammortizes as matches get closer to 10
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Last season home/away splits (full season 2025)
last_season_home_away_avg as (
    select
        id,
        avg(if(has_played and is_home = true, pts_round, null)) as pts_avg_home_last_season,
        avg(if(has_played and is_home = false, pts_round, null)) as pts_avg_away_last_season,
        countif(has_played = true and is_home = true) as matches_home_last_season,
        countif(has_played = true and is_home = false) as matches_away_last_season
    from {{ ref('int_players') }}
    where season = 2025
    group by id
),

-- This season home/away splits per round
this_season_home_away_avg as (
    select
        r.as_of_round_id,
        p.id,
        avg(if(p.has_played and p.is_home = true, p.pts_round, null)) as pts_avg_home_this_season,
        avg(if(p.has_played and p.is_home = false, p.pts_round, null)) as pts_avg_away_this_season,
        countif(p.has_played = true and p.is_home = true) as matches_home_this_season,
        countif(p.has_played = true and p.is_home = false) as matches_away_this_season
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where p.season = 2026 and p.round_id <= r.as_of_round_id
    group by r.as_of_round_id, p.id
),

-- Combine splits with baseline
combined as (
    select
        b.as_of_round_id,
        b.id,
        b.baseline_pts,
        b.pts_avg_last_season,
        b.pts_avg_this_season,
        lha.pts_avg_home_last_season,
        lha.pts_avg_away_last_season,
        lha.matches_home_last_season,
        lha.matches_away_last_season,
        tha.pts_avg_home_this_season,
        tha.pts_avg_away_this_season,
        tha.matches_home_this_season,
        tha.matches_away_this_season
    from {{ ref('int_map_baseline') }} as b
    left join last_season_home_away_avg as lha on b.id = lha.id
    left join this_season_home_away_avg as tha on b.as_of_round_id = tha.as_of_round_id and b.id = tha.id
),

-- Calculate blended averages
with_averages as (
    select
        *,
        -- Blended home/away averages (70% last season + 30% this season)
        -- Falls back to available data when one season is missing
        case
            when pts_avg_home_this_season is null and pts_avg_this_season is null
                then
                    coalesce(pts_avg_home_last_season, pts_avg_last_season)
            when pts_avg_home_last_season is null and pts_avg_last_season is null
                then
                    coalesce(pts_avg_home_this_season, pts_avg_this_season)
            else
                0.7 * coalesce(pts_avg_home_last_season, pts_avg_last_season)
                + 0.3 * coalesce(pts_avg_home_this_season, pts_avg_this_season)
        end as home_avg,
        case
            when pts_avg_away_this_season is null and pts_avg_this_season is null
                then
                    coalesce(pts_avg_away_last_season, pts_avg_last_season)
            when pts_avg_away_last_season is null and pts_avg_last_season is null
                then
                    coalesce(pts_avg_away_this_season, pts_avg_this_season)
            else
                0.7 * coalesce(pts_avg_away_last_season, pts_avg_last_season)
                + 0.3 * coalesce(pts_avg_away_this_season, pts_avg_this_season)
        end as away_avg
    from combined
)

select
    as_of_round_id,
    id,
    pts_avg_home_last_season,
    pts_avg_away_last_season,
    matches_home_last_season,
    matches_away_last_season,
    pts_avg_home_this_season,
    pts_avg_away_this_season,
    matches_home_this_season,
    matches_away_this_season,
    home_avg,
    away_avg,
    -- Home multiplier: clamped +-15%
    case
        when baseline_pts is null or baseline_pts = 0 or home_avg is null then null
        else greatest(0.85, least(1.15, home_avg / baseline_pts))
    end as home_multiplier,
    -- Away multiplier: clamped +-15%
    case
        when baseline_pts is null or baseline_pts = 0 or away_avg is null then null
        else greatest(0.85, least(1.15, away_avg / baseline_pts))
    end as away_multiplier,
    -- Delta: positive means player performs better at home
    coalesce(home_avg, 0) - coalesce(away_avg, 0) as home_away_delta
from with_averages
