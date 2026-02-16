{{ config(materialized='view') }}

with ranked_matches as (
    select
        id,
        name,
        club,
        position,
        round_id,
        pts_round,
        has_played,
        row_number() over (partition by id order by round_id desc) as match_rank
    from {{ ref('int_players') }}
    where season = 2025
),

latest_info as (
    select id, name, club, position
    from ranked_matches
    where match_rank = 1
),

aggregated as (
    select
        id,
        countif(has_played = true) as matches_counted,
        avg(if(has_played, pts_round, null)) as pts_avg,
        countif(has_played = true) / count(*) as availability
    from ranked_matches
    group by id
)

select
    a.id,
    l.name,
    l.club,
    l.position,
    a.matches_counted,
    a.pts_avg,
    a.availability
from aggregated a
join latest_info l on a.id = l.id
