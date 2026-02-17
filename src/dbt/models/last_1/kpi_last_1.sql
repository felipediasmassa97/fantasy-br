{{ config(materialized='view') }}

with last_round as (
    select max(round_id) as max_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

last_round_status as (
    select
        p.id,
        p.name,
        p.club,
        p.position,
        p.has_played
    from {{ ref('int_players') }} p
    cross join last_round lr
    where p.season = 2026 and p.round_id = lr.max_round_id
),

last_played_stats as (
    select
        id,
        pts_round,
        base_round,
        row_number() over (partition by id order by round_id desc) as rn
    from {{ ref('int_players') }}
    where season = 2026 and has_played = true
),

player_pts as (
    select
        s.id,
        s.name,
        s.club,
        s.position,
        if(s.has_played, 1, 0) as matches_counted,
        lp.pts_round as pts_avg,
        lp.base_round as base_avg,
        if(s.has_played, 1.0, 0.0) as availability
    from last_round_status s
    left join last_played_stats lp on s.id = lp.id and lp.rn = 1
),

with_z_score as (
    select
        *,
        {{ z_score_general('pts_avg') }} as z_score_gen,
        {{ z_score_position('pts_avg', 'position') }} as z_score_pos
    from player_pts
),

with_dvs as (
    select
        *,
        {{ dvs('z_score_gen', 'availability') }} as dvs_gen,
        {{ dvs('z_score_pos', 'availability') }} as dvs_pos
    from with_z_score
)

select
    *,
    row_number() over (order by dvs_gen desc nulls last) as adp_gen,
    row_number() over (partition by position order by dvs_pos desc nulls last) as adp_pos
from with_dvs
