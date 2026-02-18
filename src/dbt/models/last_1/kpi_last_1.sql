{{ config(materialized='view') }}

with last_round as (
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

last_played_stats as (
    select
        id,
        pts_round,
        base_round,
        scout_G, scout_A, scout_FT, scout_FD, scout_FF, scout_FS, scout_PS,
        scout_DS, scout_SG, scout_DE, scout_DP,
        scout_FC, scout_PC, scout_CA, scout_CV, scout_GC, scout_GS, scout_I, scout_PP,
        row_number() over (partition by id order by round_id desc) as rn
    from {{ ref('int_players') }}
    where season = 2026 and has_played = true
),

player_pts as (
    select
        s.id,
        s.name,
        s.club,
        s.position,
        if(s.has_played, 1, 0) as matches_counted,
        lp.pts_round as pts_avg,
        lp.base_round as base_avg,
        if(s.has_played, 1.0, 0.0) as availability,
        -- Offensive scouts
        lp.scout_G as avg_G,
        lp.scout_A as avg_A,
        lp.scout_FT as avg_FT,
        lp.scout_FD as avg_FD,
        lp.scout_FF as avg_FF,
        lp.scout_FS as avg_FS,
        lp.scout_PS as avg_PS,
        -- Defensive scouts
        lp.scout_DS as avg_DS,
        lp.scout_SG as avg_SG,
        lp.scout_DE as avg_DE,
        lp.scout_DP as avg_DP,
        -- Negative scouts
        lp.scout_FC as avg_FC,
        lp.scout_PC as avg_PC,
        lp.scout_CA as avg_CA,
        lp.scout_CV as avg_CV,
        lp.scout_GC as avg_GC,
        lp.scout_GS as avg_GS,
        lp.scout_I as avg_I,
        lp.scout_PP as avg_PP
    from last_round_status s
    left join last_played_stats lp on s.id = lp.id and lp.rn = 1
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
