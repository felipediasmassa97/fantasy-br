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
    p.scout,
    case
        when m.club_home_id = p.club_id then true
        when m.club_away_id = p.club_id then false
    end as is_home
from {{ ref('stg_players') }} p
left join {{ ref('stg_clubs') }} c on p.club_id = c.id
left join {{ ref('stg_positions') }} pos on p.position_id = pos.id
left join {{ ref('stg_matches') }} m
    on p.season = m.season
    and p.round_id = m.round_id
    and (p.club_id = m.club_home_id or p.club_id = m.club_away_id)
