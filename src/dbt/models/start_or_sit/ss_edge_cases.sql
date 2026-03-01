/*
Start or Sit: Edge Cases & Missing Data (Subtab)

Thin mart: data quality flags per player.
See int_edge_cases for computation.
*/

select
    player_id,
    player_name,
    position,
    club,
    club_logo_url,
    has_last_season_data,
    matches_last_season,
    matches_this_season,
    first_round_seen,
    last_round_seen,
    missing_home_away_flag,
    missing_opponent_flag,
    missing_points_flag
from {{ ref('int_edge_cases') }}
