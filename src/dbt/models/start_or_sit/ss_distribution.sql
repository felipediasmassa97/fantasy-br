/*
Start or Sit: Distribution & Volatility (Subtab)

Thin mart: score distribution, consistency, and boom/bust rates.
See int_distribution_stats for calculation details.
*/

select
    as_of_round_id,
    name as player_name,
    id as player_id,
    position,
    matches_played as n_games_total_used,
    floor_pts as floor_p20,
    median_pts as median_p50,
    ceiling_pts as ceiling_p80,
    pts_avg as mean_points_used,
    pts_stddev as std_points_used,
    cv as cv_points,
    consistency_rating,
    boom_rate_ge_8,
    bust_rate_le_2
from {{ ref('int_distribution_stats') }}
