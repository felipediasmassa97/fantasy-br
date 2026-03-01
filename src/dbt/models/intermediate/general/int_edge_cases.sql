/*
Edge Cases & Missing Data

Flags players with incomplete or missing data for quality auditing.
One row per player with data completeness indicators.
*/

with player_summary as (
    select
        id,
        name,
        position,
        club,
        club_logo_url,
        -- Season-level counts
        countif(season = 2025) as rounds_last_season,
        countif(season = 2025 and has_played) as matches_last_season,
        countif(season = 2026) as rounds_this_season,
        countif(season = 2026 and has_played) as matches_this_season,
        -- First/last appearance
        min(if(season = 2026, round_id, null)) as first_round_seen,
        max(if(season = 2026, round_id, null)) as last_round_seen,
        -- Missing data flags
        countif(season = 2026 and is_home is null) as missing_home_away_count,
        countif(season = 2026 and opponent_id is null) as missing_opponent_count,
        countif(season = 2026 and pts_round is null) as missing_points_count
    from {{ ref('int_players') }}
    group by id, name, position, club, club_logo_url
),

-- Check if player has last season data (same criteria as int_baseline)
last_season_quality as (
    select
        id,
        countif(has_played) as matches_last,
        countif(has_played) * 1.0 / nullif(count(*), 0) as avail_last
    from {{ ref('int_players') }}
    where season = 2025
    group by id
)

select
    ps.id as player_id,
    ps.name as player_name,
    ps.position,
    ps.club,
    ps.club_logo_url,
    -- Has reliable last season data (same threshold as int_baseline: >=5 matches, >30% availability)
    coalesce(lsq.matches_last >= 5 and lsq.avail_last > 0.30, false) as has_last_season_data,
    ps.matches_last_season,
    ps.matches_this_season,
    ps.first_round_seen,
    ps.last_round_seen,
    -- Missing data flags (true = has missing data)
    ps.missing_home_away_count > 0 as missing_home_away_flag,
    ps.missing_opponent_count > 0 as missing_opponent_flag,
    ps.missing_points_count > 0 as missing_points_flag
from player_summary as ps
left join last_season_quality as lsq on ps.id = lsq.id
where ps.rounds_this_season > 0
