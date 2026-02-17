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
        row_number() over (partition by id order by round_id desc) as match_rank
    from {{ ref('int_players') }}
    where season = 2025
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
        countif(r.has_played = true) / count(*) as availability
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
