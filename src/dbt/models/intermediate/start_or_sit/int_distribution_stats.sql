/*
Distribution Stats: Floor / Median / Ceiling + Consistency Rating

Floor (20th percentile): Bad-but-normal game
Median (50th percentile): Typical game  
Ceiling (80th percentile): Great-but-realistic game
Consistency Rating: How stable are the player's scores (higher = more consistent)

Small-sample fix: If < 10 games, blend with position-level distribution.

Consistency = 1 / (1 + CV) where CV = std_dev / mean
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- All played matches per player (this season)
player_matches as (
    select
        r.as_of_round_id,
        p.id,
        p.position,
        p.pts_round
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026 
        and p.round_id <= r.as_of_round_id
        and p.has_played = true
),

-- Position-level stats for small-sample blending
position_stats as (
    select
        as_of_round_id,
        position,
        percentile_cont(pts_round, 0.20) over (partition by as_of_round_id, position) as pos_floor,
        percentile_cont(pts_round, 0.50) over (partition by as_of_round_id, position) as pos_median,
        percentile_cont(pts_round, 0.80) over (partition by as_of_round_id, position) as pos_ceiling,
        avg(pts_round) over (partition by as_of_round_id, position) as pos_avg,
        stddev(pts_round) over (partition by as_of_round_id, position) as pos_stddev
    from player_matches
),

position_stats_deduped as (
    select distinct
        as_of_round_id,
        position,
        pos_floor,
        pos_median,
        pos_ceiling,
        pos_avg,
        pos_stddev
    from position_stats
),

-- Player-level percentiles
player_percentiles as (
    select
        as_of_round_id,
        id,
        percentile_cont(pts_round, 0.20) over (partition by as_of_round_id, id) as raw_floor,
        percentile_cont(pts_round, 0.50) over (partition by as_of_round_id, id) as raw_median,
        percentile_cont(pts_round, 0.80) over (partition by as_of_round_id, id) as raw_ceiling,
        avg(pts_round) over (partition by as_of_round_id, id) as pts_avg,
        stddev(pts_round) over (partition by as_of_round_id, id) as pts_stddev,
        count(*) over (partition by as_of_round_id, id) as matches_played
    from player_matches
),

player_percentiles_deduped as (
    select distinct
        as_of_round_id,
        id,
        raw_floor,
        raw_median,
        raw_ceiling,
        pts_avg,
        pts_stddev,
        matches_played
    from player_percentiles
),

-- Calculate blended stats (blend with position if < 10 games)
blended_stats as (
    select
        pp.as_of_round_id,
        pp.id,
        b.name,
        b.club,
        b.position,
        pp.matches_played,
        pp.pts_avg,
        pp.pts_stddev,
        pp.raw_floor,
        pp.raw_median,
        pp.raw_ceiling,
        ps.pos_floor,
        ps.pos_median,
        ps.pos_ceiling,
        ps.pos_avg,
        ps.pos_stddev,
        case 
            when pp.matches_played >= 10 then 0.0
            else (10.0 - pp.matches_played) / 10.0
        end as blend_weight
    from player_percentiles_deduped pp
    inner join (
        select as_of_round_id, id, name, club, position from {{ ref('int_map_baseline') }}
    ) b 
        on pp.as_of_round_id = b.as_of_round_id and pp.id = b.id
    left join position_stats_deduped ps
        on pp.as_of_round_id = ps.as_of_round_id and b.position = ps.position
)


select
    bs.as_of_round_id,
    bs.id,
    bs.name,
    bs.club,
    bs.position,
    bs.matches_played,
    bs.pts_avg,
    bs.pts_stddev,
    (1 - bs.blend_weight) * bs.raw_floor + bs.blend_weight * coalesce(bs.pos_floor, bs.raw_floor) as floor_pts,
    (1 - bs.blend_weight) * bs.raw_median + bs.blend_weight * coalesce(bs.pos_median, bs.raw_median) as median_pts,
    (1 - bs.blend_weight) * bs.raw_ceiling + bs.blend_weight * coalesce(bs.pos_ceiling, bs.raw_ceiling) as ceiling_pts,
    bs.raw_floor,
    bs.raw_median,
    bs.raw_ceiling,
    bs.pos_floor,
    bs.pos_median,
    bs.pos_ceiling,
    bs.blend_weight
from blended_stats bs
