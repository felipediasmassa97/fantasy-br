/*
Form & Trend Analysis (Market Valuation)

Computes last-3 and last-5 match averages alongside season and EWM averages.
Derives trend ratios and a form bucket for quick directional assessment.

Trend ratios:
  - trend_ratio_last3 = last3_avg / season_avg (> 1 = improving)
  - trend_ratio_ewm = ewm_pts / stabilized_mean (> 1 = hot)

Form bucket:
  - UP: trend_ratio_ewm > 1.10 (significantly above baseline)
  - DOWN: trend_ratio_ewm < 0.90 (significantly below baseline)
  - FLAT: otherwise
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Rank played matches by recency for last-N averages
player_matches_ranked as (
    select
        r.as_of_round_id,
        p.id,
        p.pts_round,
        row_number() over (
            partition by r.as_of_round_id, p.id
            order by p.round_id desc
        ) as recency_rank
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where
        p.season = 2026
        and p.round_id <= r.as_of_round_id
        and p.has_played = true
),

-- Last 3 and last 5 averages
recent_avgs as (
    select
        as_of_round_id,
        id,
        avg(if(recency_rank <= 3, pts_round, null)) as last3_avg_pts
    from player_matches_ranked
    where recency_rank <= 3
    group by as_of_round_id, id
)

select
    b.as_of_round_id,
    b.id,
    b.name,
    b.club,
    b.club_logo_url,
    b.position,
    -- EWM form
    0.25 as ewm_alpha,
    e.ewm_pts,
    -- Recent averages
    ra.last3_avg_pts,
    -- Season / baseline
    b.pts_avg_this_season as season_avg_pts,
    b.baseline_pts as stabilized_mean_pts,
    -- Trend ratios
    case
        when b.pts_avg_this_season is null or b.pts_avg_this_season = 0 then null
        else ra.last3_avg_pts / b.pts_avg_this_season
    end as trend_ratio_last3,
    case
        when b.baseline_pts is null or b.baseline_pts = 0 then null
        else e.ewm_pts / b.baseline_pts
    end as trend_ratio_ewm,
    -- Form bucket last 3: IMPROVING / DECLINING / FLAT vs season average
    case
        when b.pts_avg_this_season is null or b.pts_avg_this_season = 0 or ra.last3_avg_pts is null then null
        when ra.last3_avg_pts / b.pts_avg_this_season > 1.10 then 'IMPROVING'
        when ra.last3_avg_pts / b.pts_avg_this_season < 0.90 then 'DECLINING'
        else 'FLAT'
    end as form_bucket_last3,
    -- Form bucket EWM: HOT / COLD / WARM vs stabilized mean
    case
        when b.baseline_pts is null or b.baseline_pts = 0 or e.ewm_pts is null then null
        when e.ewm_pts / b.baseline_pts > 1.10 then 'HOT'
        when e.ewm_pts / b.baseline_pts < 0.90 then 'COLD'
        else 'WARM'
    end as form_bucket_ewm
from {{ ref('int_map_baseline') }} as b
left join {{ ref('int_ewm_form') }} as e
    on b.as_of_round_id = e.as_of_round_id and b.id = e.id
left join recent_avgs as ra
    on b.as_of_round_id = ra.as_of_round_id and b.id = ra.id
