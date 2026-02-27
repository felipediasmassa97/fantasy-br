/*
Market Valuation: Main Consolidated Tab

Thin mart: key valuation metrics for quick player assessment.
Joins PAR, baseline, EWM, regression, and distribution data.
*/

select
    b.as_of_round_id,
    b.id,
    b.name,
    b.club,
    b.club_logo_url,
    b.position,
    -- PAR: value over replacement
    b.baseline_pts - rl.replacement_level as par,
    -- Stabilized mean (= baseline_pts)
    b.baseline_pts as stabilized_mean,
    -- Recency-weighted form
    e.ewm_pts,
    -- Regression candidate score
    reg.regression_score,
    -- Availability: games played / total rounds this season
    -- # fixit should be matches played / matches listed (rounds where player was listed)
    case
        when b.matches_this_season is null then null
        else b.matches_this_season * 1.0 / b.as_of_round_id
    end as availability
from {{ ref('int_map_baseline') }} b
left join {{ ref('int_replacement_levels') }} rl
    on b.as_of_round_id = rl.as_of_round_id and b.position = rl.position
left join {{ ref('int_ewm_form') }} e
    on b.as_of_round_id = e.as_of_round_id and b.id = e.id
left join {{ ref('int_regression') }} reg
    on b.as_of_round_id = reg.as_of_round_id and b.id = reg.id
where b.baseline_pts is not null
