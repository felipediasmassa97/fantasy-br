{{ config(materialized='view') }}

with player_home_rounds as (
    select
        id,
        name,
        club,
        position,
        round_id,
        has_played,
        row_number() over (partition by id order by round_id desc) as round_rank
    from {{ ref('int_players') }}
    where season = 2026 and is_home = true
),

latest_info as (
    select id, name, club, position
    from player_home_rounds
    where round_rank = 1
),

availability_calc as (
    select
        id,
        countif(has_played = true) as matches_counted,
        countif(has_played = true) / count(*) as availability
    from player_home_rounds
    where round_rank <= 3
    group by id
),

last_3_home_played as (
    select
        id,
        pts_round,
        base_round,
        scout_G, scout_A, scout_FT, scout_FD, scout_FF, scout_FS, scout_PS,
        scout_DS, scout_SG, scout_DE, scout_DP,
        scout_FC, scout_PC, scout_CA, scout_CV, scout_GC, scout_GS, scout_I, scout_PP,
        row_number() over (partition by id order by round_id desc) as played_rank
    from {{ ref('int_players') }}
    where season = 2026 and is_home = true and has_played = true
),

pts_calc as (
    select
        id,
        avg(pts_round) as pts_avg,
        avg(base_round) as base_avg,
        -- Offensive scouts
        avg(scout_G) as avg_G,
        avg(scout_A) as avg_A,
        avg(scout_FT) as avg_FT,
        avg(scout_FD) as avg_FD,
        avg(scout_FF) as avg_FF,
        avg(scout_FS) as avg_FS,
        avg(scout_PS) as avg_PS,
        -- Defensive scouts
        avg(scout_DS) as avg_DS,
        avg(scout_SG) as avg_SG,
        avg(scout_DE) as avg_DE,
        avg(scout_DP) as avg_DP,
        -- Negative scouts
        avg(scout_FC) as avg_FC,
        avg(scout_PC) as avg_PC,
        avg(scout_CA) as avg_CA,
        avg(scout_CV) as avg_CV,
        avg(scout_GC) as avg_GC,
        avg(scout_GS) as avg_GS,
        avg(scout_I) as avg_I,
        avg(scout_PP) as avg_PP
    from last_3_home_played
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
        a.availability,
        p.avg_G, p.avg_A, p.avg_FT, p.avg_FD, p.avg_FF, p.avg_FS, p.avg_PS,
        p.avg_DS, p.avg_SG, p.avg_DE, p.avg_DP,
        p.avg_FC, p.avg_PC, p.avg_CA, p.avg_CV, p.avg_GC, p.avg_GS, p.avg_I, p.avg_PP
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
