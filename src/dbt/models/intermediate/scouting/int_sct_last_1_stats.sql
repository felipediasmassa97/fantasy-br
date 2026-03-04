/*
Scouting Intermediate: Last Match Stats

For each as_of_round, captures the most recent played match per player.
- Points and scout values are raw values from that single match (not averaged).
- availability = 1 if the player played in the as_of_round, 0 otherwise.
- matches_counted = 1 if played, 0 otherwise.

This differs from other scouting windows: stats come from a single match,
and availability reflects only the current round participation.

Enriched with z-scores and DVS via scouting_enrichment macro.
*/

with all_rounds as (
    -- All distinct rounds in season 2026, used as the as_of_round dimension
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Check whether each player participated in the current as_of_round
round_status as (
    select
        r.as_of_round_id,
        p.id,
        p.player_name,
        p.club,
        p.club_logo_url,
        p.position,
        p.has_played
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where
        p.season = 2026
        and p.round_id = r.as_of_round_id
),

-- Find the most recent played match per player (up to as_of_round)
-- Used to populate stats even if the player didn't play in the as_of_round itself
last_played_stats as (
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
        ) as rn
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where
        p.season = 2026
        and p.has_played = true
        and p.round_id <= r.as_of_round_id
),

-- Combine: player info from round_status + stats from most recent played match
-- availability reflects current-round participation only
player_pts as (
    select
        s.as_of_round_id,
        s.id,
        s.player_name,
        s.club,
        s.club_logo_url,
        s.position,
        -- Raw values from most recent played match (not averaged)
        lp.pts_round as pts_avg,
        lp.base_round as base_avg,
        lp.scout_g as avg_g,
        lp.scout_a as avg_a,
        lp.scout_ft as avg_ft,
        lp.scout_fd as avg_fd,
        lp.scout_ff as avg_ff,
        lp.scout_fs as avg_fs,
        lp.scout_ps as avg_ps,
        lp.scout_ds as avg_ds,
        lp.scout_sg as avg_sg,
        lp.scout_de as avg_de,
        lp.scout_dp as avg_dp,
        lp.scout_fc as avg_fc,
        lp.scout_pc as avg_pc,
        lp.scout_ca as avg_ca,
        lp.scout_cv as avg_cv,
        lp.scout_gc as avg_gc,
        lp.scout_gs as avg_gs,
        lp.scout_i as avg_i,
        lp.scout_pp as avg_pp,
        if(lp.is_home, lp.scout_g, null) as avg_g_home,
        if(lp.is_home, lp.scout_a, null) as avg_a_home,
        if(lp.is_home, lp.scout_ft, null) as avg_ft_home,
        if(lp.is_home, lp.scout_fd, null) as avg_fd_home,
        if(lp.is_home, lp.scout_ff, null) as avg_ff_home,
        if(lp.is_home, lp.scout_fs, null) as avg_fs_home,
        if(lp.is_home, lp.scout_ps, null) as avg_ps_home,
        if(lp.is_home, lp.scout_ds, null) as avg_ds_home,
        if(lp.is_home, lp.scout_sg, null) as avg_sg_home,
        if(lp.is_home, lp.scout_de, null) as avg_de_home,
        if(lp.is_home, lp.scout_dp, null) as avg_dp_home,
        if(lp.is_home, lp.scout_fc, null) as avg_fc_home,
        if(lp.is_home, lp.scout_pc, null) as avg_pc_home,
        if(lp.is_home, lp.scout_ca, null) as avg_ca_home,
        if(lp.is_home, lp.scout_cv, null) as avg_cv_home,
        if(lp.is_home, lp.scout_gc, null) as avg_gc_home,
        if(lp.is_home, lp.scout_gs, null) as avg_gs_home,
        if(lp.is_home, lp.scout_i, null) as avg_i_home,
        if(lp.is_home, lp.scout_pp, null) as avg_pp_home,
        if(not lp.is_home, lp.scout_g, null) as avg_g_away,
        if(not lp.is_home, lp.scout_a, null) as avg_a_away,
        if(not lp.is_home, lp.scout_ft, null) as avg_ft_away,
        if(not lp.is_home, lp.scout_fd, null) as avg_fd_away,
        if(not lp.is_home, lp.scout_ff, null) as avg_ff_away,
        if(not lp.is_home, lp.scout_fs, null) as avg_fs_away,
        if(not lp.is_home, lp.scout_ps, null) as avg_ps_away,
        if(not lp.is_home, lp.scout_ds, null) as avg_ds_away,
        if(not lp.is_home, lp.scout_sg, null) as avg_sg_away,
        if(not lp.is_home, lp.scout_de, null) as avg_de_away,
        if(not lp.is_home, lp.scout_dp, null) as avg_dp_away,
        if(not lp.is_home, lp.scout_fc, null) as avg_fc_away,
        if(not lp.is_home, lp.scout_pc, null) as avg_pc_away,
        if(not lp.is_home, lp.scout_ca, null) as avg_ca_away,
        if(not lp.is_home, lp.scout_cv, null) as avg_cv_away,
        if(not lp.is_home, lp.scout_gc, null) as avg_gc_away,
        if(not lp.is_home, lp.scout_gs, null) as avg_gs_away,
        if(not lp.is_home, lp.scout_i, null) as avg_i_away,
        if(not lp.is_home, lp.scout_pp, null) as avg_pp_away,
        if(s.has_played, 1, 0) as matches_counted,
        if(s.has_played, 1.0, 0.0) as availability
    from round_status as s
    left join last_played_stats as lp
        on
            s.as_of_round_id = lp.as_of_round_id
            and s.id = lp.id
            and lp.rn = 1  -- only the most recent played match
),

-- Enrichment: z-scores and DVS (see scouting_enrichment macro for details)
{{ scouting_enrichment(by_round=true) }}
