/*
Squad and Team: Player Roster

Thin mart: enriched player list for squad and team management.
Joins base player data with MAP projection, PoE, next opponent and market
valuation signals for display in the Squad and Team page.
*/

with ss_main_enriched as (
    select
        ss.as_of_round_id,
        ss.player_id,
        ss.map_score,
        ss.avg_poe_last_5,
        ss.is_home_next
    from {{ ref('ss_main') }} as ss
    group by
        ss.as_of_round_id,
        ss.player_id,
        ss.map_score,
        ss.avg_poe_last_5,
        ss.is_home_next
),

ss_map_breakdown_enriched as (
    select
        mb.as_of_round_id,
        mb.player_id,
        mb.opponent_club
    from {{ ref('ss_map_breakdown') }} as mb
    group by
        mb.as_of_round_id,
        mb.player_id,
        mb.opponent_club
),

mv_main_enriched as (
    select
        mv.as_of_round_id,
        mv.player_id,
        mv.par,
        mv.regression_score
    from {{ ref('mv_main') }} as mv
    group by
        mv.as_of_round_id,
        mv.player_id,
        mv.par,
        mv.regression_score
)

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
left join ss_main_enriched as ss
    on s.as_of_round_id = ss.as_of_round_id and s.id = ss.player_id
left join ss_map_breakdown_enriched as mb
    on s.as_of_round_id = mb.as_of_round_id and s.id = mb.player_id
left join mv_main_enriched as mv
    on s.as_of_round_id = mv.as_of_round_id and s.id = mv.player_id