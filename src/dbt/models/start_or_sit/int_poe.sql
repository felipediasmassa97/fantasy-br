{{ config(materialized='view') }}

/*
PoE (Points over Expected)

Measures how much a player over/underperforms their MAP projection.
Positive PoE = player is exceeding expectations.
Negative PoE = player is underperforming.

Calculation:
- For each round N, compare actual_pts in round N with MAP calculated as_of_round N-1
  (MAP at round N-1 projects for round N's matchup)
- PoE_total = sum of all (actual - expected) this season
- PoE_last_5 = sum of (actual - expected) for last 5 rounds

Use cases:
- Identify regression candidates (high PoE = sell-high, low PoE = buy-low)
- Validate projection accuracy
- Alternative form metric
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Actual points per player per round
actual_points as (
    select
        id,
        round_id,
        pts_round,
        has_played
    from {{ ref('int_players') }}
    where season = 2026
),

-- MAP projections (as_of_round_id projects for round as_of_round_id + 1)
map_projections as (
    select
        as_of_round_id,
        as_of_round_id + 1 as projected_for_round,
        id,
        map_score
    from {{ ref('map') }}
),

-- Join actual points with MAP projections
-- Actual points in round N compared with MAP from round N-1
round_by_round as (
    select
        ap.id,
        ap.round_id,
        ap.pts_round as actual_pts,
        ap.has_played,
        mp.map_score as expected_pts,
        case
            when ap.has_played and mp.map_score is not null
            then ap.pts_round - mp.map_score
            else null
        end as poe_round
    from actual_points ap
    left join map_projections mp
        on ap.id = mp.id
        and ap.round_id = mp.projected_for_round
),

-- Calculate cumulative PoE up to each as_of_round
cumulative_poe as (
    select
        r.as_of_round_id,
        rbr.id,
        -- Total PoE (all rounds this season up to as_of_round)
        sum(rbr.poe_round) as poe_total,
        count(rbr.poe_round) as poe_rounds_total,
        avg(rbr.poe_round) as poe_avg
    from round_by_round rbr
    cross join all_rounds r
    where rbr.round_id <= r.as_of_round_id
        and rbr.poe_round is not null
    group by r.as_of_round_id, rbr.id
),

-- Calculate last 5 rounds PoE
last_5_poe as (
    select
        r.as_of_round_id,
        rbr.id,
        rbr.round_id,
        rbr.poe_round,
        row_number() over (
            partition by r.as_of_round_id, rbr.id
            order by rbr.round_id desc
        ) as recency_rank
    from round_by_round rbr
    cross join all_rounds r
    where rbr.round_id <= r.as_of_round_id
        and rbr.poe_round is not null
),

last_5_agg as (
    select
        as_of_round_id,
        id,
        sum(poe_round) as poe_last_5,
        count(*) as poe_rounds_last_5,
        avg(poe_round) as poe_avg_last_5
    from last_5_poe
    where recency_rank <= 5
    group by as_of_round_id, id
)

select
    b.as_of_round_id,
    b.id,
    b.name,
    b.club,
    b.club_logo_url,
    b.position,
    b.baseline_pts,
    -- Cumulative PoE
    coalesce(cp.poe_total, 0) as poe_total,
    cp.poe_rounds_total,
    cp.poe_avg,
    -- Last 5 rounds PoE
    coalesce(l5.poe_last_5, 0) as poe_last_5,
    l5.poe_rounds_last_5,
    l5.poe_avg_last_5,
    -- PoE category (for quick identification)
    case
        when cp.poe_total > 5 then 'overperforming'
        when cp.poe_total < -5 then 'underperforming'
        else 'as_expected'
    end as poe_category
from {{ ref('int_map_baseline') }} b
left join cumulative_poe cp
    on b.as_of_round_id = cp.as_of_round_id
    and b.id = cp.id
left join last_5_agg l5
    on b.as_of_round_id = l5.as_of_round_id
    and b.id = l5.id
