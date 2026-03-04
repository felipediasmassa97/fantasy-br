/*
Scouting Intermediate: Last 10 Matches Stats

For each as_of_round, computes averaged stats over the last 10 played matches.

Two distinct windows are used:
  1. Calendar window (last 10 rounds): determines availability.
     "Of the last 10 rounds, how many did this player play?"
  2. Played window (last 10 played matches): determines stat averages.
     "Across all played matches up to now, what are the last 10 averages?"

Same logic as int_sct_last_5_stats but with a 10-match/round window.
Enriched with z-scores and DVS via scouting_enrichment macro.
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

round_ids as (
    select distinct round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Last 10 calendar rounds per as_of_round (for availability calculation)
round_windows as (
    select
        r1.as_of_round_id,
        r2.round_id,
        row_number() over (
            partition by r1.as_of_round_id
            order by r2.round_id desc
        ) as round_rank
    from all_rounds as r1
    cross join round_ids as r2
    where r2.round_id <= r1.as_of_round_id
),

last_n_calendar_rounds as (
    select
        as_of_round_id,
        round_id
    from round_windows
    where round_rank <= 10
),

-- Player status in those calendar rounds (for availability + latest info)
player_rounds as (
    select
        lr.as_of_round_id,
        p.id,
        p.player_name,
        p.club,
        p.club_logo_url,
        p.position,
        p.round_id,
        p.has_played,
        row_number() over (
            partition by lr.as_of_round_id, p.id
            order by p.round_id desc
        ) as round_rank
    from {{ ref('int_players') }} as p
    inner join last_n_calendar_rounds as lr on p.round_id = lr.round_id
    where p.season = 2026
),

latest_info as (
    select
        as_of_round_id,
        id,
        player_name,
        club,
        club_logo_url,
        position
    from player_rounds
    where round_rank = 1
),

-- Availability: matches played / calendar rounds in the 10-round window
availability_calc as (
    select
        as_of_round_id,
        id,
        countif(has_played = true) as matches_counted,
        countif(has_played = true) / count(*) as availability
    from player_rounds
    group by as_of_round_id, id
),

-- Last 10 PLAYED matches per player (for stat aggregation)
last_n_played as (
    select
        r.as_of_round_id,
        p.id,
        p.pts_round,
        p.base_round,
        p.is_home,
        p.scout_g,
        p.scout_a,
        p.scout_ft,
        p.scout_fd,
        p.scout_ff,
        p.scout_fs,
        p.scout_ps,
        p.scout_ds,
        p.scout_sg,
        p.scout_de,
        p.scout_dp,
        p.scout_fc,
        p.scout_pc,
        p.scout_ca,
        p.scout_cv,
        p.scout_gc,
        p.scout_gs,
        p.scout_i,
        p.scout_pp,
        row_number() over (
            partition by r.as_of_round_id, p.id
            order by p.round_id desc
        ) as played_rank
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where
        p.season = 2026
        and p.has_played = true
        and p.round_id <= r.as_of_round_id
),

-- Average stats from the last 10 played matches
pts_calc as (
    select
        as_of_round_id,
        id,
        avg(pts_round) as pts_avg,
        avg(base_round) as base_avg,
        avg(scout_g) as avg_g,
        avg(scout_a) as avg_a,
        avg(scout_ft) as avg_ft,
        avg(scout_fd) as avg_fd,
        avg(scout_ff) as avg_ff,
        avg(scout_fs) as avg_fs,
        avg(scout_ps) as avg_ps,
        avg(scout_ds) as avg_ds,
        avg(scout_sg) as avg_sg,
        avg(scout_de) as avg_de,
        avg(scout_dp) as avg_dp,
        avg(scout_fc) as avg_fc,
        avg(scout_pc) as avg_pc,
        avg(scout_ca) as avg_ca,
        avg(scout_cv) as avg_cv,
        avg(scout_gc) as avg_gc,
        avg(scout_gs) as avg_gs,
        avg(scout_i) as avg_i,
        avg(scout_pp) as avg_pp,
        avg(if(is_home, scout_g, null)) as avg_g_home,
        avg(if(is_home, scout_a, null)) as avg_a_home,
        avg(if(is_home, scout_ft, null)) as avg_ft_home,
        avg(if(is_home, scout_fd, null)) as avg_fd_home,
        avg(if(is_home, scout_ff, null)) as avg_ff_home,
        avg(if(is_home, scout_fs, null)) as avg_fs_home,
        avg(if(is_home, scout_ps, null)) as avg_ps_home,
        avg(if(is_home, scout_ds, null)) as avg_ds_home,
        avg(if(is_home, scout_sg, null)) as avg_sg_home,
        avg(if(is_home, scout_de, null)) as avg_de_home,
        avg(if(is_home, scout_dp, null)) as avg_dp_home,
        avg(if(is_home, scout_fc, null)) as avg_fc_home,
        avg(if(is_home, scout_pc, null)) as avg_pc_home,
        avg(if(is_home, scout_ca, null)) as avg_ca_home,
        avg(if(is_home, scout_cv, null)) as avg_cv_home,
        avg(if(is_home, scout_gc, null)) as avg_gc_home,
        avg(if(is_home, scout_gs, null)) as avg_gs_home,
        avg(if(is_home, scout_i, null)) as avg_i_home,
        avg(if(is_home, scout_pp, null)) as avg_pp_home,
        avg(if(not is_home, scout_g, null)) as avg_g_away,
        avg(if(not is_home, scout_a, null)) as avg_a_away,
        avg(if(not is_home, scout_ft, null)) as avg_ft_away,
        avg(if(not is_home, scout_fd, null)) as avg_fd_away,
        avg(if(not is_home, scout_ff, null)) as avg_ff_away,
        avg(if(not is_home, scout_fs, null)) as avg_fs_away,
        avg(if(not is_home, scout_ps, null)) as avg_ps_away,
        avg(if(not is_home, scout_ds, null)) as avg_ds_away,
        avg(if(not is_home, scout_sg, null)) as avg_sg_away,
        avg(if(not is_home, scout_de, null)) as avg_de_away,
        avg(if(not is_home, scout_dp, null)) as avg_dp_away,
        avg(if(not is_home, scout_fc, null)) as avg_fc_away,
        avg(if(not is_home, scout_pc, null)) as avg_pc_away,
        avg(if(not is_home, scout_ca, null)) as avg_ca_away,
        avg(if(not is_home, scout_cv, null)) as avg_cv_away,
        avg(if(not is_home, scout_gc, null)) as avg_gc_away,
        avg(if(not is_home, scout_gs, null)) as avg_gs_away,
        avg(if(not is_home, scout_i, null)) as avg_i_away,
        avg(if(not is_home, scout_pp, null)) as avg_pp_away
    from last_n_played
    where played_rank <= 10
    group by as_of_round_id, id
),

-- Combine: player info + availability + averaged stats
player_pts as (
    select
        a.as_of_round_id,
        a.id,
        l.player_name,
        l.club,
        l.club_logo_url,
        l.position,
        a.matches_counted,
        p.pts_avg,
        p.base_avg,
        a.availability,
        p.avg_g,
        p.avg_a,
        p.avg_ft,
        p.avg_fd,
        p.avg_ff,
        p.avg_fs,
        p.avg_ps,
        p.avg_ds,
        p.avg_sg,
        p.avg_de,
        p.avg_dp,
        p.avg_fc,
        p.avg_pc,
        p.avg_ca,
        p.avg_cv,
        p.avg_gc,
        p.avg_gs,
        p.avg_i,
        p.avg_pp,
        p.avg_g_home,
        p.avg_a_home,
        p.avg_ft_home,
        p.avg_fd_home,
        p.avg_ff_home,
        p.avg_fs_home,
        p.avg_ps_home,
        p.avg_ds_home,
        p.avg_sg_home,
        p.avg_de_home,
        p.avg_dp_home,
        p.avg_fc_home,
        p.avg_pc_home,
        p.avg_ca_home,
        p.avg_cv_home,
        p.avg_gc_home,
        p.avg_gs_home,
        p.avg_i_home,
        p.avg_pp_home,
        p.avg_g_away,
        p.avg_a_away,
        p.avg_ft_away,
        p.avg_fd_away,
        p.avg_ff_away,
        p.avg_fs_away,
        p.avg_ps_away,
        p.avg_ds_away,
        p.avg_sg_away,
        p.avg_de_away,
        p.avg_dp_away,
        p.avg_fc_away,
        p.avg_pc_away,
        p.avg_ca_away,
        p.avg_cv_away,
        p.avg_gc_away,
        p.avg_gs_away,
        p.avg_i_away,
        p.avg_pp_away
    from availability_calc as a
    inner join latest_info as l
        on a.as_of_round_id = l.as_of_round_id and a.id = l.id
    left join pts_calc as p
        on a.as_of_round_id = p.as_of_round_id and a.id = p.id
),

-- Enrichment: z-scores and DVS (see scouting_enrichment macro for details)
{{ scouting_enrichment(by_round=true) }}
