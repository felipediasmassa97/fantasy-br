/*
Scouting Mart: Last Season (2025)

Thin mart over int_sct_last_season_stats.
Adds ADP rankings (row_number by DVS) and G/A contribution.
No as_of_round_id dimension since this covers the entire previous season.
*/

select
    id as player_id,
    name as player_name,
    position,
    club,
    club_logo_url,
    matches_counted,
    availability,
    pts_avg,
    base_avg,
    -- G/A contribution: points from goals and assists
    pts_avg - base_avg as ga_avg,
    -- Scout averages (full season 2025 averages)
    avg_g,
    avg_a,
    avg_ft,
    avg_fd,
    avg_ff,
    avg_fs,
    avg_ps,
    avg_ds,
    avg_sg,
    avg_de,
    avg_dp,
    avg_fc,
    avg_pc,
    avg_ca,
    avg_cv,
    avg_gc,
    avg_gs,
    avg_i,
    avg_pp,
    -- Z-scores and DVS from intermediate
    z_score_pos_avg,
    z_score_pos_base,
    z_score_gen_avg,
    z_score_gen_base,
    dvs_pos_avg,
    dvs_pos_base,
    dvs_gen_avg,
    dvs_gen_base,
    -- ADP rankings: no partition by as_of_round_id (single snapshot)
    row_number() over (partition by position order by dvs_pos_avg desc nulls last) as adp_pos_avg,
    row_number() over (partition by position order by dvs_pos_base desc nulls last) as adp_pos_base,
    row_number() over (order by dvs_gen_avg desc nulls last) as adp_gen_avg,
    row_number() over (order by dvs_gen_base desc nulls last) as adp_gen_base
from {{ ref('int_sct_last_season_stats') }}
