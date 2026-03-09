/*
Market Valuation: Regression Candidate Decomposition (Subtab)

Thin mart: detailed regression signal breakdown per player.
See int_regression for score formula.
*/

select
    r.as_of_round_id,
    r.id as player_id,
    r.player_name,
    r.position,
    r.club,
    r.club_logo_url,
    r.ewm_pts as ewm_points,
    r.baseline_pts,
    r.performance_gap,
    r.ga_share as goal_assist_share,
    r.consistency_rating,
    r.regression_score,
    r.signal_label,
    r.confidence_flag,
    r.baseline_pts - rl.replacement_level as par
from {{ ref('int_regression') }} as r
left join {{ ref('int_replacement_levels') }} as rl
    on r.as_of_round_id = rl.as_of_round_id and r.position = rl.position
