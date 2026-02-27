/*
Round-by-Round Raw Player Data

Enriches int_players with opponent team name for round-level audit.
One row per player per round (season 2026 only).
Used by both Start/Sit and Market Valuation round-by-round tabs.
*/

select
    p.round_id as round,
    p.match_id,
    p.id as player_id,
    p.name as player_name,
    p.position,
    p.club as team,
    oc.abbreviation as opponent_team,
    p.is_home,
    p.pts_round as points_total,
    p.base_round as points_base,
    p.scout_G as goals,
    p.scout_A as assists,
    p.has_played as did_play,
    -- All scout columns for detailed analysis
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
    p.scout_PP
from {{ ref('int_players') }} p
left join {{ ref('stg_clubs') }} oc on p.opponent_id = oc.id
where p.season = 2026
