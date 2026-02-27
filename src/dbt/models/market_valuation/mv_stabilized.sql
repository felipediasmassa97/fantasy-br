/*
Market Valuation: Stabilized Mean & Shrinkage (Subtab)

Thin mart: detailed baseline/stabilized mean with shrinkage parameters.
Shows how the baseline is constructed from multi-season data.
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
    -- Shrinkage parameter: matches threshold for "reliable" data
    -- weighted_seasons requires >= 5 matches + > 30% availability last season
    -- # fixit this is not using shrinkage factor k yet
    case
        when has_last_season_data then 5
        else null
    end as shrink_k_used,
    weight_this_season,
    baseline_pts as stabilized_mean_points,
    -- Stabilized rank within position
    row_number() over (
        partition by as_of_round_id, position
        order by baseline_pts desc nulls last
    ) as stabilized_rank_pos
    -- fixit add stabilized rank general
from {{ ref('int_map_baseline') }}
