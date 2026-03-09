/*
Market Valuation: Form (EWM) & Trend (Subtab)

Thin mart: EWM form, last-3/5 averages, trend ratios, and form direction.
See int_form_trend for calculation details.
*/

select
    f.as_of_round_id,
    f.id as player_id,
    f.player_name,
    f.club,
    f.club_logo_url,
    f.position,
    f.ewm_alpha,
    f.ewm_pts as ewm_points,
    f.last3_avg_pts as last3_avg_points,
    f.season_avg_pts as season_avg_points,
    f.trend_ratio_last3,
    f.form_bucket_last3,
    f.trend_ratio_ewm,
    f.form_bucket_ewm,
    b.baseline_pts - rl.replacement_level as par
from {{ ref('int_form_trend') }} as f
left join {{ ref('int_baseline') }} as b
    on f.as_of_round_id = b.as_of_round_id and f.id = b.id
left join {{ ref('int_replacement_levels') }} as rl
    on f.as_of_round_id = rl.as_of_round_id and f.position = rl.position
