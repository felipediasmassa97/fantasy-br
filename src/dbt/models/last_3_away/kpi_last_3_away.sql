{{ config(materialized='view') }}

with player_away_rounds as (
    select
        id,
        name,
        club,
        position,
        round_id,
        has_played,
        row_number() over (partition by id order by round_id desc) as round_rank
    from {{ ref('int_players') }}
    where season = 2026 and is_home = false
),

latest_info as (
    select id, name, club, position
    from player_away_rounds
    where round_rank = 1
),

availability_calc as (
    select
        id,
        countif(has_played = true) as matches_counted,
        countif(has_played = true) / count(*) as availability
    from player_away_rounds
    where round_rank <= 3
    group by id
),

last_3_away_played as (
    select
        id,
        pts_round,
        base_round,
        row_number() over (partition by id order by round_id desc) as played_rank
    from {{ ref('int_players') }}
    where season = 2026 and is_home = false and has_played = true
),

pts_calc as (
    select
        id,
        avg(pts_round) as pts_avg,
        avg(base_round) as base_avg
    from last_3_away_played
    where played_rank <= 3
    group by id
),

player_pts as (
    select
        a.id,
        l.name,
        l.club,
        l.position,
        a.matches_counted,
        p.pts_avg,
        p.base_avg,
        a.availability
    from availability_calc a
    join latest_info l on a.id = l.id
    left join pts_calc p on a.id = p.id
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
