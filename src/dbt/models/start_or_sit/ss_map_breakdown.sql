/*
Start or Sit: MAP Breakdown (Subtab)

Thin mart: detailed MAP component values from int_map_score.
Allows users to see exactly how each component affects the final projection.
*/

select
    as_of_round_id,
    name as player_name,
    id as player_id,
    position,
    club as team,
    opponent_team,
    is_home_next as is_home,
    baseline_pts,
    ewm_pts as ewm_form_points,
    form_multiplier,
    venue_multiplier as home_away_multiplier,
    mpap_multiplier,
    map_score as map_points,
    map_rank_pos,
    map_rank_gen
from {{ ref('int_map_score') }}
