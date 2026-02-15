{{ config(materialized='view') }}

with last_round as (
    select max(round_id) as max_round_id
    from {{ ref('int_players') }}
    where season = 2026 and has_played = true
)

select
    p.id,
    p.name,
    p.club,
    p.position,
    p.round_id,
    p.pts_round as pts_avg
from {{ ref('int_players') }} p
cross join last_round lr
where p.season = 2026
  and p.has_played = true
  and p.round_id = lr.max_round_id
