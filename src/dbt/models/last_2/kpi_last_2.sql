{{ config(materialized='view') }}

-- fixit remove model

with last_2_rounds as (
    select distinct round_id
    from {{ ref('int_players') }}
    where season = 2026
    order by round_id desc
    limit 2
),

player_rounds as (
    select
        p.id,
        p.name,
        p.club,
        p.position,
        p.round_id,
        p.has_played,
        row_number() over (partition by p.id order by p.round_id desc) as round_rank
    from {{ ref('int_players') }} p
    inner join last_2_rounds r on p.round_id = r.round_id
    where p.season = 2026
),

latest_info as (
    select id, name, club, position
    from player_rounds
    where round_rank = 1
),

availability_calc as (
    select
        id,
        countif(has_played = true) as matches_counted,
        countif(has_played = true) / count(*) as availability
    from player_rounds
    group by id
),

last_2_played as (
    select
        id,
        pts_round,
        row_number() over (partition by id order by round_id desc) as played_rank
    from {{ ref('int_players') }}
    where season = 2026 and has_played = true
),

pts_calc as (
    select
        id,
        avg(pts_round) as pts_avg
    from last_2_played
    where played_rank <= 2
    group by id
)

select
    a.id,
    l.name,
    l.club,
    l.position,
    a.matches_counted,
    p.pts_avg,
    a.availability
from availability_calc a
join latest_info l on a.id = l.id
left join pts_calc p on a.id = p.id
