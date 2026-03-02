/*
Market Valuation: Form (EWM) & Trend (Subtab)

Thin mart: EWM form, last-3/5 averages, trend ratios, and form direction.
See int_form_trend for calculation details.
*/

select
    as_of_round_id,
    id as player_id,
    player_name,
    club,
    club_logo_url,
    position,
    ewm_alpha,
    ewm_pts as ewm_points,
    last3_avg_pts as last3_avg_points,
    season_avg_pts as season_avg_points,
    trend_ratio_last3,
    form_bucket_last3,
    trend_ratio_ewm,
    form_bucket_ewm
from {{ ref('int_form_trend') }}
