/*
Points over Expected (PoE): per-round residual and aggregate metrics.

PoE = Actual Points (in a round) - MAP Projection (for that round)

MAP at as_of_round_id = R projects performance for round R+1.
So PoE for round R = actual_pts(R) - map_score(as_of_round_id = R-1).

Aggregates per player per as_of_round:
  - avg_poe_season: mean PoE across all rounds with valid MAP this season
  - avg_poe_last_5: mean PoE across the 5 most recently played rounds with valid MAP
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Round-level PoE: actual points minus MAP projection for that round.
-- MAP at as_of_round_id = R-1 projects round R.
round_poe as (
    select
        p.round_id,
        p.id,
        p.pts_round as actual_pts,
        m.map_score as projected_map,
        p.pts_round - m.map_score as poe
    from {{ ref('int_players') }} as p
    inner join {{ ref('int_map_score') }} as m
        on
            m.as_of_round_id = p.round_id - 1
            and p.id = m.id
    where
        p.season = 2026
        and p.has_played = true
        and m.map_score is not null
),

-- For each as_of_round, rank played rounds by recency per player
ranked_poe as (
    select
        r.as_of_round_id,
        rp.id,
        rp.round_id,
        rp.poe,
        row_number() over (
            partition by r.as_of_round_id, rp.id
            order by rp.round_id desc
        ) as recency_rank
    from round_poe as rp
    cross join all_rounds as r
    where rp.round_id <= r.as_of_round_id
)

select
    as_of_round_id,
    id,
    avg(poe) as avg_poe_season,
    avg(case when recency_rank <= 5 then poe end) as avg_poe_last_5
from ranked_poe
group by as_of_round_id, id
