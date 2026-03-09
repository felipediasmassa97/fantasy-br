/*
Start or Sit: Distribution & Volatility (Subtab)

Thin mart: score distribution, consistency, and boom/bust rates.
See int_distribution_stats for calculation details.
*/

select
    d.as_of_round_id,
    d.id as player_id,
    d.player_name,
    d.position,
    d.club,
    d.club_logo_url,
    d.matches_played,
    d.pts_floor,
    d.pts_median,
    d.pts_ceiling,
    d.pts_avg,
    d.pts_stddev,
    d.cv as cv_points,
    d.consistency_rating,
    d.boom_rate,
    d.bust_rate,
    m.map_score
from {{ ref('int_distribution_stats') }} as d
left join {{ ref('int_map_score') }} as m
    on d.as_of_round_id = m.as_of_round_id and d.id = m.id
