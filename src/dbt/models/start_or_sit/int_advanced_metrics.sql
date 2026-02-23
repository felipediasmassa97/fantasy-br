{{ config(materialized='view') }}

-- Final combined model for all advanced metrics
select
    b.as_of_round_id,
    b.id,
    b.name,
    b.club,
    b.club_logo_url,
    b.position,
    d.floor_pts,
    d.median_pts,
    d.ceiling_pts,
    c.consistency_rating,
    c.cv,
    c.pts_range,
    p.poe_total,
    p.poe_last_5,
    e.ewm_pts,
    e.ewm_ratio,
    e.ewm_vs_season_ratio
from {{ ref('int_map_baseline') }} b
left join {{ ref('int_distribution_stats') }} d
    on b.as_of_round_id = d.as_of_round_id and b.id = d.id
left join {{ ref('int_consistency') }} c
    on b.as_of_round_id = c.as_of_round_id and b.id = c.id
left join {{ ref('int_poe') }} p
    on b.as_of_round_id = p.as_of_round_id and b.id = p.id
left join {{ ref('int_ewm_form') }} e
    on b.as_of_round_id = e.as_of_round_id and b.id = e.id
