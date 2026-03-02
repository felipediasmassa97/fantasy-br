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
        p.player_name,
        p.club,
        p.club_logo_url,
        p.position,
        p.round_id,
        p.pts_round,
        p.base_round,
        p.has_played,
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
        ) as match_rank
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where
        p.season = 2026
        and p.round_id <= r.as_of_round_id
),

-- Most recent player info (name, club may change mid-season)
latest_info as (
    select
        as_of_round_id,
        id,
        player_name,
        club,
        club_logo_url,
        position
    from ranked_matches
    where match_rank = 1
),

-- Season-to-date aggregates: average of all played matches
player_pts as (
    select
        r.as_of_round_id,
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
    inner join latest_info as l
        on r.as_of_round_id = l.as_of_round_id and r.id = l.id
    group by r.as_of_round_id, r.id, l.player_name, l.club, l.club_logo_url, l.position
),

-- Enrichment: z-scores and DVS (see scouting_enrichment macro for details)
{{ scouting_enrichment(by_round=true) }}
