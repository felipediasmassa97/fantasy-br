/*
MAP Component 2: Recent Form

Calculates form adjustment based on last 5 played matches:
- form_ratio = pts_avg_last_5 / baseline_pts
- Clamped between 0.8 and 1.2 (+-20% max impact)
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Last 5 matches per player per round
last_5_matches as (
    select
        r.as_of_round_id,
        p.id,
        p.pts_round,
        p.has_played,
        row_number() over (
            partition by r.as_of_round_id, p.id
            order by p.round_id desc
        ) as match_rank
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026 and p.round_id <= r.as_of_round_id
),

-- Recent form: average of last 5 played matches
recent_form as (
    select
        as_of_round_id,
        id,
        avg(if(has_played, pts_round, null)) as pts_avg_last_5,
        countif(has_played = true) as matches_last_5
    from last_5_matches
    where match_rank <= 5
    group by as_of_round_id, id
)

select
    b.as_of_round_id,
    b.id,
    rf.pts_avg_last_5,
    rf.matches_last_5,
    -- Form ratio: recent performance relative to baseline (clamped +-20%)
    case
        when b.baseline_pts is null or b.baseline_pts = 0 or rf.pts_avg_last_5 is null then null
        else greatest(0.8, least(1.2, rf.pts_avg_last_5 / b.baseline_pts))
    end as form_ratio
from {{ ref('int_map_baseline') }} b
left join recent_form rf
    on b.as_of_round_id = rf.as_of_round_id
    and b.id = rf.id
