/*
Scouting Intermediate: Last Season Stats (2025)

Computes stats over the complete previous season (2025).
No as_of_round_id dimension since this covers an entire past season.
- Stats are the full season average for played matches.
- Availability = matches played / total rounds in season 2025.

Enriched with z-scores and DVS via scouting_enrichment macro (by_round=false).
*/

with ranked_matches as (
    -- All matches from season 2025, ranked by recency for latest info
    select
        id,
        name,
        club,
        club_logo_url,
        position,
        round_id,
        pts_round,
        base_round,
        has_played,
        scout_G, scout_A, scout_FT, scout_FD, scout_FF, scout_FS, scout_PS,
        scout_DS, scout_SG, scout_DE, scout_DP,
        scout_FC, scout_PC, scout_CA, scout_CV, scout_GC, scout_GS, scout_I, scout_PP,
        row_number() over (partition by id order by round_id desc) as match_rank
    from {{ ref('int_players') }}
    where season = 2025
),

-- Most recent player info from season 2025
latest_info as (
    select id, name, club, club_logo_url, position
    from ranked_matches
    where match_rank = 1
),

-- Full season 2025 aggregates
player_pts as (
    select
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
    inner join latest_info l on r.id = l.id
    group by r.id, l.name, l.club, l.club_logo_url, l.position
),

-- Enrichment: z-scores and DVS (no round dimension for last season)
{{ scouting_enrichment(by_round=false) }}
