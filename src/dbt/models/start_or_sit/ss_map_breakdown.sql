/*
Start or Sit: MAP Breakdown (Subtab)

Thin mart: detailed MAP component values from int_map_score.
Allows users to see exactly how each component affects the final projection.
*/

select
    m.as_of_round_id,
    m.id as player_id,
    m.player_name,
    m.position,
    m.club,
    m.club_logo_url,
    m.opponent_club,
    m.is_home_next as is_home,
    m.baseline_pts,
    m.ewm_pts as ewm_form_points,
    m.form_multiplier,
    m.venue_multiplier as home_away_multiplier,
    m.mpap_multiplier,
    m.map_score as map_points,
    poe.avg_poe_season,
    poe.avg_poe_last_5,
    m.map_rank_pos,
    m.map_rank_gen
from {{ ref('int_map_score') }} as m
left join {{ ref('int_poe') }} as poe
    on m.as_of_round_id = poe.as_of_round_id and m.id = poe.id
