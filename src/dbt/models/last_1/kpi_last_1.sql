{{ config(materialized='view') }}

with scout_points as (
    select code, points
    from {{ ref('scout_points') }}
),

goal_points as (
    select points from scout_points where code = 'G'
),

assist_points as (
    select points from scout_points where code = 'A'
),

last_round as (
    select max(round_id) as max_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

last_round_status as (
    select
        p.id,
        p.name,
        p.club,
        p.position,
        p.has_played
    from {{ ref('int_players') }} p
    cross join last_round lr
    where p.season = 2026 and p.round_id = lr.max_round_id
),

-- Calculate per-round goals and assists from cumulative scout data
players_with_deltas as (
    select
        id,
        round_id,
        pts_round,
        has_played,
        coalesce(scout.G, 0) as goals_cumulative,
        coalesce(scout.A, 0) as assists_cumulative,
        coalesce(scout.G, 0) - coalesce(lag(scout.G) over (partition by id order by round_id), 0) as goals_round,
        coalesce(scout.A, 0) - coalesce(lag(scout.A) over (partition by id order by round_id), 0) as assists_round
    from {{ ref('int_players') }}
    where season = 2026
),

last_played_stats as (
    select
        id,
        pts_round,
        goals_round,
        assists_round,
        row_number() over (partition by id order by round_id desc) as rn
    from players_with_deltas
    where has_played = true
)

select
    s.id,
    s.name,
    s.club,
    s.position,
    if(s.has_played, 1, 0) as matches_counted,
    lp.pts_round as pts_avg,
    lp.pts_round - (lp.goals_round * gp.points) - (lp.assists_round * ap.points) as base_avg,
    if(s.has_played, 1.0, 0.0) as availability
from last_round_status s
left join last_played_stats lp on s.id = lp.id and lp.rn = 1
cross join goal_points gp
cross join assist_points ap
