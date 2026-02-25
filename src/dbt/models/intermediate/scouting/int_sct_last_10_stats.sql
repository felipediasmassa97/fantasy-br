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

-- Last 10 calendar rounds per as_of_round (for availability calculation)
round_windows as (
    select
        r1.as_of_round_id,
        r2.round_id,
        row_number() over (
            partition by r1.as_of_round_id
            order by r2.round_id desc
        ) as round_rank
    from all_rounds r1
    cross join (
        select distinct round_id
        from {{ ref('int_players') }}
        where season = 2026
    ) r2
    where r2.round_id <= r1.as_of_round_id
),

last_n_calendar_rounds as (
    select as_of_round_id, round_id
    from round_windows
    where round_rank <= 10
),

-- Player status in those calendar rounds (for availability + latest info)
player_rounds as (
    select
        lr.as_of_round_id,
        p.id,
        p.name,
        p.club,
        p.club_logo_url,
        p.position,
        p.round_id,
        p.has_played,
        row_number() over (
            partition by lr.as_of_round_id, p.id
            order by p.round_id desc
        ) as round_rank
    from {{ ref('int_players') }} p
    inner join last_n_calendar_rounds lr on p.round_id = lr.round_id
    where p.season = 2026
),

latest_info as (
    select as_of_round_id, id, name, club, club_logo_url, position
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
        p.scout_G, p.scout_A, p.scout_FT, p.scout_FD, p.scout_FF, p.scout_FS, p.scout_PS,
        p.scout_DS, p.scout_SG, p.scout_DE, p.scout_DP,
        p.scout_FC, p.scout_PC, p.scout_CA, p.scout_CV, p.scout_GC, p.scout_GS, p.scout_I, p.scout_PP,
        row_number() over (
            partition by r.as_of_round_id, p.id
            order by p.round_id desc
        ) as played_rank
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026
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
    from last_n_played
    where played_rank <= 10
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
        p.avg_G, p.avg_A, p.avg_FT, p.avg_FD, p.avg_FF, p.avg_FS, p.avg_PS,
        p.avg_DS, p.avg_SG, p.avg_DE, p.avg_DP,
        p.avg_FC, p.avg_PC, p.avg_CA, p.avg_CV, p.avg_GC, p.avg_GS, p.avg_I, p.avg_PP
    from availability_calc a
    inner join latest_info l
        on a.as_of_round_id = l.as_of_round_id and a.id = l.id
    left join pts_calc p
        on a.as_of_round_id = p.as_of_round_id and a.id = p.id
),

-- Enrichment: z-scores and DVS (see scouting_enrichment macro for details)
{{ scouting_enrichment(by_round=true) }}
