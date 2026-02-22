{{ config(materialized='view') }}

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Get away rounds per player up to each as_of_round
player_away_rounds as (
    select
        r.as_of_round_id,
        p.id,
        p.name,
        p.club,
        p.club_logo_url,
        p.position,
        p.round_id,
        p.has_played,
        row_number() over (partition by r.as_of_round_id, p.id order by p.round_id desc) as round_rank
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026 and p.is_home = false and p.round_id <= r.as_of_round_id
),

latest_info as (
    select as_of_round_id, id, name, club, club_logo_url, position
    from player_away_rounds
    where round_rank = 1
),

availability_calc as (
    select
        as_of_round_id,
        id,
        countif(has_played = true) as matches_counted,
        countif(has_played = true) / count(*) as availability
    from player_away_rounds
    where round_rank <= 5
    group by as_of_round_id, id
),

-- Get last 5 away played matches per player up to each as_of_round
last_5_away_played as (
    select
        r.as_of_round_id,
        p.id,
        p.pts_round,
        p.base_round,
        p.scout_G, p.scout_A, p.scout_FT, p.scout_FD, p.scout_FF, p.scout_FS, p.scout_PS,
        p.scout_DS, p.scout_SG, p.scout_DE, p.scout_DP,
        p.scout_FC, p.scout_PC, p.scout_CA, p.scout_CV, p.scout_GC, p.scout_GS, p.scout_I, p.scout_PP,
        row_number() over (partition by r.as_of_round_id, p.id order by p.round_id desc) as played_rank
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026 and p.is_home = false and p.has_played = true and p.round_id <= r.as_of_round_id
),

pts_calc as (
    select
        as_of_round_id,
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
    from last_5_away_played
    where played_rank <= 5
    group by as_of_round_id, id
),

player_pts as (
    select
        a.as_of_round_id,
        a.id,
        l.name,
        l.club,
        l.club_logo_url,
        l.position,
        a.matches_counted,
        p.pts_avg,
        p.base_avg,
        a.availability,
        p.avg_G, p.avg_A, p.avg_FT, p.avg_FD, p.avg_FF, p.avg_FS, p.avg_PS,
        p.avg_DS, p.avg_SG, p.avg_DE, p.avg_DP,
        p.avg_FC, p.avg_PC, p.avg_CA, p.avg_CV, p.avg_GC, p.avg_GS, p.avg_I, p.avg_PP
    from availability_calc a
    join latest_info l on a.as_of_round_id = l.as_of_round_id and a.id = l.id
    left join pts_calc p on a.as_of_round_id = p.as_of_round_id and a.id = p.id
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
