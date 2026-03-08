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
        p.player_name,
        c.abbreviation as club,
        c.logo_url as club_logo_url,
        pos.abbreviation as position,
        p.pts_round,
        p.pts_avg,
        p.has_played,
        p.matches_played,
        p.scout,
        p.club_id,
        m.match_id,
        case
            when m.club_home_id = p.club_id then true
            when m.club_away_id = p.club_id then false
        end as is_home,
        case
            when p.club_id = m.club_home_id then m.club_away_id
            when p.club_id = m.club_away_id then m.club_home_id
        end as opponent_id
    from {{ ref('stg_players') }} as p
    left join {{ ref('stg_clubs') }} as c on p.club_id = c.id
    left join {{ ref('stg_positions') }} as pos on p.position_id = pos.id
    left join {{ ref('int_matches') }} as m
        on
            p.season = m.season
            and p.round_id = m.round_id
            and (p.club_id = m.club_home_id or p.club_id = m.club_away_id)
),

goal_points as (
    select points
    from scout_points
    where code = 'G'
),

assist_points as (
    select points
    from scout_points
    where code = 'A'
),

red_card_points as (
    select points
    from scout_points
    where code = 'CV'
),

own_goal_points as (
    select points
    from scout_points
    where code = 'GC'
),

-- Calculate per-round scout values from cumulative scout data
with_deltas as (
    select
        *,
        -- Offensive scouts
        coalesce(scout.g, 0) - coalesce(lag(scout.g) over (partition by id, season order by round_id), 0) as scout_g,
        coalesce(scout.a, 0) - coalesce(lag(scout.a) over (partition by id, season order by round_id), 0) as scout_a,
        coalesce(scout.ft, 0) - coalesce(lag(scout.ft) over (partition by id, season order by round_id), 0) as scout_ft,
        coalesce(scout.fd, 0) - coalesce(lag(scout.fd) over (partition by id, season order by round_id), 0) as scout_fd,
        coalesce(scout.ff, 0) - coalesce(lag(scout.ff) over (partition by id, season order by round_id), 0) as scout_ff,
        coalesce(scout.fs, 0) - coalesce(lag(scout.fs) over (partition by id, season order by round_id), 0) as scout_fs,
        coalesce(scout.ps, 0) - coalesce(lag(scout.ps) over (partition by id, season order by round_id), 0) as scout_ps,
        -- Defensive scouts
        coalesce(scout.ds, 0) - coalesce(lag(scout.ds) over (partition by id, season order by round_id), 0) as scout_ds,
        coalesce(scout.sg, 0) - coalesce(lag(scout.sg) over (partition by id, season order by round_id), 0) as scout_sg,
        coalesce(scout.de, 0) - coalesce(lag(scout.de) over (partition by id, season order by round_id), 0) as scout_de,
        coalesce(scout.dp, 0) - coalesce(lag(scout.dp) over (partition by id, season order by round_id), 0) as scout_dp,
        -- Negative scouts
        coalesce(scout.fc, 0) - coalesce(lag(scout.fc) over (partition by id, season order by round_id), 0) as scout_fc,
        coalesce(scout.pc, 0) - coalesce(lag(scout.pc) over (partition by id, season order by round_id), 0) as scout_pc,
        coalesce(scout.ca, 0) - coalesce(lag(scout.ca) over (partition by id, season order by round_id), 0) as scout_ca,
        coalesce(scout.cv, 0) - coalesce(lag(scout.cv) over (partition by id, season order by round_id), 0) as scout_cv,
        coalesce(scout.gc, 0) - coalesce(lag(scout.gc) over (partition by id, season order by round_id), 0) as scout_gc,
        coalesce(scout.gs, 0) - coalesce(lag(scout.gs) over (partition by id, season order by round_id), 0) as scout_gs,
        coalesce(scout.i, 0) - coalesce(lag(scout.i) over (partition by id, season order by round_id), 0) as scout_i,
        coalesce(scout.pp, 0) - coalesce(lag(scout.pp) over (partition by id, season order by round_id), 0) as scout_pp
    from base_players
)

-- Calculate base_round (points without goals, assists, red cards, and own goals)
select
    d.season,
    d.round_id,
    d.id,
    d.player_name,
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
    d.scout_pp,
    -- Base points (without goals, assists, red cards, and own goals)
    d.pts_round
    - (d.scout_g * gp.points)
    - (d.scout_a * ap.points)
    - (d.scout_cv * cvp.points)
    - (d.scout_gc * gcp.points) as base_round
from with_deltas as d
cross join goal_points as gp
cross join assist_points as ap
cross join red_card_points as cvp
cross join own_goal_points as gcp
