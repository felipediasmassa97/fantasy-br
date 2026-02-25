{% macro scouting_enrichment(by_round=true) %}
{#
Scouting enrichment: computes z-scores and DVS from a preceding `player_pts` CTE.

This macro generates CTEs that continue the WITH clause started in the calling model.
It expects a CTE named `player_pts` to already exist with these columns:
  - as_of_round_id (required if by_round=true)
  - id, name, club, club_logo_url, position
  - pts_avg, base_avg, availability, matches_counted
  - All scout averages: avg_G, avg_A, avg_FT, avg_FD, avg_FF, avg_FS, avg_PS,
    avg_DS, avg_SG, avg_DE, avg_DP, avg_FC, avg_PC, avg_CA, avg_CV, avg_GC, avg_GS, avg_I, avg_PP

Outputs all player_pts columns plus:
  - z_score_gen_avg, z_score_gen_base: standard deviations from top-200 player mean
  - z_score_pos_avg, z_score_pos_base: standard deviations from top position-group mean
  - dvs_gen_avg, dvs_gen_base: DVS (z-score adjusted by availability) for general scope
  - dvs_pos_avg, dvs_pos_base: DVS for position-based scope

Parameters:
  - by_round (bool): true for current-season models with as_of_round_id dimension,
                      false for last-season models without it.
#}

{% if by_round %}

-- Position-level benchmark stats per round
-- Reference group: top N players per position (GK=10, FB/CB=20, MD/AT=30)
position_stats_avg as (
    {{ position_stats_by_round('pts_avg') }}
),

position_stats_base as (
    {{ position_stats_by_round('base_avg') }}
),

-- General benchmark stats per round
-- Reference group: top 200 players across all positions
general_stats_avg as (
    {{ general_stats_by_round('pts_avg') }}
),

general_stats_base as (
    {{ general_stats_by_round('base_avg') }}
),

-- Z-scores: how many standard deviations above/below the benchmark mean
-- Positive = above average performance, negative = below average
with_z_score as (
    select
        p.*,
        {{ z_score_general('p.pts_avg', 'gsa') }} as z_score_gen_avg,
        {{ z_score_general('p.base_avg', 'gsb') }} as z_score_gen_base,
        {{ z_score_position('p.pts_avg', 'psa') }} as z_score_pos_avg,
        {{ z_score_position('p.base_avg', 'psb') }} as z_score_pos_base
    from player_pts p
    left join position_stats_avg psa
        on p.as_of_round_id = psa.as_of_round_id and p.position = psa.position
    left join position_stats_base psb
        on p.as_of_round_id = psb.as_of_round_id and p.position = psb.position
    left join general_stats_avg gsa
        on p.as_of_round_id = gsa.as_of_round_id
    left join general_stats_base gsb
        on p.as_of_round_id = gsb.as_of_round_id
)

{% else %}

-- Position-level benchmark stats (no round dimension, for last season)
-- Reference group: top N players per position (GK=10, FB/CB=20, MD/AT=30)
position_stats_avg as (
    {{ position_stats_cte('pts_avg') }}
),

position_stats_base as (
    {{ position_stats_cte('base_avg') }}
),

-- General benchmark stats (no round dimension)
-- Reference group: top 200 players across all positions
general_stats_avg as (
    {{ general_stats_cte('pts_avg') }}
),

general_stats_base as (
    {{ general_stats_cte('base_avg') }}
),

-- Z-scores: how many standard deviations above/below the benchmark mean
with_z_score as (
    select
        p.*,
        {{ z_score_general('p.pts_avg', 'gsa') }} as z_score_gen_avg,
        {{ z_score_general('p.base_avg', 'gsb') }} as z_score_gen_base,
        {{ z_score_position('p.pts_avg', 'psa') }} as z_score_pos_avg,
        {{ z_score_position('p.base_avg', 'psb') }} as z_score_pos_base
    from player_pts p
    left join position_stats_avg psa on p.position = psa.position
    left join position_stats_base psb on p.position = psb.position
    cross join general_stats_avg gsa
    cross join general_stats_base gsb
)

{% endif %}

-- DVS (Draft Value Score): z-score penalized by unavailability
-- Formula: z_score * (1 - (1 - availability) * gamma), gamma = 0.3
-- 100% availability keeps the full z-score; lower availability gets penalized
select
    *,
    {{ dvs('z_score_gen_avg', 'availability') }} as dvs_gen_avg,
    {{ dvs('z_score_gen_base', 'availability') }} as dvs_gen_base,
    {{ dvs('z_score_pos_avg', 'availability') }} as dvs_pos_avg,
    {{ dvs('z_score_pos_base', 'availability') }} as dvs_pos_base
from with_z_score

{% endmacro %}
