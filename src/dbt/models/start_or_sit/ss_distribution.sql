/*
Start or Sit: Distribution & Volatility (Subtab)

Thin mart: score distribution, consistency, and boom/bust rates.
See int_distribution_stats for calculation details.
*/

select
    as_of_round_id,
    id as player_id,
    player_name,
    position,
    club,
    club_logo_url,
    matches_played,
    pts_floor,
    pts_median,
    pts_ceiling,
    pts_avg,
    pts_stddev,
    cv as cv_points,
    consistency_rating,
    boom_rate,
    bust_rate
from {{ ref('int_distribution_stats') }}
