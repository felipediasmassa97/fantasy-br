{{ config(materialized='view') }}

/*
Matchup-Adjusted Projection (MAP):

MAP answers: 
"Given who this player is, how he has been playing recently, and who he's facing this round, how many points should I expect?"

MAP = baseline_pts × form_ratio × venue_multiplier × opponent_multiplier

Components (see individual models for details):
- int_map_baseline: Baseline expected points (0.6 * last_season + 0.4 * this_season or rookie shrinkage)
- int_map_form: Recent form adjustment from last 5 games (clamped +-20%)
- int_map_venue: Home/away context adjustment (clamped +-15%)
- int_map_opponent: Opponent strength adjustment (clamped 0.85-1.20)
*/

select
    -- Player info (from baseline)
    b.as_of_round_id,
    b.id,
    b.name,
    b.club,
    b.club_logo_url,
    b.position,

    -- Component 1: Baseline Ability
    b.pts_avg_this_season,
    b.matches_this_season,
    b.pts_avg_last_season,
    b.matches_last_season,
    b.availability_last_season,
    b.position_pts_avg,
    b.has_last_season_data,
    b.baseline_pts,
    b.baseline_method,

    -- Component 2: Recent Form
    f.pts_avg_last_5,
    f.matches_last_5,
    f.form_ratio,

    -- Component 3: Venue Context
    v.pts_avg_home_last_season,
    v.pts_avg_away_last_season,
    v.matches_home_last_season,
    v.matches_away_last_season,
    v.pts_avg_home_this_season,
    v.pts_avg_away_this_season,
    v.matches_home_this_season,
    v.matches_away_this_season,
    v.home_avg,
    v.away_avg,
    v.home_multiplier,
    v.away_multiplier,

    -- Component 4: Opponent Strength
    o.opponent_id,
    o.is_home_next,
    o.opponent_pts_conceded,
    o.opponent_matches_conceded,
    o.league_avg_pts,
    o.opponent_multiplier,

    -- Derived: Venue multiplier (based on next match location)
    case
        when o.is_home_next = true then v.home_multiplier
        when o.is_home_next = false then v.away_multiplier
        else null
    end as venue_multiplier,

    -- Final MAP score
    case
        when b.baseline_pts is null then null
        when f.form_ratio is null and v.home_multiplier is null and v.away_multiplier is null and o.opponent_multiplier is null then b.baseline_pts
        else
            b.baseline_pts
            * coalesce(f.form_ratio, 1.0)
            * coalesce(
                case when o.is_home_next = true then v.home_multiplier
                     when o.is_home_next = false then v.away_multiplier
                     else null end,
                1.0
            )
            * coalesce(o.opponent_multiplier, 1.0)
    end as map_score

from {{ ref('int_map_baseline') }} b
left join {{ ref('int_map_form') }} f
    on b.as_of_round_id = f.as_of_round_id and b.id = f.id
left join {{ ref('int_map_venue') }} v
    on b.as_of_round_id = v.as_of_round_id and b.id = v.id
left join {{ ref('int_map_opponent') }} o
    on b.as_of_round_id = o.as_of_round_id and b.id = o.id
