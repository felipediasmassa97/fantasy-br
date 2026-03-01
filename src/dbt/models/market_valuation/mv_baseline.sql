/*
Market Valuation: Baseline (Stabilized Mean & Shrinkage) (Subtab)

Thin mart: detailed baseline (stabilized mean with shrinkage parameters).
Shows how the baseline is constructed from multi-season data, including
home/away venue splits sourced from int_home_away.
*/

select
    b.as_of_round_id,
    b.name as player_name,
    b.id as player_id,
    b.position,
    b.player_pts_avg_this_season as avg_points_this_season,
    b.matches_this_season as games_this_season,
    b.player_pts_avg_last_season as avg_points_last_season,
    b.matches_last_season as games_last_season,
    b.position_pts_avg_last_season as position_avg_last_season,
    -- Shrinkage parameter k=5; weight = matches_this_season / (matches_this_season + 5)
    5 as shrinking_parameter,
    b.shrinking_weight_this_season,
    b.shrinking_method,
    b.baseline_pts,
    -- Baseline rank within position (all matches)
    row_number() over (
        partition by b.as_of_round_id, b.position
        order by b.baseline_pts desc nulls last
    ) as baseline_rank_pos,
    -- Baseline rank across all positions (all matches)
    row_number() over (
        partition by b.as_of_round_id
        order by b.baseline_pts desc nulls last
    ) as baseline_rank_gen,
    -- Home/away venue-split baselines (blended via shrinkage)
    v.pts_avg_home,
    v.pts_avg_away,
    v.matches_home_this_season,
    v.matches_away_this_season,
    -- Baseline rank within position (home matches only)
    row_number() over (
        partition by b.as_of_round_id, b.position
        order by v.pts_avg_home desc nulls last
    ) as baseline_rank_pos_home,
    -- Baseline rank across all positions (home matches only)
    row_number() over (
        partition by b.as_of_round_id
        order by v.pts_avg_home desc nulls last
    ) as baseline_rank_gen_home,
    -- Baseline rank within position (away matches only)
    row_number() over (
        partition by b.as_of_round_id, b.position
        order by v.pts_avg_away desc nulls last
    ) as baseline_rank_pos_away,
    -- Baseline rank across all positions (away matches only)
    row_number() over (
        partition by b.as_of_round_id
        order by v.pts_avg_away desc nulls last
    ) as baseline_rank_gen_away
from {{ ref('int_baseline') }} as b
left join {{ ref('int_home_away') }} as v
    on b.as_of_round_id = v.as_of_round_id and b.id = v.id
