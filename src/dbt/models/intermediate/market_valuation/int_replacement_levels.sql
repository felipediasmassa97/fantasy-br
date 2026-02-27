/*
Replacement Levels per Position

Computes the replacement-level baseline_pts for each position using position-specific percentiles of baseline_pts.

Replacement level = the expected output of a freely available player at a given position.
Higher percentile = more players available on waivers at that position (i.e., replacement is closer to average).
# fixit improve replacement levels calculations (still don't know how)

Position-specific percentiles:
  - GK (50th): Fewer GKs on waivers, replacement is median-quality
  - CB (80th): Many CBs available, replacement is near top
  - FB (75th): Moderate FB supply
  - MD (65th): Moderate MD supply
  - AT (55th): Fewer quality ATs on waivers
*/

with baseline as (
    -- Only players with computed baseline (filters nulls)
    select
        as_of_round_id,
        position,
        baseline_pts
    from {{ ref('int_map_baseline') }}
    where baseline_pts is not null
),

-- BigQuery requires literal percentile values, so each position needs its own CTE.

-- GK: 50th percentile (fewer GKs on waivers, replacement is median-quality)
replacement_gk as (
    select distinct
        as_of_round_id,
        'GK' as position,
        0.50 as replacement_pct,
        percentile_cont(baseline_pts, 0.50) over (partition by as_of_round_id) as replacement_level
    from baseline
    where position = 'GK'
),

-- CB: 80th percentile (many CBs available, replacement is near top)
replacement_cb as (
    select distinct
        as_of_round_id,
        'CB' as position,
        0.80 as replacement_pct,
        percentile_cont(baseline_pts, 0.80) over (partition by as_of_round_id) as replacement_level
    from baseline
    where position = 'CB'
),

-- FB: 75th percentile (moderate FB supply)
replacement_fb as (
    select distinct
        as_of_round_id,
        'FB' as position,
        0.75 as replacement_pct,
        percentile_cont(baseline_pts, 0.75) over (partition by as_of_round_id) as replacement_level
    from baseline
    where position = 'FB'
),

-- MD: 65th percentile (moderate MD supply)
replacement_md as (
    select distinct
        as_of_round_id,
        'MD' as position,
        0.65 as replacement_pct,
        percentile_cont(baseline_pts, 0.65) over (partition by as_of_round_id) as replacement_level
    from baseline
    where position = 'MD'
),

-- AT: 55th percentile (fewer quality ATs on waivers)
replacement_at as (
    select distinct
        as_of_round_id,
        'AT' as position,
        0.55 as replacement_pct,
        percentile_cont(baseline_pts, 0.55) over (partition by as_of_round_id) as replacement_level
    from baseline
    where position = 'AT'
),

-- Union all positions into a single reference table
replacement_all as (
    select * from replacement_gk
    union all
    select * from replacement_cb
    union all
    select * from replacement_fb
    union all
    select * from replacement_md
    union all
    select * from replacement_at
)

select
    *,
    -- Position depth flag: DEEP = many viable options (high replacement pct)
    -- SCARCE = few viable options (low replacement pct)
    case
        when replacement_pct >= 0.75 then 'DEEP'
        when replacement_pct >= 0.60 then 'MODERATE'
        else 'SCARCE'
    end as position_depth_flag
from replacement_all
