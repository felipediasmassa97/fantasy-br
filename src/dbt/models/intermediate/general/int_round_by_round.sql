/*
Round-by-Round Raw Player Data

Enriches int_players with opponent club name for round-level audit.
One row per player per round (season 2026 only).
Used by both Start/Sit and Market Valuation round-by-round tabs.
*/

select
    p.round_id as round,
    p.match_id,
    p.id as player_id,
    p.player_name,
    p.position,
    p.club,
    p.club_logo_url,
    oc.abbreviation as opponent_club,
    oc.logo_url as opponent_logo_url,
    p.is_home,
    p.pts_round as points_total,
    p.base_round as points_base,
    p.has_played as did_play,
    -- All scout columns for detailed analysis
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
    p.scout_pp
from {{ ref('int_players') }} as p
left join {{ ref('stg_clubs') }} as oc on p.opponent_id = oc.id
where p.season = 2026
