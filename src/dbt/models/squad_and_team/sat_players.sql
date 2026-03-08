/*
Squad and Team: Player Roster

Thin mart: enriched player list for squad and team management.
Joins base player data with MAP projection, PoE, next opponent and market
valuation signals for display in the Squad and Team page.
*/

select
    s.as_of_round_id,
    s.id as player_id,
    s.player_name,
    s.club,
    s.club_logo_url,
    s.position,
    ss.map_score,
    ss.avg_poe_last_5,
    mb.opponent_club,
    ss.is_home_next,
    mv.par,
    mv.regression_score
from {{ ref('int_map_score') }} as s
left join {{ ref('ss_main') }} as ss
    on s.as_of_round_id = ss.as_of_round_id and s.id = ss.player_id
left join {{ ref('ss_map_breakdown') }} as mb
    on s.as_of_round_id = mb.as_of_round_id and s.id = mb.player_id
left join {{ ref('mv_main') }} as mv
    on s.as_of_round_id = mv.as_of_round_id and s.id = mv.player_id
