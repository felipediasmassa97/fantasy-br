{{ config(materialized='view') }}

with scout_points as (
    select code, points
    from {{ ref('scout_points') }}
),

base_players as (
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
),

-- Calculate per-round goals and assists from cumulative scout data
with_deltas as (
    select
        *,
        coalesce(scout.G, 0) - coalesce(lag(scout.G) over (partition by id, season order by round_id), 0) as goals_round,
        coalesce(scout.A, 0) - coalesce(lag(scout.A) over (partition by id, season order by round_id), 0) as assists_round
    from base_players
)

-- Calculate base_round (points without goals and assists)
select
    d.*,
    d.pts_round - (d.goals_round * gp.points) - (d.assists_round * ap.points) as base_round
from with_deltas d
cross join (select points from scout_points where code = 'G') gp
cross join (select points from scout_points where code = 'A') ap
