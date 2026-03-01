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
        p.name,
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
        name,
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
        p.scout_G,
        p.scout_A,
        p.scout_FT,
        p.scout_FD,
        p.scout_FF,
        p.scout_FS,
        p.scout_PS,
        p.scout_DS,
        p.scout_SG,
        p.scout_DE,
        p.scout_DP,
        p.scout_FC,
        p.scout_PC,
        p.scout_CA,
        p.scout_CV,
        p.scout_GC,
        p.scout_GS,
        p.scout_I,
        p.scout_PP,
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
        avg(scout_G) as avg_G,
        avg(scout_A) as avg_A,
        avg(scout_FT) as avg_FT,
        avg(scout_FD) as avg_FD,
        avg(scout_FF) as avg_FF,
        avg(scout_FS) as avg_FS,
        avg(scout_PS) as avg_PS,
        avg(scout_DS) as avg_DS,
        avg(scout_SG) as avg_SG,
        avg(scout_DE) as avg_DE,
        avg(scout_DP) as avg_DP,
        avg(scout_FC) as avg_FC,
        avg(scout_PC) as avg_PC,
        avg(scout_CA) as avg_CA,
        avg(scout_CV) as avg_CV,
        avg(scout_GC) as avg_GC,
        avg(scout_GS) as avg_GS,
        avg(scout_I) as avg_I,
        avg(scout_PP) as avg_PP
    from last_n_home_played
    where played_rank <= 5
    group by as_of_round_id, id
),

-- Combine: player info + availability + averaged stats
player_pts as (
    select
        a.as_of_round_id,
        a.id,
        l.name,
        l.club,
        l.club_logo_url,
        l.position,
        a.matches_counted,
        p.pts_avg,
        p.base_avg,
        a.availability,
        p.avg_G,
        p.avg_A,
        p.avg_FT,
        p.avg_FD,
        p.avg_FF,
        p.avg_FS,
        p.avg_PS,
        p.avg_DS,
        p.avg_SG,
        p.avg_DE,
        p.avg_DP,
        p.avg_FC,
        p.avg_PC,
        p.avg_CA,
        p.avg_CV,
        p.avg_GC,
        p.avg_GS,
        p.avg_I,
        p.avg_PP
    from availability_calc as a
    inner join latest_info as l
        on a.as_of_round_id = l.as_of_round_id and a.id = l.id
    left join pts_calc as p
        on a.as_of_round_id = p.as_of_round_id and a.id = p.id
),

-- Enrichment: z-scores and DVS (see scouting_enrichment macro for details)
{{ scouting_enrichment(by_round=true) }}
