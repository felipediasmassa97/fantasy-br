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
        {{ z_score('pts_avg') }} as z_score
    from player_pts
),

with_dvs as (
    select
        *,
        {{ dvs('z_score', 'availability') }} as dvs
    from with_z_score
)

select
    *,
    row_number() over (order by dvs desc nulls last) as adp
from with_dvs
