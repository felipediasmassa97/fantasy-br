/*
Start or Sit: Opponent & MPAP Debug (Subtab)

Thin mart: detailed MPAP opponent analysis from int_map_mpap.
Shows how opponent strength is measured and blended across seasons.
*/

select
    o.as_of_round_id,
    oc.abbreviation as opponent_team,
    o.position,
    o.games_this_season as games_in_sample_this_season,
    o.games_last_season as games_in_sample_last_season,
    o.pts_allowed_this_season_avg as points_allowed_this_season_avg,
    o.pts_allowed_last_season_avg as points_allowed_last_season_avg,
    o.pts_allowed_avg as points_allowed_avg,
    o.league_avg_pts as league_avg_allowed_pos,
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
