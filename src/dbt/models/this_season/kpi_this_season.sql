{{ config(materialized='view') }}

with ranked_matches as (
    select
        id,
        name,
        club,
        position,
        round_id,
        pts_round,
        row_number() over (partition by id order by round_id desc) as match_rank
    from {{ ref('int_players') }}
    where season = 2026
),

latest_info as (
    select id, name, club, position
    from ranked_matches
    where match_rank = 1
),

aggregated as (
    select
        id,
        count(*) as matches_counted,
        avg(pts_round) as pts_avg
    from ranked_matches
    group by id
)

select
    a.id,
    l.name,
    l.club,
    l.position,
    a.matches_counted,
    a.pts_avg
from aggregated a
join latest_info l on a.id = l.id
