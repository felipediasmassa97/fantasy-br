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

-- Calculate per-round scout values from cumulative scout data
with_deltas as (
    select
        *,
        -- Offensive scouts
        coalesce(scout.G, 0) - coalesce(lag(scout.G) over (partition by id, season order by round_id), 0) as scout_G,
        coalesce(scout.A, 0) - coalesce(lag(scout.A) over (partition by id, season order by round_id), 0) as scout_A,
        coalesce(scout.FT, 0) - coalesce(lag(scout.FT) over (partition by id, season order by round_id), 0) as scout_FT,
        coalesce(scout.FD, 0) - coalesce(lag(scout.FD) over (partition by id, season order by round_id), 0) as scout_FD,
        coalesce(scout.FF, 0) - coalesce(lag(scout.FF) over (partition by id, season order by round_id), 0) as scout_FF,
        coalesce(scout.FS, 0) - coalesce(lag(scout.FS) over (partition by id, season order by round_id), 0) as scout_FS,
        coalesce(scout.PS, 0) - coalesce(lag(scout.PS) over (partition by id, season order by round_id), 0) as scout_PS,
        -- Defensive scouts
        coalesce(scout.DS, 0) - coalesce(lag(scout.DS) over (partition by id, season order by round_id), 0) as scout_DS,
        coalesce(scout.SG, 0) - coalesce(lag(scout.SG) over (partition by id, season order by round_id), 0) as scout_SG,
        coalesce(scout.DE, 0) - coalesce(lag(scout.DE) over (partition by id, season order by round_id), 0) as scout_DE,
        coalesce(scout.DP, 0) - coalesce(lag(scout.DP) over (partition by id, season order by round_id), 0) as scout_DP,
        -- Negative scouts
        coalesce(scout.FC, 0) - coalesce(lag(scout.FC) over (partition by id, season order by round_id), 0) as scout_FC,
        coalesce(scout.PC, 0) - coalesce(lag(scout.PC) over (partition by id, season order by round_id), 0) as scout_PC,
        coalesce(scout.CA, 0) - coalesce(lag(scout.CA) over (partition by id, season order by round_id), 0) as scout_CA,
        coalesce(scout.CV, 0) - coalesce(lag(scout.CV) over (partition by id, season order by round_id), 0) as scout_CV,
        coalesce(scout.GC, 0) - coalesce(lag(scout.GC) over (partition by id, season order by round_id), 0) as scout_GC,
        coalesce(scout.GS, 0) - coalesce(lag(scout.GS) over (partition by id, season order by round_id), 0) as scout_GS,
        coalesce(scout.I, 0) - coalesce(lag(scout.I) over (partition by id, season order by round_id), 0) as scout_I,
        coalesce(scout.PP, 0) - coalesce(lag(scout.PP) over (partition by id, season order by round_id), 0) as scout_PP
    from base_players
)

-- Calculate base_round (points without goals and assists)
select
    d.season,
    d.round_id,
    d.id,
    d.name,
    d.club,
    d.position,
    d.pts_round,
    d.pts_avg,
    d.has_played,
    d.matches_played,
    d.is_home,
    d.pts_round - (d.scout_G * gp.points) - (d.scout_A * ap.points) as base_round,
    -- Scout columns
    d.scout_G,
    d.scout_A,
    d.scout_FT,
    d.scout_FD,
    d.scout_FF,
    d.scout_FS,
    d.scout_PS,
    d.scout_DS,
    d.scout_SG,
    d.scout_DE,
    d.scout_DP,
    d.scout_FC,
    d.scout_PC,
    d.scout_CA,
    d.scout_CV,
    d.scout_GC,
    d.scout_GS,
    d.scout_I,
    d.scout_PP
from with_deltas d
cross join (select points from scout_points where code = 'G') gp
cross join (select points from scout_points where code = 'A') ap
