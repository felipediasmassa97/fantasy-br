/*
Start or Sit: Player Home vs Away (Subtab)

Thin mart: home/away performance breakdown from int_home_away + int_baseline.
Shows split averages, delta, and multipliers per player.
*/

select
    b.as_of_round_id,
    b.id as player_id,
    b.player_name,
    b.position,
    b.club,
    b.club_logo_url,
    v.matches_home_this_season,
    v.player_pts_avg_home_this_season as avg_points_home_this_season,
    v.matches_away_this_season,
    v.player_pts_avg_away_this_season as avg_points_away_this_season,
    v.matches_home_last_season,
    v.player_pts_avg_home_last_season as avg_points_home_last_season,
    v.matches_away_last_season,
    v.player_pts_avg_away_last_season as avg_points_away_last_season,
    v.position_pts_avg_home_last_season as position_avg_points_home_last_season,
    v.position_pts_avg_away_last_season as position_avg_points_away_last_season,
    v.home_away_delta,
    v.multiplier_home,
    v.multiplier_away,
    m.map_score
from {{ ref('int_baseline') }} as b
left join {{ ref('int_home_away') }} as v
    on b.as_of_round_id = v.as_of_round_id and b.id = v.id
left join {{ ref('int_map_score') }} as m
    on b.as_of_round_id = m.as_of_round_id and b.id = m.id
