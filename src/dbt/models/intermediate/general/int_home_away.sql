/*
MAP Component 3: Home/Away Context

Calculates venue adjustments based on historical home/away performance.
Blending uses the same Bayesian shrinkage as int_baseline, applied per-venue
using the actual home/away match count:
  weight_venue_this_season = matches_venue_this_season / (matches_venue_this_season + k)
  venue_avg = weight_this * position_pts_avg_venue_this_season + (1 - weight_this) * prior_venue

Prior for each venue split:
- Returning players (>=5 matches in venue, >30% availability last season): players_pts_avg_venue_last_season
- Rookies / insufficient history: position_pts_avg_venue_last_season

venue_multiplier = avg_[home|away] / baseline_pts
Clamped between 0.85 and 1.15 (+-15% max impact)
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- This season home/away splits per round
player_avg_venue_this_season as (
    select
        r.as_of_round_id,
        p.id,
        avg(if(p.has_played and p.is_home = true, p.pts_round, null)) as player_pts_avg_home_this_season,
        avg(if(p.has_played and p.is_home = false, p.pts_round, null)) as player_pts_avg_away_this_season,
        countif(p.has_played = true and p.is_home = true) as matches_home_this_season,
        countif(p.has_played = true and p.is_home = false) as matches_away_this_season
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where p.season = 2026 and p.round_id <= r.as_of_round_id
    group by r.as_of_round_id, p.id
),

-- Last season home/away splits (full season 2025)
player_avg_venue_last_season as (
    select
        id,
        position,
        avg(if(has_played and is_home = true, pts_round, null)) as player_pts_avg_home_last_season,
        avg(if(has_played and is_home = false, pts_round, null)) as player_pts_avg_away_last_season,
        countif(has_played = true and is_home = true) as matches_home_last_season,
        countif(has_played = true and is_home = false) as matches_away_last_season,
        countif(has_played = true) / count(*) as availability_last_season
    from {{ ref('int_players') }}
    where season = 2025
    group by id, position
),

-- Position average home from last season (for rookies)
-- Only include players with >= 5 matches at home AND > 30% availability
position_avg_home_last_season as (
    select
        position,
        avg(player_pts_avg_home_last_season) as position_pts_avg_home_last_season
    from player_avg_venue_last_season
    where matches_home_last_season >= 5 and availability_last_season > 0.30
    group by position
),

-- Position average away from last season (for rookies)
-- Only include players with >= 5 matches away AND > 30% availability
position_avg_away_last_season as (
    select
        position,
        avg(player_pts_avg_away_last_season) as position_pts_avg_away_last_season
    from player_avg_venue_last_season
    where matches_away_last_season >= 5 and availability_last_season > 0.30
    group by position
),

-- Combine splits with baseline
combined as (
    select
        b.as_of_round_id,
        b.id,
        b.baseline_pts,
        b.player_pts_avg_last_season,
        b.player_pts_avg_this_season,
        ls.player_pts_avg_home_last_season,
        ls.player_pts_avg_away_last_season,
        ls.matches_home_last_season,
        ls.matches_away_last_season,
        ts.player_pts_avg_home_this_season,
        ts.player_pts_avg_away_this_season,
        ts.matches_home_this_season,
        ts.matches_away_this_season,
        ph.position_pts_avg_home_last_season,
        pa.position_pts_avg_away_last_season,
        -- Flag: player qualifies as having last season home/away data
        -- Note: uses home/away for number of matches, but overall availability
        (ls.matches_home_last_season >= 5 and ls.availability_last_season > 0.30) as has_last_season_home_data,
        (ls.matches_away_last_season >= 5 and ls.availability_last_season > 0.30) as has_last_season_away_data
    from {{ ref('int_baseline') }} as b
    left join player_avg_venue_last_season as ls on b.id = ls.id
    left join player_avg_venue_this_season as ts on b.as_of_round_id = ts.as_of_round_id and b.id = ts.id
    left join position_avg_home_last_season as ph on b.position = ph.position
    left join position_avg_away_last_season as pa on b.position = pa.position
),

-- Calculate blended averages using shrinkage per venue
-- See macros/shrink_blend.sql
-- prior_venue = last_season_venue_avg if available, else last_season_overall_avg (from baseline)
with_averages as (
    select
        *,
        -- Blended home average (shrinkage):
        -- prior = last season home avg; fallback to position home avg (rookies)
        case
            when has_last_season_home_data
                then
                    {{
                        shrink_blend(
                            'matches_home_this_season',
                            'player_pts_avg_home_this_season',
                            'player_pts_avg_home_last_season'
                        )
                    }}
            else
                {{
                    shrink_blend(
                        'matches_home_this_season',
                        'player_pts_avg_home_this_season',
                        'coalesce(position_pts_avg_home_last_season, player_pts_avg_home_this_season)'
                    )
                }}
        end as pts_avg_home,
        -- Blended away average (shrinkage):
        -- prior = last season away avg; fallback to position away avg (rookies)
        case
            when has_last_season_away_data
                then
                    {{
                        shrink_blend(
                            'matches_away_this_season',
                            'player_pts_avg_away_this_season',
                            'player_pts_avg_away_last_season'
                        )
                    }}
            else
                {{
                    shrink_blend(
                        'matches_away_this_season',
                        'player_pts_avg_away_this_season',
                        'coalesce(position_pts_avg_away_last_season, player_pts_avg_away_this_season)'
                    )
                }}
        end as pts_avg_away,
        -- Shrinking method: "weighted_seasons" or "rookie_shrinkage"
        case
            when has_last_season_home_data then 'weighted_seasons'
            else 'rookie_shrinkage'
        end as shrinking_method_home,
        case
            when has_last_season_away_data then 'weighted_seasons'
            else 'rookie_shrinkage'
        end as shrinking_method_away,
        -- Shrinkage weight: grows from 0 toward 1 as matches_[home|away]_this_season increases
        case
            when player_pts_avg_home_this_season is null then 0.0
            else {{ shrink_weight('matches_home_this_season') }}
        end as weight_home,
        case
            when player_pts_avg_away_this_season is null then 0.0
            else {{ shrink_weight('matches_away_this_season') }}
        end as weight_away
    from combined
)

select
    as_of_round_id,
    id,
    player_pts_avg_home_this_season,
    player_pts_avg_away_this_season,
    matches_home_this_season,
    matches_away_this_season,
    player_pts_avg_home_last_season,
    player_pts_avg_away_last_season,
    matches_home_last_season,
    matches_away_last_season,
    position_pts_avg_home_last_season,
    position_pts_avg_away_last_season,
    pts_avg_home,
    pts_avg_away,
    shrinking_method_home,
    shrinking_method_away,
    weight_home,
    weight_away,
    -- Home multiplier: clamped +-15%
    case
        when baseline_pts is null or baseline_pts = 0 or pts_avg_home is null then null
        else greatest(0.85, least(1.15, pts_avg_home / baseline_pts))
    end as multiplier_home,
    -- Away multiplier: clamped +-15%
    case
        when baseline_pts is null or baseline_pts = 0 or pts_avg_away is null then null
        else greatest(0.85, least(1.15, pts_avg_away / baseline_pts))
    end as multiplier_away,
    -- Delta: positive means player performs better at home
    coalesce(pts_avg_home, 0) - coalesce(pts_avg_away, 0) as home_away_delta
from with_averages
