{{ config(materialized='view') }}

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Get all matches up to each as_of_round
ranked_matches as (
    select
        r.as_of_round_id,
        p.id,
        p.name,
        p.club,
        p.club_logo_url,
        p.position,
        p.round_id,
        p.pts_round,
        p.base_round,
        p.has_played,
        p.scout_G, p.scout_A, p.scout_FT, p.scout_FD, p.scout_FF, p.scout_FS, p.scout_PS,
        p.scout_DS, p.scout_SG, p.scout_DE, p.scout_DP,
        p.scout_FC, p.scout_PC, p.scout_CA, p.scout_CV, p.scout_GC, p.scout_GS, p.scout_I, p.scout_PP,
        row_number() over (partition by r.as_of_round_id, p.id order by p.round_id desc) as match_rank
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026 and p.round_id <= r.as_of_round_id
),

latest_info as (
    select as_of_round_id, id, name, club, club_logo_url, position
    from ranked_matches
    where match_rank = 1
),

player_pts as (
    select
        r.as_of_round_id,
        r.id,
        l.name,
        l.club,
        l.club_logo_url,
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
    join latest_info l on r.as_of_round_id = l.as_of_round_id and r.id = l.id
    group by r.as_of_round_id, r.id, l.name, l.club, l.club_logo_url, l.position
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
    pts_avg - base_avg as ga_avg,
    row_number() over (partition by as_of_round_id order by dvs_gen_avg desc nulls last) as adp_gen_avg,
    row_number() over (partition by as_of_round_id order by dvs_gen_base desc nulls last) as adp_gen_base,
    row_number() over (partition by as_of_round_id, position order by dvs_pos_avg desc nulls last) as adp_pos_avg,
    row_number() over (partition by as_of_round_id, position order by dvs_pos_base desc nulls last) as adp_pos_base
from with_dvs
