/*
Scouting Mart: Last 10 Matches

Thin mart over int_sct_last_10_stats.
Adds ADP rankings (row_number by DVS) and G/A contribution.
All complex logic (windowing, z-scores, DVS) lives in the intermediate model.
*/

with goal_points as (
    select points
    from {{ ref('raw_scout_points') }}
    where code = 'G'
),

assist_points as (
    select points
    from {{ ref('raw_scout_points') }}
    where code = 'A'
)

select
    as_of_round_id,
    id as player_id,
    player_name,
    position,
    club,
    club_logo_url,
    matches_counted,
    availability,
    pts_avg,
    base_avg,
    -- Scout averages (averaged over last 10 played matches)
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
    -- Home scout averages
    avg_g_home,
    avg_a_home,
    avg_ft_home,
    avg_fd_home,
    avg_ff_home,
    avg_fs_home,
    avg_ps_home,
    avg_ds_home,
    avg_sg_home,
    avg_de_home,
    avg_dp_home,
    avg_fc_home,
    avg_pc_home,
    avg_ca_home,
    avg_cv_home,
    avg_gc_home,
    avg_gs_home,
    avg_i_home,
    avg_pp_home,
    -- Away scout averages
    avg_g_away,
    avg_a_away,
    avg_ft_away,
    avg_fd_away,
    avg_ff_away,
    avg_fs_away,
    avg_ps_away,
    avg_ds_away,
    avg_sg_away,
    avg_de_away,
    avg_dp_away,
    avg_fc_away,
    avg_pc_away,
    avg_ca_away,
    avg_cv_away,
    avg_gc_away,
    avg_gs_away,
    avg_i_away,
    avg_pp_away,
    -- Z-scores and DVS from intermediate
    z_score_pos_avg,
    z_score_pos_base,
    z_score_gen_avg,
    z_score_gen_base,
    dvs_pos_avg,
    dvs_pos_base,
    dvs_gen_avg,
    dvs_gen_base,
    -- G/A contribution: points from goals and assists
    (avg_g * (select goal_points.points from goal_points))
    + (avg_a * (select assist_points.points from assist_points)) as ga_avg,
    -- ADP rankings: lower rank = better player (ordered by DVS descending)
    row_number() over (partition by as_of_round_id, position order by dvs_pos_avg desc nulls last) as adp_pos_avg,
    row_number() over (partition by as_of_round_id, position order by dvs_pos_base desc nulls last) as adp_pos_base,
    row_number() over (partition by as_of_round_id order by dvs_gen_avg desc nulls last) as adp_gen_avg,
    row_number() over (partition by as_of_round_id order by dvs_gen_base desc nulls last) as adp_gen_base
from {{ ref('int_sct_last_10_stats') }}
