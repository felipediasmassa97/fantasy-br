/*
Start or Sit: Player Home vs Away (Subtab)

Thin mart: home/away performance breakdown from int_map_venue + int_baseline.
Shows split averages, delta, and multipliers per player.
*/

select
    b.as_of_round_id,
    b.name as player_name,
    b.id as player_id,
    b.position,
    b.club as team,
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
    v.home_multiplier as home_away_multiplier_home,
    v.away_multiplier as home_away_multiplier_away
from {{ ref('int_baseline') }} as b
left join {{ ref('int_map_venue') }} as v
    on b.as_of_round_id = v.as_of_round_id and b.id = v.id
