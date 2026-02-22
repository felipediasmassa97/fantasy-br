{{ config(materialized='view') }}

/*
Matchup-Adjusted Projection (MAP):

MAP answers: 
“Given who this player is, how he has been playing recently, and who he’s facing this round, how many points should I expect?”

MAP is an Expected Points (xP) proxy for the next match, combining:

- Baseline Ability:
  - Players with last season data: 0.6 * last_season_avg + 0.4 * this_season_avg
  - New players: 0.7 * this_season_avg + 0.3 * position_avg_last_season

- Recent Form Adjustment:
  - Use last 5 games average
  - form_ratio = recent_avg / baseline_pts
  - Clamp ratio between 0.8 and 1.2 (20% max impact)

- Home/Away Context:
  - home_away_avg = 0.7 * last_season_split + 0.3 * this_season_split
  - home_away_multiplier = home_away_avg / baseline_pts
  - Clamp between 0.85 and 1.15 (15% max impact)

- Opponent Strength:
  - Calculate points conceded by opponent to player's position (recent 5 games)
  - opponent_multiplier = conceded / league_avg
  - Clamp between 0.85 and 1.20 (15% max impact)
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Last season averages per player (full season 2025)
last_season_player_avg as (
    select
        id,
        position,
        avg(if(has_played, pts_round, null)) as pts_avg_last_season,
        countif(has_played = true) as matches_last_season,
        countif(has_played = true) / count(*) as availability_last_season
    from {{ ref('int_players') }}
    where season = 2025
    group by id, position
),

-- Last season home/away splits (full season 2025)
last_season_home_away_avg as (
    select
        id,
        avg(if(has_played and is_home = true, pts_round, null)) as pts_avg_home_last_season,
        avg(if(has_played and is_home = false, pts_round, null)) as pts_avg_away_last_season,
        countif(has_played = true and is_home = true) as matches_home_last_season,
        countif(has_played = true and is_home = false) as matches_away_last_season
    from {{ ref('int_players') }}
    where season = 2025
    group by id
),

-- Position average from last season (for rookies)
-- Only include players with >= 5 matches AND > 30% availability
position_avg_last_season as (
    select
        position,
        avg(pts_avg_last_season) as position_pts_avg
    from last_season_player_avg
    where matches_last_season >= 5 and availability_last_season > 0.30
    group by position
),

-- This season averages per player up to each round
this_season_player_avg as (
    select
        r.as_of_round_id,
        p.id,
        p.name,
        p.club,
        p.club_logo_url,
        p.position,
        avg(if(p.has_played, p.pts_round, null)) as pts_avg_this_season,
        countif(p.has_played = true) as matches_this_season
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026 and p.round_id <= r.as_of_round_id
    group by r.as_of_round_id, p.id, p.name, p.club, p.club_logo_url, p.position
),

-- This season home/away splits per round
this_season_home_away_avg as (
    select
        r.as_of_round_id,
        p.id,
        avg(if(p.has_played and p.is_home = true, p.pts_round, null)) as pts_avg_home_this_season,
        avg(if(p.has_played and p.is_home = false, p.pts_round, null)) as pts_avg_away_this_season,
        countif(p.has_played = true and p.is_home = true) as matches_home_this_season,
        countif(p.has_played = true and p.is_home = false) as matches_away_this_season
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026 and p.round_id <= r.as_of_round_id
    group by r.as_of_round_id, p.id
),

-- Last 5 matches per player per round (for recent form)
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
),

-- Get club_id for each player (needed for opponent matching)
player_club as (
    select distinct
        p.id as player_id,
        p.club_id
    from {{ ref('stg_players') }} p
    where p.season = 2026
),

-- Next match for each club at each round (looking at as_of_round_id + 1)
next_match as (
    select
        r.as_of_round_id,
        m.club_home_id as club_id,
        m.club_away_id as opponent_id,
        true as is_home_next
    from all_rounds r
    inner join {{ ref('stg_matches') }} m
        on m.season = 2026 and m.round_id = r.as_of_round_id + 1
    union all
    select
        r.as_of_round_id,
        m.club_away_id as club_id,
        m.club_home_id as opponent_id,
        false as is_home_next
    from all_rounds r
    inner join {{ ref('stg_matches') }} m
        on m.season = 2026 and m.round_id = r.as_of_round_id + 1
),

-- Points conceded by each team to each position (opponent's players points when facing this team)
-- For last 5 games per team at each round
points_conceded_raw as (
    select
        r.as_of_round_id,
        -- The team that conceded (opponent in the match)
        case
            when p.is_home then m.club_away_id
            else m.club_home_id
        end as conceding_team_id,
        p.position,
        p.pts_round,
        p.has_played,
        p.round_id,
        row_number() over (
            partition by r.as_of_round_id,
                case when p.is_home then m.club_away_id else m.club_home_id end
            order by p.round_id desc
        ) as team_match_rank
    from {{ ref('int_players') }} p
    cross join all_rounds r
    inner join {{ ref('stg_matches') }} m
        on p.season = m.season
        and p.round_id = m.round_id
    inner join player_club pc on p.id = pc.player_id
    where p.season = 2026
        and p.round_id <= r.as_of_round_id
        and (pc.club_id = m.club_home_id or pc.club_id = m.club_away_id)
),

-- Aggregate points conceded per team per position (last 5 team games)
points_conceded as (
    select
        as_of_round_id,
        conceding_team_id,
        position,
        avg(if(has_played, pts_round, null)) as avg_pts_conceded,
        countif(has_played = true) as matches_conceded
    from points_conceded_raw
    where team_match_rank <= 5 * 20  -- ~20 players per team, last 5 team matches
    group by as_of_round_id, conceding_team_id, position
),

-- League average points per position (this season up to each round)
league_avg_by_position as (
    select
        r.as_of_round_id,
        p.position,
        avg(if(p.has_played, p.pts_round, null)) as league_avg_pts
    from {{ ref('int_players') }} p
    cross join all_rounds r
    where p.season = 2026 and p.round_id <= r.as_of_round_id
    group by r.as_of_round_id, p.position
),

-- Combine last season and this season data
combined as (
    select
        ts.as_of_round_id,
        ts.id,
        ts.name,
        ts.club,
        ts.club_logo_url,
        ts.position,
        ts.pts_avg_this_season,
        ts.matches_this_season,
        ls.pts_avg_last_season,
        ls.matches_last_season,
        ls.availability_last_season,
        pa.position_pts_avg,
        rf.pts_avg_last_5,
        rf.matches_last_5,
        -- Home/away splits
        lha.pts_avg_home_last_season,
        lha.pts_avg_away_last_season,
        lha.matches_home_last_season,
        lha.matches_away_last_season,
        tha.pts_avg_home_this_season,
        tha.pts_avg_away_this_season,
        tha.matches_home_this_season,
        tha.matches_away_this_season,
        -- Opponent info for next match
        nm.opponent_id,
        nm.is_home_next,
        pc_opp.avg_pts_conceded as opponent_pts_conceded,
        pc_opp.matches_conceded as opponent_matches_conceded,
        lap.league_avg_pts,
        -- Flag: player qualifies as having last season data
        (ls.matches_last_season >= 5 and ls.availability_last_season > 0.30) as has_last_season_data
    from this_season_player_avg ts
    left join last_season_player_avg ls on ts.id = ls.id
    left join position_avg_last_season pa on ts.position = pa.position
    left join recent_form rf on ts.as_of_round_id = rf.as_of_round_id and ts.id = rf.id
    left join last_season_home_away_avg lha on ts.id = lha.id
    left join this_season_home_away_avg tha on ts.as_of_round_id = tha.as_of_round_id and ts.id = tha.id
    -- Opponent strength joins
    left join player_club pc on ts.id = pc.player_id
    left join next_match nm on ts.as_of_round_id = nm.as_of_round_id and pc.club_id = nm.club_id
    left join points_conceded pc_opp
        on ts.as_of_round_id = pc_opp.as_of_round_id
        and nm.opponent_id = pc_opp.conceding_team_id
        and ts.position = pc_opp.position
    left join league_avg_by_position lap
        on ts.as_of_round_id = lap.as_of_round_id
        and ts.position = lap.position
),

-- Calculate baseline points
with_baseline as (
    select
        *,
        case
            when has_last_season_data then
                0.6 * pts_avg_last_season + 0.4 * coalesce(pts_avg_this_season, 0)
            else
                0.7 * coalesce(pts_avg_this_season, 0) + 0.3 * coalesce(position_pts_avg, 0)
        end as baseline_pts,
        case
            when has_last_season_data then 'weighted_seasons'
            else 'rookie_shrinkage'
        end as baseline_method,
        -- Blended home/away averages (70% last season + 30% this season)
        0.7 * coalesce(pts_avg_home_last_season, pts_avg_last_season) +
        0.3 * coalesce(pts_avg_home_this_season, pts_avg_this_season, 0) as home_avg,
        0.7 * coalesce(pts_avg_away_last_season, pts_avg_last_season) +
        0.3 * coalesce(pts_avg_away_this_season, pts_avg_this_season, 0) as away_avg
    from combined
),

-- Add calculated ratios for final MAP
with_ratios as (
    select
        *,
        -- Form ratio: recent performance relative to baseline (clamped ±20%)
        case
            when baseline_pts is null or baseline_pts = 0 or pts_avg_last_5 is null then null
            else greatest(0.8, least(1.2, pts_avg_last_5 / baseline_pts))
        end as form_ratio,
        -- Home multiplier: clamped ±15%
        case
            when baseline_pts is null or baseline_pts = 0 or home_avg is null then null
            else greatest(0.85, least(1.15, home_avg / baseline_pts))
        end as home_multiplier,
        -- Away multiplier: clamped ±15%
        case
            when baseline_pts is null or baseline_pts = 0 or away_avg is null then null
            else greatest(0.85, least(1.15, away_avg / baseline_pts))
        end as away_multiplier,
        -- Opponent multiplier: clamped 0.85 to 1.20
        case
            when league_avg_pts is null or league_avg_pts = 0 or opponent_pts_conceded is null then null
            else greatest(0.85, least(1.20, opponent_pts_conceded / league_avg_pts))
        end as opponent_multiplier
    from with_baseline
)

select
    as_of_round_id,
    id,
    name,
    club,
    club_logo_url,
    position,
    pts_avg_this_season,
    matches_this_season,
    pts_avg_last_season,
    matches_last_season,
    availability_last_season,
    position_pts_avg,
    pts_avg_last_5,
    matches_last_5,
    baseline_pts,
    baseline_method,
    form_ratio,
    -- Home/Away context
    pts_avg_home_last_season,
    pts_avg_away_last_season,
    matches_home_last_season,
    matches_away_last_season,
    pts_avg_home_this_season,
    pts_avg_away_this_season,
    matches_home_this_season,
    matches_away_this_season,
    home_avg,
    away_avg,
    home_multiplier,
    away_multiplier,
    -- Opponent strength data
    opponent_id,
    is_home_next,
    opponent_pts_conceded,
    opponent_matches_conceded,
    league_avg_pts,
    opponent_multiplier,
    -- Venue multiplier (home or away based on next match)
    case
        when is_home_next = true then home_multiplier
        when is_home_next = false then away_multiplier
        else null
    end as venue_multiplier,
    -- Final MAP: baseline * form * venue * opponent
    case
        when baseline_pts is null then null
        when form_ratio is null and (home_multiplier is null or away_multiplier is null) and opponent_multiplier is null then baseline_pts
        else
            baseline_pts
            * coalesce(form_ratio, 1.0)
            * coalesce(
                case when is_home_next = true then home_multiplier
                     when is_home_next = false then away_multiplier
                     else null end,
                1.0
            )
            * coalesce(opponent_multiplier, 1.0)
    end as map_score
from with_ratios
