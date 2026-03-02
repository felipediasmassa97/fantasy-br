/*
Distribution Stats: Floor / Median / Ceiling + Consistency

Score distribution analysis per player, blended with position-level data for small samples.

Percentile definitions:
  - Floor (20th percentile): Bad-but-normal match
  - Median (50th percentile): Typical match
  - Ceiling (80th percentile): Great-but-realistic match

Small-sample fix: If < 10 matches, blend with position-level distribution.
  blend_weight = (10 - matches) / 10, so 0 matches = 100% position, 10+ matches = 0% position.

Consistency metrics (derived from blended stats):
  - CV (Coefficient of Variation) = stddev / mean. Lower = more stable.
  - Consistency Rating = 1 / (1 + CV). Range 0-1, higher = more consistent.
  - Range = ceiling - floor. Measure of volatility.
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- All played matches per player (this season) up to each as_of_round
player_matches as (
    select
        r.as_of_round_id,
        p.id,
        p.position,
        p.pts_round
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where
        p.season = 2026
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
        count(*) over (partition by as_of_round_id, id) as matches_played,
        -- Boom/bust counts for rate computation
        sum(case when pts_round >= 8.0 then 1 else 0 end) over (partition by as_of_round_id, id) as boom_count,
        sum(case when pts_round <= 2.0 then 1 else 0 end) over (partition by as_of_round_id, id) as bust_count
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
        matches_played,
        boom_count,
        bust_count
    from player_percentiles
),

-- Blend player stats with position stats if < 10 matches
blended_stats as (
    select
        pp.as_of_round_id,
        pp.id,
        b.player_name,
        b.club,
        b.club_logo_url,
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
        pp.boom_count,
        pp.bust_count,
        -- blend_weight: 0 if >= 10 matches (pure player data), up to 1.0 if 0 matches (pure position data)
        case
            when pp.matches_played >= 10 then 0.0
            else (10.0 - pp.matches_played) / 10.0
        end as blend_weight
    from player_percentiles_deduped as pp
    inner join {{ ref('int_baseline') }} as b
        on pp.as_of_round_id = b.as_of_round_id and pp.id = b.id
    left join position_stats_deduped as ps
        on pp.as_of_round_id = ps.as_of_round_id and b.position = ps.position
)

select
    bs.as_of_round_id,
    bs.id,
    bs.player_name,
    bs.club,
    bs.club_logo_url,
    bs.position,
    bs.matches_played,
    bs.pts_avg,
    bs.pts_stddev,
    bs.blend_weight,
    -- Blended percentiles: weighted average of player and position stats
    (1 - bs.blend_weight) * bs.raw_floor + bs.blend_weight * coalesce(bs.pos_floor, bs.raw_floor) as pts_floor,
    (1 - bs.blend_weight) * bs.raw_median + bs.blend_weight * coalesce(bs.pos_median, bs.raw_median) as pts_median,
    (1 - bs.blend_weight) * bs.raw_ceiling + bs.blend_weight * coalesce(bs.pos_ceiling, bs.raw_ceiling) as pts_ceiling,
    -- Range: ceiling - floor (measure of volatility)
    ((1 - bs.blend_weight) * bs.raw_ceiling + bs.blend_weight * coalesce(bs.pos_ceiling, bs.raw_ceiling))
    - ((1 - bs.blend_weight) * bs.raw_floor + bs.blend_weight * coalesce(bs.pos_floor, bs.raw_floor)) as pts_range,
    -- CV (Coefficient of Variation): lower = more stable
    case
        when bs.pts_avg is null or bs.pts_avg = 0 or bs.pts_stddev is null then null
        else bs.pts_stddev / bs.pts_avg
    end as cv,
    -- Consistency Rating: 1 / (1 + CV), range 0-1, higher = more consistent
    case
        when bs.pts_avg is null or bs.pts_avg = 0 or bs.pts_stddev is null then null
        else 1.0 / (1.0 + bs.pts_stddev / bs.pts_avg)
    end as consistency_rating,
    -- Boom rate: fraction of matches scoring >= 8 points
    case when bs.matches_played > 0 then bs.boom_count * 1.0 / bs.matches_played end as boom_rate,
    -- Bust rate: fraction of matches scoring <= 2 points
    case when bs.matches_played > 0 then bs.bust_count * 1.0 / bs.matches_played end as bust_rate
from blended_stats as bs
