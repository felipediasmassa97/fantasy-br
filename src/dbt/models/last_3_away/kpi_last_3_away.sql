{{ config(materialized='view') }}

with player_away_rounds as (
    select
        id,
        name,
        club,
        position,
        round_id,
        has_played,
        row_number() over (partition by id order by round_id desc) as round_rank
    from {{ ref('int_players') }}
    where season = 2026 and is_home = false
),

latest_info as (
    select id, name, club, position
    from player_away_rounds
    where round_rank = 1
),

availability_calc as (
    select
        id,
        countif(has_played = true) as matches_counted,
        countif(has_played = true) / count(*) as availability
    from player_away_rounds
    where round_rank <= 3
    group by id
),

last_3_away_played as (
    select
        id,
        pts_round,
        base_round,
        row_number() over (partition by id order by round_id desc) as played_rank
    from {{ ref('int_players') }}
    where season = 2026 and is_home = false and has_played = true
),

pts_calc as (
    select
        id,
        avg(pts_round) as pts_avg,
        avg(base_round) as base_avg
    from last_3_away_played
    where played_rank <= 3
    group by id
),

player_pts as (
    select
        a.id,
        l.name,
        l.club,
        l.position,
        a.matches_counted,
        p.pts_avg,
        p.base_avg,
        a.availability
    from availability_calc a
    join latest_info l on a.id = l.id
    left join pts_calc p on a.id = p.id
),

position_stats_avg as (
    {{ position_stats_cte('pts_avg') }}
),

position_stats_base as (
    {{ position_stats_cte('base_avg') }}
),

general_stats_avg as (
    {{ general_stats_cte('pts_avg') }}
),

general_stats_base as (
    {{ general_stats_cte('base_avg') }}
),

with_z_score as (
    select
        p.*,
        {{ z_score_general('p.pts_avg', 'gsa') }} as z_score_gen_avg,
        {{ z_score_general('p.base_avg', 'gsb') }} as z_score_gen_base,
        {{ z_score_position('p.pts_avg', 'psa') }} as z_score_pos_avg,
        {{ z_score_position('p.base_avg', 'psb') }} as z_score_pos_base
    from player_pts p
    left join position_stats_avg psa on p.position = psa.position
    left join position_stats_base psb on p.position = psb.position
    cross join general_stats_avg gsa
    cross join general_stats_base gsb
),

with_dvs as (
    select
        *,
        {{ dvs('z_score_gen_avg', 'availability') }} as dvs_gen_avg,
        {{ dvs('z_score_gen_base', 'availability') }} as dvs_gen_base,
        {{ dvs('z_score_pos_avg', 'availability') }} as dvs_pos_avg,
        {{ dvs('z_score_pos_base', 'availability') }} as dvs_pos_base
    from with_z_score
)

select
    *,
    row_number() over (order by dvs_gen_avg desc nulls last) as adp_gen_avg,
    row_number() over (order by dvs_gen_base desc nulls last) as adp_gen_base,
    row_number() over (partition by position order by dvs_pos_avg desc nulls last) as adp_pos_avg,
    row_number() over (partition by position order by dvs_pos_base desc nulls last) as adp_pos_base
from with_dvs
