/*
Scouting Intermediate: This Season Stats

For each as_of_round, computes season-to-date stats over ALL matches in season 2026.
- Stats are the full season average for played matches up to as_of_round.
- Availability = matches played / total rounds this season up to as_of_round.

Enriched with z-scores and DVS via scouting_enrichment macro.
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- All matches up to each as_of_round, with recency rank for latest info
ranked_matches as (
    select
        r.as_of_round_id,
        p.id,
        p.name,
        p.club,
        p.club_logo_url,
        p.position,
        p.round_id,
        p.pts_round,
        p.base_round,
        p.has_played,
        p.scout_G, p.scout_A, p.scout_FT, p.scout_FD, p.scout_FF, p.scout_FS, p.scout_PS,
        p.scout_DS, p.scout_SG, p.scout_DE, p.scout_DP,
        p.scout_FC, p.scout_PC, p.scout_CA, p.scout_CV, p.scout_GC, p.scout_GS, p.scout_I, p.scout_PP,
        row_number() over (
            partition by r.as_of_round_id, p.id
            order by p.round_id desc
        ) as match_rank
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026
        and p.round_id <= r.as_of_round_id
),

-- Most recent player info (name, club may change mid-season)
latest_info as (
    select as_of_round_id, id, name, club, club_logo_url, position
    from ranked_matches
    where match_rank = 1
),

-- Season-to-date aggregates: average of all played matches
player_pts as (
    select
        r.as_of_round_id,
        r.id,
        l.name,
        l.club,
        l.club_logo_url,
        l.position,
        countif(r.has_played = true) as matches_counted,
        avg(if(r.has_played, r.pts_round, null)) as pts_avg,
        avg(if(r.has_played, r.base_round, null)) as base_avg,
        countif(r.has_played = true) / count(*) as availability,
        avg(if(r.has_played, r.scout_G, null)) as avg_G,
        avg(if(r.has_played, r.scout_A, null)) as avg_A,
        avg(if(r.has_played, r.scout_FT, null)) as avg_FT,
        avg(if(r.has_played, r.scout_FD, null)) as avg_FD,
        avg(if(r.has_played, r.scout_FF, null)) as avg_FF,
        avg(if(r.has_played, r.scout_FS, null)) as avg_FS,
        avg(if(r.has_played, r.scout_PS, null)) as avg_PS,
        avg(if(r.has_played, r.scout_DS, null)) as avg_DS,
        avg(if(r.has_played, r.scout_SG, null)) as avg_SG,
        avg(if(r.has_played, r.scout_DE, null)) as avg_DE,
        avg(if(r.has_played, r.scout_DP, null)) as avg_DP,
        avg(if(r.has_played, r.scout_FC, null)) as avg_FC,
        avg(if(r.has_played, r.scout_PC, null)) as avg_PC,
        avg(if(r.has_played, r.scout_CA, null)) as avg_CA,
        avg(if(r.has_played, r.scout_CV, null)) as avg_CV,
        avg(if(r.has_played, r.scout_GC, null)) as avg_GC,
        avg(if(r.has_played, r.scout_GS, null)) as avg_GS,
        avg(if(r.has_played, r.scout_I, null)) as avg_I,
        avg(if(r.has_played, r.scout_PP, null)) as avg_PP
    from ranked_matches r
    inner join latest_info l
        on r.as_of_round_id = l.as_of_round_id and r.id = l.id
    group by r.as_of_round_id, r.id, l.name, l.club, l.club_logo_url, l.position
),

-- Enrichment: z-scores and DVS (see scouting_enrichment macro for details)
{{ scouting_enrichment(by_round=true) }}
