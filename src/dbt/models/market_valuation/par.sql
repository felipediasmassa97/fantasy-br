{{ config(materialized='view') }}

/*
PAR (Points Above Replacement)

Measures how many points a player provides compared to a replacement-level player
at the same position. Replacement level is defined using position-specific percentiles.

Replacement Percentiles:
- GK: 50th percentile
- CB: 80th percentile
- FB: 75th percentile
- MD: 65th percentile
- AT: 55th percentile

PAR = baseline_pts - replacement_level_for_position
*/

with baseline as (
    select
        as_of_round_id,
        id,
        name,
        club,
        club_logo_url,
        position,
        baseline_pts,
        baseline_method,
        pts_avg_this_season,
        matches_this_season,
        pts_avg_last_season,
        matches_last_season,
        availability_last_season
    from {{ ref('int_map_baseline') }}
    where baseline_pts is not null
),

-- Calculate replacement level per position using hardcoded percentiles
-- GK: 50th percentile
replacement_gk as (
    select
        as_of_round_id,
        'GK' as position,
        0.50 as replacement_pct,
        percentile_cont(baseline_pts, 0.50) over (partition by as_of_round_id) as replacement_level
    from baseline
    where position = 'GK'
),

-- CB: 80th percentile
replacement_cb as (
    select
        as_of_round_id,
        'CB' as position,
        0.80 as replacement_pct,
        percentile_cont(baseline_pts, 0.80) over (partition by as_of_round_id) as replacement_level
    from baseline
    where position = 'CB'
),

-- FB: 75th percentile
replacement_fb as (
    select
        as_of_round_id,
        'FB' as position,
        0.75 as replacement_pct,
        percentile_cont(baseline_pts, 0.75) over (partition by as_of_round_id) as replacement_level
    from baseline
    where position = 'FB'
),

-- MD: 65th percentile
replacement_md as (
    select
        as_of_round_id,
        'MD' as position,
        0.65 as replacement_pct,
        percentile_cont(baseline_pts, 0.65) over (partition by as_of_round_id) as replacement_level
    from baseline
    where position = 'MD'
),

-- AT: 55th percentile
replacement_at as (
    select
        as_of_round_id,
        'AT' as position,
        0.55 as replacement_pct,
        percentile_cont(baseline_pts, 0.55) over (partition by as_of_round_id) as replacement_level
    from baseline
    where position = 'AT'
),

-- Union all replacement levels and dedupe
replacement_levels as (
    select distinct as_of_round_id, position, replacement_pct, replacement_level from replacement_gk
    union all
    select distinct as_of_round_id, position, replacement_pct, replacement_level from replacement_fb
    union all
    select distinct as_of_round_id, position, replacement_pct, replacement_level from replacement_cb
    union all
    select distinct as_of_round_id, position, replacement_pct, replacement_level from replacement_md
    union all
    select distinct as_of_round_id, position, replacement_pct, replacement_level from replacement_at
)

select
    b.as_of_round_id,
    b.id,
    b.name,
    b.club,
    b.club_logo_url,
    b.position,
    b.baseline_pts,
    b.baseline_method,
    b.pts_avg_this_season,
    b.matches_this_season,
    b.pts_avg_last_season,
    b.matches_last_season,
    b.availability_last_season,
    rl.replacement_pct,
    rl.replacement_level,
    b.baseline_pts - rl.replacement_level as par
from baseline b
inner join replacement_levels rl
    on b.as_of_round_id = rl.as_of_round_id
    and b.position = rl.position
