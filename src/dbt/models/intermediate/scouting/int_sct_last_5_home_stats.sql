/*
Scouting Intermediate: Last 5 Home Matches Stats

For each as_of_round, computes averaged stats over the last 5 HOME played matches.

Two distinct windows are used:
  1. Calendar window (last 5 home rounds): determines availability.
     "Of the last 5 home rounds, how many did this player play?"
  2. Played window (last 5 home played matches): determines stat averages.
     "Across all home matches up to now, what are the last 5 averages?"

Venue filter: only home matches (is_home = true) are considered.
Enriched with z-scores and DVS via scouting_enrichment macro.
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Player home rounds up to each as_of_round (for availability in home context)
player_home_rounds as (
    select
        r.as_of_round_id,
        p.id,
        p.player_name,
        p.club,
        p.club_logo_url,
        p.position,
        p.round_id,
        p.has_played,
        row_number() over (
            partition by r.as_of_round_id, p.id
            order by p.round_id desc
        ) as round_rank
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where
        p.season = 2026
        and p.is_home = true  -- only home matches
        and p.round_id <= r.as_of_round_id
),

-- Most recent player info
latest_info as (
    select
        as_of_round_id,
        id,
        player_name,
        club,
        club_logo_url,
        position
    from player_home_rounds
    where round_rank = 1
),

-- Availability: matches played / total in last 5 home rounds
availability_calc as (
    select
        as_of_round_id,
        id,
        countif(has_played = true) as matches_counted,
        countif(has_played = true) / count(*) as availability
    from player_home_rounds
    where round_rank <= 5  -- last 5 home rounds
    group by as_of_round_id, id
),

-- Last 5 HOME PLAYED matches per player (for stat aggregation)
last_n_home_played as (
    select
        r.as_of_round_id,
        p.id,
        p.pts_round,
        p.base_round,
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
        and p.is_home = true  -- only home matches
        and p.has_played = true
        and p.round_id <= r.as_of_round_id
),

-- Average stats from the last 5 home played matches
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
        avg(scout_pp) as avg_pp
    from last_n_home_played
    where played_rank <= 5
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
        p.avg_pp
    from availability_calc as a
    inner join latest_info as l
        on a.as_of_round_id = l.as_of_round_id and a.id = l.id
    left join pts_calc as p
        on a.as_of_round_id = p.as_of_round_id and a.id = p.id
),

-- Enrichment: z-scores and DVS (see scouting_enrichment macro for details)
{{ scouting_enrichment(by_round=true) }}
