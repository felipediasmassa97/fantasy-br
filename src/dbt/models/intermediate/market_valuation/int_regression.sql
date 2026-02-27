/*
Regression Candidate Score (Market Valuation)

Identifies players likely to regress toward their true talent level.

Components:
  - performance_gap = ewm_pts - stabilized_mean (positive = outperforming)
  - ga_share: high G/A dependency amplifies regression risk
  - consistency_rating: inconsistent players are more regression-prone
  - regression_score combines these signals: performance_gap * (1 + ga_share) * (1 / consistency_rating)

Signal labels:
  - SELL_HIGH: regression_score > 2.0 (outperforming + volatile/G-A-dependent)
  - BUY_LOW: regression_score < -2.0 (underperforming, likely to bounce back)
  - NEUTRAL: otherwise

Confidence flag:
  - LOW_SAMPLE: < 5 games this season (unreliable signal)
  - OK: >= 5 games
*/

select
    b.as_of_round_id,
    b.id,
    b.name,
    b.club,
    b.club_logo_url,
    b.position,
    -- Inputs
    b.baseline_pts as stabilized_mean_pts,
    e.ewm_pts,
    -- Performance gap: positive = currently exceeding expected output
    coalesce(e.ewm_pts, 0) - coalesce(b.baseline_pts, 0) as performance_gap,
    -- GA dependency
    coalesce(ga.ga_share, 0) as ga_share,
    -- Consistency
    d.consistency_rating,
    -- Regression score: gap amplified by G/A dependency and inconsistency
    -- Positive = sell-high candidate, Negative = buy-low candidate
    case
        when b.baseline_pts is null or e.ewm_pts is null or d.consistency_rating is null
            or d.consistency_rating = 0 then null
        else
            (e.ewm_pts - b.baseline_pts)
            * (1.0 + coalesce(ga.ga_share, 0))
            * (1.0 / d.consistency_rating)
    end as regression_score,
    -- Signal label
    case
        when b.baseline_pts is null or e.ewm_pts is null or d.consistency_rating is null
            or d.consistency_rating = 0 then null
        when (e.ewm_pts - b.baseline_pts) * (1.0 + coalesce(ga.ga_share, 0)) * (1.0 / d.consistency_rating) > 2.0
            then 'SELL_HIGH'
        when (e.ewm_pts - b.baseline_pts) * (1.0 + coalesce(ga.ga_share, 0)) * (1.0 / d.consistency_rating) < -2.0
            then 'BUY_LOW'
        else 'NEUTRAL'
    end as signal_label,
    -- Confidence flag
    case
        when b.matches_this_season < 5 then 'LOW_SAMPLE'
        else 'OK'
    end as confidence_flag
from {{ ref('int_map_baseline') }} b
left join {{ ref('int_ewm_form') }} e
    on b.as_of_round_id = e.as_of_round_id and b.id = e.id
left join {{ ref('int_ga_dependency') }} ga
    on b.as_of_round_id = ga.as_of_round_id and b.id = ga.id
left join {{ ref('int_distribution_stats') }} d
    on b.as_of_round_id = d.as_of_round_id and b.id = d.id
