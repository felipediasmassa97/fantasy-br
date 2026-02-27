/*
Market Valuation: Regression Candidate Decomposition (Subtab)

Thin mart: detailed regression signal breakdown per player.
See int_regression for score formula.
*/

select
    as_of_round_id,
    name as player_name,
    id as player_id,
    position,
    ewm_pts as ewm_points,
    stabilized_mean_pts as stabilized_mean_points,
    performance_gap,
    ga_share as goal_assist_share,
    consistency_rating,
    regression_score,
    signal_label,
    confidence_flag
from {{ ref('int_regression') }}
