/*
Market Valuation: Main Consolidated Tab

Thin mart: key valuation metrics for quick player assessment.
Joins PAR, baseline, EWM, regression, and distribution data.
*/

select
    b.as_of_round_id,
    b.id as player_id,
    b.player_name,
    b.club,
    b.club_logo_url,
    b.position,
    -- Stabilized mean (= baseline_pts)
    b.baseline_pts,
    -- Recency-weighted form
    e.ewm_pts,
    -- Regression candidate score
    reg.regression_score,
    -- PoE: points over expected based on MAP projection
    poe.avg_poe_season,
    poe.avg_poe_last_5,
    -- PAR: value over replacement
    b.baseline_pts - rl.replacement_level as par,
    -- Availability: matches played / rounds where player was listed this season
    case
        when b.rounds_listed_this_season is null or b.rounds_listed_this_season = 0 then null
        else b.matches_this_season * 1.0 / b.rounds_listed_this_season
    end as availability
from {{ ref('int_baseline') }} as b
left join {{ ref('int_replacement_levels') }} as rl
    on b.as_of_round_id = rl.as_of_round_id and b.position = rl.position
left join {{ ref('int_ewm_form') }} as e
    on b.as_of_round_id = e.as_of_round_id and b.id = e.id
left join {{ ref('int_regression') }} as reg
    on b.as_of_round_id = reg.as_of_round_id and b.id = reg.id
left join {{ ref('int_poe') }} as poe
    on b.as_of_round_id = poe.as_of_round_id and b.id = poe.id
where b.baseline_pts is not null
