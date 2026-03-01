/*
Market Valuation: Baseline (Stabilized Mean & Shrinkage) (Subtab)

Thin mart: detailed baseline (stabilized mean with shrinkage parameters).
Shows how the baseline is constructed from multi-season data.

# fixit add home/away splits for baseline here too
*/

select
    as_of_round_id,
    name as player_name,
    id as player_id,
    position,
    pts_avg_this_season as avg_points_this_season,
    matches_this_season as games_this_season,
    pts_avg_last_season as avg_points_last_season,
    matches_last_season as games_last_season,
    position_pts_avg as position_avg_last_season,
    -- Shrinkage parameter k=5; weight = matches_this_season / (matches_this_season + 5)
    5 as shrinking_parameter,
    shrinking_weight_this_season,
    shrinking_method,
    baseline_pts,
    -- Baseline rank within position
    row_number() over (
        partition by as_of_round_id, position
        order by baseline_pts desc nulls last
    ) as baseline_rank_pos,
    -- Baseline rank across all positions
    row_number() over (
        partition by as_of_round_id
        order by baseline_pts desc nulls last
    ) as baseline_rank_gen
from {{ ref('int_baseline') }}
