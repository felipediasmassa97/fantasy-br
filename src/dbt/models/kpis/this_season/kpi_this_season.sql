{{ config(materialized='view') }}

with ranked_matches as (
    select
        id,
        name,
        club,
        position,
        round_id,
        pts_round,
        base_round,
        has_played,
        scout_G, scout_A, scout_FT, scout_FD, scout_FF, scout_FS, scout_PS,
        scout_DS, scout_SG, scout_DE, scout_DP,
        scout_FC, scout_PC, scout_CA, scout_CV, scout_GC, scout_GS, scout_I, scout_PP,
        row_number() over (partition by id order by round_id desc) as match_rank
    from {{ ref('int_players') }}
    where season = 2026
),

latest_info as (
    select id, name, club, position
    from ranked_matches
    where match_rank = 1
),

player_pts as (
    select
        r.id,
        l.name,
        l.club,
        l.position,
        countif(r.has_played = true) as matches_counted,
        avg(if(r.has_played, r.pts_round, null)) as pts_avg,
        avg(if(r.has_played, r.base_round, null)) as base_avg,
        countif(r.has_played = true) / count(*) as availability,
        -- Offensive scouts
        avg(if(r.has_played, r.scout_G, null)) as avg_G,
        avg(if(r.has_played, r.scout_A, null)) as avg_A,
        avg(if(r.has_played, r.scout_FT, null)) as avg_FT,
        avg(if(r.has_played, r.scout_FD, null)) as avg_FD,
        avg(if(r.has_played, r.scout_FF, null)) as avg_FF,
        avg(if(r.has_played, r.scout_FS, null)) as avg_FS,
        avg(if(r.has_played, r.scout_PS, null)) as avg_PS,
        -- Defensive scouts
        avg(if(r.has_played, r.scout_DS, null)) as avg_DS,
        avg(if(r.has_played, r.scout_SG, null)) as avg_SG,
        avg(if(r.has_played, r.scout_DE, null)) as avg_DE,
        avg(if(r.has_played, r.scout_DP, null)) as avg_DP,
        -- Negative scouts
        avg(if(r.has_played, r.scout_FC, null)) as avg_FC,
        avg(if(r.has_played, r.scout_PC, null)) as avg_PC,
        avg(if(r.has_played, r.scout_CA, null)) as avg_CA,
        avg(if(r.has_played, r.scout_CV, null)) as avg_CV,
        avg(if(r.has_played, r.scout_GC, null)) as avg_GC,
        avg(if(r.has_played, r.scout_GS, null)) as avg_GS,
        avg(if(r.has_played, r.scout_I, null)) as avg_I,
        avg(if(r.has_played, r.scout_PP, null)) as avg_PP
    from ranked_matches r
    join latest_info l on r.id = l.id
    group by r.id, l.name, l.club, l.position
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
