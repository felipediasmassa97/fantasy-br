/*
Replacement Levels per Position

Replacement level = the average baseline_pts of the first 5 undrafted players
at each position (the best waiver-wire options).

Draft roster sizes (10 participants * roster spots per position):
  GK: 20  (2 per team)
  CB: 40  (4 per team)
  FB: 40  (4 per team)
  MD: 60  (6 per team)
  AT: 60  (6 per team)

Players are ranked by baseline_pts descending. The replacement window is
  ranks [drafted_count + 1 .. drafted_count + 5].
*/

-- Draft configuration: expected number of rostered players per position
with
draft_config as (
    select *
    from
        unnest(
            [
                struct('GK' as position, 20 as drafted_count),
                struct('FB' as position, 40 as drafted_count),
                struct('CB' as position, 40 as drafted_count),
                struct('MD' as position, 60 as drafted_count),
                struct('AT' as position, 60 as drafted_count)
            ]
        )
),

-- Rank all players per position per round by baseline (best = rank 1)
ranked as (
    select
        as_of_round_id,
        position,
        baseline_pts,
        row_number() over (
            partition by as_of_round_id, position
            order by baseline_pts desc nulls last
        ) as position_rank
    from {{ ref('int_baseline') }}
    where baseline_pts is not null
),

-- Average baseline of the replacement window for each position
replacement_window as (
    select
        r.as_of_round_id,
        r.position,
        dc.drafted_count,
        avg(r.baseline_pts) as replacement_level,
        count(*) as players_in_replacement_window
    from ranked as r
    inner join draft_config as dc on r.position = dc.position
    where r.position_rank between dc.drafted_count + 1 and dc.drafted_count + 5
    group by r.as_of_round_id, r.position, dc.drafted_count
)

select
    as_of_round_id,
    position,
    drafted_count,
    replacement_level,
    players_in_replacement_window
from replacement_window
