/*
Market Valuation: Schedule Strength (Subtab)

Shows schedule strength (MPAP-based) per player: average points allowed
by position across the next 10 opponents.  Higher values indicate
an easier upcoming schedule.
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

league_avg_by_position as (
    select
        r.as_of_round_id,
        p.position,
        avg(if(p.has_played, p.pts_round, null)) as league_avg_pts
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where p.season = 2026 and p.round_id <= r.as_of_round_id
    group by r.as_of_round_id, p.position
)

select
    b.as_of_round_id,
    b.id as player_id,
    b.player_name,
    b.position,
    b.club,
    b.club_logo_url,
    b.baseline_pts,
    ss.schedule_strength,
    ss.opponents_evaluated,
    ss.upcoming_opponents,
    lap.league_avg_pts as league_avg_position_pts,
    b.baseline_pts - rl.replacement_level as par,
    case
        when lap.league_avg_pts is null or lap.league_avg_pts = 0 then null
        else ss.schedule_strength / lap.league_avg_pts
    end as schedule_strength_ratio
from {{ ref('int_baseline') }} as b
inner join {{ ref('int_schedule_strength') }} as ss
    on b.as_of_round_id = ss.as_of_round_id and b.id = ss.id
inner join {{ ref('int_replacement_levels') }} as rl
    on b.as_of_round_id = rl.as_of_round_id and b.position = rl.position
left join league_avg_by_position as lap
    on b.as_of_round_id = lap.as_of_round_id and b.position = lap.position
where b.baseline_pts is not null
