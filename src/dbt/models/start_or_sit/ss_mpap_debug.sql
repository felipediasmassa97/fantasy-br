/*
Start or Sit: Opponent & MPAP Debug (Subtab)

Thin mart: detailed MPAP opponent analysis from int_map_mpap.
Shows how opponent strength is measured and blended across seasons.
*/

select
    o.as_of_round_id,
    oc.abbreviation as opponent_club,
    oc.logo_url as opponent_logo_url,
    o.position,
    o.matches_this_season,
    o.matches_last_season,
    o.pts_allowed_this_season_avg,
    o.pts_allowed_last_season_avg,
    o.pts_allowed_avg,
    o.league_avg_pts as pts_allowed_avg_league,
    o.mpap_ratio,
    o.mpap_multiplier,
    o.as_of_round_id as last_updated_round
from {{ ref('int_map_mpap') }} as o
left join {{ ref('stg_clubs') }} as oc on o.opponent_id = oc.id
-- Deduplicate: show one row per opponent-position-round (not per player)
qualify row_number() over (
    partition by o.as_of_round_id, o.opponent_id, o.position
    order by o.id
) = 1
