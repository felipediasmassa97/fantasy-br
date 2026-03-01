/*
Market Valuation: Regression Candidate Decomposition (Subtab)

Thin mart: detailed regression signal breakdown per player.
See int_regression for score formula.
*/

select
    as_of_round_id,
    id as player_id,
    name as player_name,
    position,
    club,
    club_logo_url,
    ewm_pts as ewm_points,
    baseline_pts,
    performance_gap,
    ga_share as goal_assist_share,
    consistency_rating,
    regression_score,
    signal_label,
    confidence_flag
from {{ ref('int_regression') }}
