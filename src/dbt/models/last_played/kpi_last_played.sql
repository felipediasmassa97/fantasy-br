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

last_played_points as (
    select
        id,
        pts_round,
        row_number() over (partition by id order by round_id desc) as rn
    from {{ ref('int_players') }}
    where season = 2026 and has_played = true
)

select
    s.id,
    s.name,
    s.club,
    s.position,
    cast(s.has_played as int64) as matches_counted,
    lp.pts_round as pts_avg,
    cast(s.has_played as float64) as availability
from last_round_status s
left join last_played_points lp on s.id = lp.id and lp.rn = 1
