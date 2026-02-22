{{ config(materialized='view') }}

/*
MAP Components 1 & 2: Baseline Ability + Recent Form

Component 1 - Baseline Ability:
- Players with last season data: 0.6 * last_season_avg + 0.4 * this_season_avg
- Rookies/new players: 0.7 * this_season_avg + 0.3 * position_avg_last_season

Component 2 - Recent Form Adjustment:
- Use last 5 games average
- form_ratio = recent_avg / baseline_pts
- Clamp ratio between 0.8 and 1.2 (±20% max impact)
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

-- Last 5 matches per player per round (for recent form)
last_5_matches as (
    select
        r.as_of_round_id,
        p.id,
        p.pts_round,
        p.has_played,
        row_number() over (
            partition by r.as_of_round_id, p.id
            order by p.round_id desc
        ) as match_rank
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026 and p.round_id <= r.as_of_round_id
),

-- Recent form: average of last 5 played matches
recent_form as (
    select
        as_of_round_id,
        id,
        avg(if(has_played, pts_round, null)) as pts_avg_last_5,
        countif(has_played = true) as matches_last_5
    from last_5_matches
    where match_rank <= 5
    group by as_of_round_id, id
),

-- Combine last season and this season data
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
        rf.pts_avg_last_5,
        rf.matches_last_5,
        -- Flag: player qualifies as having last season data
        (ls.matches_last_season >= 5 and ls.availability_last_season > 0.30) as has_last_season_data
    from this_season_player_avg ts
    left join last_season_player_avg ls on ts.id = ls.id
    left join position_avg_last_season pa on ts.position = pa.position
    left join recent_form rf on ts.as_of_round_id = rf.as_of_round_id and ts.id = rf.id
),

-- Calculate baseline points
with_baseline as (
    select
        *,
        case
            when has_last_season_data then
                0.6 * pts_avg_last_season + 0.4 * coalesce(pts_avg_this_season, 0)
            else
                0.7 * coalesce(pts_avg_this_season, 0) + 0.3 * coalesce(position_pts_avg, 0)
        end as baseline_pts,
        case
            when has_last_season_data then 'weighted_seasons'
            else 'rookie_shrinkage'
        end as baseline_method
    from combined
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
    pts_avg_last_5,
    matches_last_5,
    baseline_pts,
    baseline_method,
    -- Form ratio: recent performance relative to baseline (clamped ±20%)
    case
        when baseline_pts is null or baseline_pts = 0 or pts_avg_last_5 is null then null
        else greatest(0.8, least(1.2, pts_avg_last_5 / baseline_pts))
    end as form_ratio
from with_baseline
