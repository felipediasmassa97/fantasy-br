with scout_points as (
    select
        code,
        points
    from {{ ref('raw_scout_points') }}
),

base_players as (
    select
        p.season,
        p.round_id,
        p.id,
        p.name,
        c.abbreviation as club,
        c.logo_url as club_logo_url,
        pos.abbreviation as position,
        p.pts_round,
        p.pts_avg,
        p.has_played,
        p.matches_played,
        p.scout,
        case
            when m.club_home_id = p.club_id then true
            when m.club_away_id = p.club_id then false
        end as is_home,
        p.club_id,
        m.match_id,
        case
            when p.club_id = m.club_home_id then m.club_away_id
            when p.club_id = m.club_away_id then m.club_home_id
        end as opponent_id
    from {{ ref('stg_players') }} as p
    left join {{ ref('stg_clubs') }} as c on p.club_id = c.id
    left join {{ ref('stg_positions') }} as pos on p.position_id = pos.id
    left join {{ ref('stg_matches') }} as m
        on
            p.season = m.season
            and p.round_id = m.round_id
            and (p.club_id = m.club_home_id or p.club_id = m.club_away_id)
),

-- Calculate per-round scout values from cumulative scout data
with_deltas as (
    select
        *,
        -- Offensive scouts
        coalesce(scout.G, 0) - coalesce(lag(scout.G) over (partition by id, season order by round_id), 0) as scout_g,
        coalesce(scout.A, 0) - coalesce(lag(scout.A) over (partition by id, season order by round_id), 0) as scout_a,
        coalesce(scout.FT, 0) - coalesce(lag(scout.FT) over (partition by id, season order by round_id), 0) as scout_ft,
        coalesce(scout.FD, 0) - coalesce(lag(scout.FD) over (partition by id, season order by round_id), 0) as scout_fd,
        coalesce(scout.FF, 0) - coalesce(lag(scout.FF) over (partition by id, season order by round_id), 0) as scout_ff,
        coalesce(scout.FS, 0) - coalesce(lag(scout.FS) over (partition by id, season order by round_id), 0) as scout_fs,
        coalesce(scout.PS, 0) - coalesce(lag(scout.PS) over (partition by id, season order by round_id), 0) as scout_ps,
        -- Defensive scouts
        coalesce(scout.DS, 0) - coalesce(lag(scout.DS) over (partition by id, season order by round_id), 0) as scout_ds,
        coalesce(scout.SG, 0) - coalesce(lag(scout.SG) over (partition by id, season order by round_id), 0) as scout_sg,
        coalesce(scout.DE, 0) - coalesce(lag(scout.DE) over (partition by id, season order by round_id), 0) as scout_de,
        coalesce(scout.DP, 0) - coalesce(lag(scout.DP) over (partition by id, season order by round_id), 0) as scout_dp,
        -- Negative scouts
        coalesce(scout.FC, 0) - coalesce(lag(scout.FC) over (partition by id, season order by round_id), 0) as scout_fc,
        coalesce(scout.PC, 0) - coalesce(lag(scout.PC) over (partition by id, season order by round_id), 0) as scout_pc,
        coalesce(scout.CA, 0) - coalesce(lag(scout.CA) over (partition by id, season order by round_id), 0) as scout_ca,
        coalesce(scout.CV, 0) - coalesce(lag(scout.CV) over (partition by id, season order by round_id), 0) as scout_cv,
        coalesce(scout.GC, 0) - coalesce(lag(scout.GC) over (partition by id, season order by round_id), 0) as scout_gc,
        coalesce(scout.GS, 0) - coalesce(lag(scout.GS) over (partition by id, season order by round_id), 0) as scout_gs,
        coalesce(scout.I, 0) - coalesce(lag(scout.I) over (partition by id, season order by round_id), 0) as scout_i,
        coalesce(scout.PP, 0) - coalesce(lag(scout.PP) over (partition by id, season order by round_id), 0) as scout_pp
    from base_players
)

-- Calculate base_round (points without goals and assists)
select
    d.season,
    d.round_id,
    d.id,
    d.name,
    d.club,
    d.club_logo_url,
    d.position,
    d.pts_round,
    d.pts_avg,
    d.has_played,
    d.matches_played,
    d.is_home,
    d.club_id,
    d.match_id,
    d.opponent_id,
    d.pts_round - (d.scout_g * gp.points) - (d.scout_a * ap.points) as base_round,
    -- Scout columns
    d.scout_g,
    d.scout_a,
    d.scout_ft,
    d.scout_fd,
    d.scout_ff,
    d.scout_fs,
    d.scout_ps,
    d.scout_ds,
    d.scout_sg,
    d.scout_de,
    d.scout_dp,
    d.scout_fc,
    d.scout_pc,
    d.scout_ca,
    d.scout_cv,
    d.scout_gc,
    d.scout_gs,
    d.scout_i,
    d.scout_pp
from with_deltas as d
cross join (
    select points from scout_points
    where code = 'G'
) as gp
cross join (
    select points from scout_points
    where code = 'A'
) as ap
