{{ config(materialized='view') }}

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

round_status as (
    select
        r.as_of_round_id,
        p.id,
        p.name,
        p.club,
        p.club_logo_url,
        p.position,
        p.has_played
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026 and p.round_id = r.as_of_round_id
),

last_played_stats as (
    select
        r.as_of_round_id,
        p.id,
        p.pts_round,
        p.base_round,
        p.scout_G, p.scout_A, p.scout_FT, p.scout_FD, p.scout_FF, p.scout_FS, p.scout_PS,
        p.scout_DS, p.scout_SG, p.scout_DE, p.scout_DP,
        p.scout_FC, p.scout_PC, p.scout_CA, p.scout_CV, p.scout_GC, p.scout_GS, p.scout_I, p.scout_PP,
        row_number() over (partition by r.as_of_round_id, p.id order by p.round_id desc) as rn
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026 and p.has_played = true and p.round_id <= r.as_of_round_id
),

player_pts as (
    select
        s.as_of_round_id,
        s.id,
        s.name,
        s.club,
        s.club_logo_url,
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
    from round_status s
    left join last_played_stats lp on s.as_of_round_id = lp.as_of_round_id and s.id = lp.id and lp.rn = 1
),

position_stats_avg as (
    {{ position_stats_by_round('pts_avg') }}
),

position_stats_base as (
    {{ position_stats_by_round('base_avg') }}
),

general_stats_avg as (
    {{ general_stats_by_round('pts_avg') }}
),

general_stats_base as (
    {{ general_stats_by_round('base_avg') }}
),

with_z_score as (
    select
        p.*,
        {{ z_score_general('p.pts_avg', 'gsa') }} as z_score_gen_avg,
        {{ z_score_general('p.base_avg', 'gsb') }} as z_score_gen_base,
        {{ z_score_position('p.pts_avg', 'psa') }} as z_score_pos_avg,
        {{ z_score_position('p.base_avg', 'psb') }} as z_score_pos_base
    from player_pts p
    left join position_stats_avg psa on p.as_of_round_id = psa.as_of_round_id and p.position = psa.position
    left join position_stats_base psb on p.as_of_round_id = psb.as_of_round_id and p.position = psb.position
    left join general_stats_avg gsa on p.as_of_round_id = gsa.as_of_round_id
    left join general_stats_base gsb on p.as_of_round_id = gsb.as_of_round_id
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
    row_number() over (partition by as_of_round_id order by dvs_gen_avg desc nulls last) as adp_gen_avg,
    row_number() over (partition by as_of_round_id order by dvs_gen_base desc nulls last) as adp_gen_base,
    row_number() over (partition by as_of_round_id, position order by dvs_pos_avg desc nulls last) as adp_pos_avg,
    row_number() over (partition by as_of_round_id, position order by dvs_pos_base desc nulls last) as adp_pos_base
from with_dvs
