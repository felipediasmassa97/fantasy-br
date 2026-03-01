/*
EWM Form: Recency-Weighted Form (Exponentially Weighted Mean Points)

A player's current form giving more weight to recent games and less to old ones.
More stable than simple "last 3 games" average, reacts faster than season average.

Calculation:
- Take all played games (this season only, by as_of_round)
- Assign decay weights: weight = (1-alpha)^game_age where game_age=0 for most recent
- EWM = sum(points * weight) / sum(weight)
- Alpha = 0.25 (standard value, higher = reacts faster)

Half-life with alpha=0.25: ~2.4 games (after ~2-3 games, old data is half as important)
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- All played matches per player with game age (0 = most recent)
player_matches as (
    select
        r.as_of_round_id,
        p.id,
        p.pts_round,
        p.has_played,
        p.round_id,
        row_number() over (
            partition by r.as_of_round_id, p.id
            order by p.round_id desc
        ) - 1 as game_age  -- 0 = most recent, 1 = second most recent, etc.
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where
        p.season = 2026
        and p.round_id <= r.as_of_round_id
        and p.has_played = true
),

-- Calculate EWM with alpha = 0.25 (decay = 0.75)
-- Weight = (1 - alpha)^game_age = 0.75^game_age
ewm_calc as (
    select
        as_of_round_id,
        id,
        pts_round,
        game_age,
        round_id,
        pow(0.75, game_age) as weight,
        pts_round * pow(0.75, game_age) as weighted_pts
    from player_matches
),

-- Aggregate EWM per player
ewm_agg as (
    select
        as_of_round_id,
        id,
        sum(weighted_pts) / sum(weight) as ewm_pts,
        sum(weight) as total_weight,
        count(*) as matches_used,
        min(round_id) as oldest_round,
        max(round_id) as newest_round
    from ewm_calc
    group by as_of_round_id, id
)

select
    b.as_of_round_id,
    b.id,
    b.name,
    b.club,
    b.club_logo_url,
    b.position,
    e.ewm_pts,
    e.matches_used,
    e.oldest_round,
    e.newest_round,
    b.baseline_pts,
    b.pts_avg_this_season,
    -- EWM vs baseline ratio (how hot/cold is the player based on recent weighted form)
    case
        when b.baseline_pts is null or b.baseline_pts = 0 then null
        else e.ewm_pts / b.baseline_pts
    end as ewm_vs_baseline_ratio,
    -- EWM vs season average (is recent form better or worse than season average)
    case
        when b.pts_avg_this_season is null or b.pts_avg_this_season = 0 then null
        else e.ewm_pts / b.pts_avg_this_season
    end as ewm_vs_season_ratio,
    -- Form multiplier: EWM-based, clamped 0.8-1.2 (replaces simple last-5 avg form for MAP)
    case
        when b.baseline_pts is null or b.baseline_pts = 0 or e.ewm_pts is null then null
        else greatest(0.8, least(1.2, e.ewm_pts / b.baseline_pts))
    end as form_multiplier
from {{ ref('int_map_baseline') }} as b
left join ewm_agg as e
    on
        b.as_of_round_id = e.as_of_round_id
        and b.id = e.id
