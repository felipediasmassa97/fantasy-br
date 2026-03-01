/*
Start or Sit: Main Consolidated Tab

Thin mart: joins MAP score with distribution and next-match context.
Shows the key decision columns for start/sit decisions.
*/

select
    m.as_of_round_id,
    m.id,
    m.name,
    m.club,
    m.club_logo_url,
    m.position,
    m.map_score,
    d.floor_pts,
    d.ceiling_pts,
    d.consistency_rating,
    m.is_home_next
from {{ ref('int_map_score') }} as m
left join {{ ref('int_distribution_stats') }} as d
    on m.as_of_round_id = d.as_of_round_id and m.id = d.id
