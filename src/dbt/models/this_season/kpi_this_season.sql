{{ config(materialized='view') }}

with ranked_matches as (
    select
        id,
        name,
        club,
        position,
        round_id,
        pts_round,
        base_round,
        has_played,
        row_number() over (partition by id order by round_id desc) as match_rank
    from {{ ref('int_players') }}
    where season = 2026
),

latest_info as (
    select id, name, club, position
    from ranked_matches
    where match_rank = 1
),

player_pts as (
    select
        r.id,
        l.name,
        l.club,
        l.position,
        countif(r.has_played = true) as matches_counted,
        avg(if(r.has_played, r.pts_round, null)) as pts_avg,
        avg(if(r.has_played, r.base_round, null)) as base_avg,
        countif(r.has_played = true) / count(*) as availability
    from ranked_matches r
    join latest_info l on r.id = l.id
    group by r.id, l.name, l.club, l.position
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
