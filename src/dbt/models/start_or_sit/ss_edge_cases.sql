/*
Start or Sit: Edge Cases & Missing Data (Subtab)

Thin mart: data quality flags per player.
See int_edge_cases for computation.
*/

select
    e.player_id,
    e.player_name,
    e.position,
    e.club,
    e.club_logo_url,
    e.has_last_season_data,
    e.matches_last_season,
    e.matches_this_season,
    e.first_round_seen,
    e.last_round_seen,
    e.missing_home_away_flag,
    e.missing_opponent_flag,
    e.missing_points_flag,
    m.map_score
from {{ ref('int_edge_cases') }} as e
left join (
    select id, map_score
    from {{ ref('int_map_score') }}
    qualify row_number() over (partition by id order by as_of_round_id desc) = 1
) as m on e.player_id = m.id
