{{ config(materialized='view') }}

/*
MAP Component 4: MPAP (Matchup Points Allowed by Position)

MPAP measures how many fantasy points a team allows to a specific position.
Not "is this defense good?" but "How well does this team defend against this type of player?"

Calculation:
- Track points conceded by opponent to each position (last 5 team games)
- mpap_multiplier = mpap_pts_conceded / league_avg
- Clamped between 0.85 and 1.20 (asymmetric to favor attacking weak opponents)
*/

with all_rounds as (
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
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

-- Get club_id for each player (needed for opponent matching)
player_club as (
    select distinct
        p.id as player_id,
        p.club_id
    from {{ ref('stg_players') }} p
    where p.season = 2026
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
)

select
    b.as_of_round_id,
    b.id,
    b.position,
    nm.opponent_id,
    nm.is_home_next,
    pc.avg_pts_conceded as mpap_pts_conceded,
    pc.matches_conceded as mpap_matches,
    lap.league_avg_pts,
    -- MPAP multiplier: clamped 0.85 to 1.20
    case
        when lap.league_avg_pts is null or lap.league_avg_pts = 0 or pc.avg_pts_conceded is null then null
        else greatest(0.85, least(1.20, pc.avg_pts_conceded / lap.league_avg_pts))
    end as mpap_multiplier
from {{ ref('int_map_baseline') }} b
left join player_club plc on b.id = plc.player_id
left join next_match nm on b.as_of_round_id = nm.as_of_round_id and plc.club_id = nm.club_id
left join points_conceded pc
    on b.as_of_round_id = pc.as_of_round_id
    and nm.opponent_id = pc.conceding_team_id
    and b.position = pc.position
left join league_avg_by_position lap
    on b.as_of_round_id = lap.as_of_round_id
    and b.position = lap.position
