/*
Scouting Mart: This Season (2026)

Thin mart over int_sct_this_season_stats.
Adds ADP rankings (row_number by DVS) and G/A contribution.
All complex logic (season aggregation, z-scores, DVS) lives in the intermediate model.
*/

select
    as_of_round_id,
    id,
    name,
    position,
    club,
    club_logo_url,
    matches_counted,
    availability,
    pts_avg,
    base_avg,
    -- G/A contribution: points from goals and assists
    pts_avg - base_avg as ga_avg,
    -- Scout averages (season-to-date averages for played matches)
    avg_G,
    avg_A,
    avg_FT,
    avg_FD,
    avg_FF,
    avg_FS,
    avg_PS,
    avg_DS,
    avg_SG,
    avg_DE,
    avg_DP,
    avg_FC,
    avg_PC,
    avg_CA,
    avg_CV,
    avg_GC,
    avg_GS,
    avg_I,
    avg_PP,
    -- Z-scores and DVS from intermediate
    z_score_gen_avg,
    z_score_gen_base,
    z_score_pos_avg,
    z_score_pos_base,
    dvs_gen_avg,
    dvs_gen_base,
    dvs_pos_avg,
    dvs_pos_base,
    -- ADP rankings: lower rank = better player (ordered by DVS descending)
    row_number() over (partition by as_of_round_id order by dvs_gen_avg desc nulls last) as adp_gen_avg,
    row_number() over (partition by as_of_round_id order by dvs_gen_base desc nulls last) as adp_gen_base,
    row_number() over (partition by as_of_round_id, position order by dvs_pos_avg desc nulls last) as adp_pos_avg,
    row_number() over (partition by as_of_round_id, position order by dvs_pos_base desc nulls last) as adp_pos_base
from {{ ref('int_sct_this_season_stats') }}
