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
        player_name,
        club,
        club_logo_url,
        position,
        round_id,
        pts_round,
        base_round,
        has_played,
        scout_g,
        scout_a,
        scout_ft,
        scout_fd,
        scout_ff,
        scout_fs,
        scout_ps,
        scout_ds,
        scout_sg,
        scout_de,
        scout_dp,
        scout_fc,
        scout_pc,
        scout_ca,
        scout_cv,
        scout_gc,
        scout_gs,
        scout_i,
        scout_pp,
        row_number() over (partition by id order by round_id desc) as match_rank
    from {{ ref('int_players') }}
    where season = 2025
),

-- Most recent player info from season 2025
latest_info as (
    select
        id,
        player_name,
        club,
        club_logo_url,
        position
    from ranked_matches
    where match_rank = 1
),

-- Full season 2025 aggregates
player_pts as (
    select
        r.id,
        l.player_name,
        l.club,
        l.club_logo_url,
        l.position,
        countif(r.has_played = true) as matches_counted,
        avg(if(r.has_played, r.pts_round, null)) as pts_avg,
        avg(if(r.has_played, r.base_round, null)) as base_avg,
        countif(r.has_played = true) / count(*) as availability,
        avg(if(r.has_played, r.scout_g, null)) as avg_g,
        avg(if(r.has_played, r.scout_a, null)) as avg_a,
        avg(if(r.has_played, r.scout_ft, null)) as avg_ft,
        avg(if(r.has_played, r.scout_fd, null)) as avg_fd,
        avg(if(r.has_played, r.scout_ff, null)) as avg_ff,
        avg(if(r.has_played, r.scout_fs, null)) as avg_fs,
        avg(if(r.has_played, r.scout_ps, null)) as avg_ps,
        avg(if(r.has_played, r.scout_ds, null)) as avg_ds,
        avg(if(r.has_played, r.scout_sg, null)) as avg_sg,
        avg(if(r.has_played, r.scout_de, null)) as avg_de,
        avg(if(r.has_played, r.scout_dp, null)) as avg_dp,
        avg(if(r.has_played, r.scout_fc, null)) as avg_fc,
        avg(if(r.has_played, r.scout_pc, null)) as avg_pc,
        avg(if(r.has_played, r.scout_ca, null)) as avg_ca,
        avg(if(r.has_played, r.scout_cv, null)) as avg_cv,
        avg(if(r.has_played, r.scout_gc, null)) as avg_gc,
        avg(if(r.has_played, r.scout_gs, null)) as avg_gs,
        avg(if(r.has_played, r.scout_i, null)) as avg_i,
        avg(if(r.has_played, r.scout_pp, null)) as avg_pp
    from ranked_matches as r
    inner join latest_info as l on r.id = l.id
    group by r.id, l.player_name, l.club, l.club_logo_url, l.position
),

-- Enrichment: z-scores and DVS (no round dimension for last season)
{{ scouting_enrichment(by_round=false) }}
