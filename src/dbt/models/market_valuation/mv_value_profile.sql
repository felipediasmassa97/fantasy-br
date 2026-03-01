/*
Market Valuation: Value Profile - Risk vs Reward (Subtab)

Thin mart: combines PAR, distribution, consistency, and GA dependency
for a comprehensive risk/reward assessment per player.
*/

select
    b.as_of_round_id,
    b.name as player_name,
    b.id as player_id,
    b.position,
    -- Value
    b.baseline_pts - rl.replacement_level as par_points,
    b.baseline_pts as stabilized_mean_points,
    -- Distribution
    d.floor_pts as floor_p20,
    d.median_pts as median_p50,
    d.ceiling_pts as ceiling_p80,
    d.consistency_rating,
    -- Availability: games played / rounds where player was listed this season
    case
        when b.rounds_listed_this_season is null or b.rounds_listed_this_season = 0 then null
        else b.matches_this_season * 1.0 / b.rounds_listed_this_season
    end as availability_rate,
    -- G/A dependency
    coalesce(ga.ga_share, 0) as ga_dependency
from {{ ref('int_map_baseline') }} as b
inner join {{ ref('int_replacement_levels') }} as rl
    on b.as_of_round_id = rl.as_of_round_id and b.position = rl.position
left join {{ ref('int_distribution_stats') }} as d
    on b.as_of_round_id = d.as_of_round_id and b.id = d.id
left join {{ ref('int_ga_dependency') }} as ga
    on b.as_of_round_id = ga.as_of_round_id and b.id = ga.id
where b.baseline_pts is not null
