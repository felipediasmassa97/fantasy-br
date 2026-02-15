{{ config(materialized='view') }}

select
    p.season,
    p.round_id,
    p.id,
    p.name,
    c.abbreviation as club,
    pos.abbreviation as position,
    p.pts_round,
    p.pts_avg,
    p.has_played,
    p.matches_played,
    p.scout
from {{ ref('stg_players') }} p
left join {{ ref('stg_clubs') }} c on p.club_id = c.id
left join {{ ref('stg_positions') }} pos on p.position_id = pos.id
