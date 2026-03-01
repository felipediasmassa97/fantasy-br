/*
Scouting Intermediate: Last Match Stats

For each as_of_round, captures the most recent played match per player.
- Points and scout values are raw values from that single match (not averaged).
- availability = 1 if the player played in the as_of_round, 0 otherwise.
- matches_counted = 1 if played, 0 otherwise.

This differs from other scouting windows: stats come from a single match,
and availability reflects only the current round participation.

Enriched with z-scores and DVS via scouting_enrichment macro.
*/

with all_rounds as (
    -- All distinct rounds in season 2026, used as the as_of_round dimension
    select distinct round_id as as_of_round_id
    from {{ ref('int_players') }}
    where season = 2026
),

-- Check whether each player participated in the current as_of_round
round_status as (
    select
        r.as_of_round_id,
        p.id,
        p.name,
        p.club,
        p.club_logo_url,
        p.position,
        p.has_played
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where
        p.season = 2026
        and p.round_id = r.as_of_round_id
),

-- Find the most recent played match per player (up to as_of_round)
-- Used to populate stats even if the player didn't play in the as_of_round itself
last_played_stats as (
    select
        r.as_of_round_id,
        p.id,
        p.pts_round,
        p.base_round,
        p.scout_G,
        p.scout_A,
        p.scout_FT,
        p.scout_FD,
        p.scout_FF,
        p.scout_FS,
        p.scout_PS,
        p.scout_DS,
        p.scout_SG,
        p.scout_DE,
        p.scout_DP,
        p.scout_FC,
        p.scout_PC,
        p.scout_CA,
        p.scout_CV,
        p.scout_GC,
        p.scout_GS,
        p.scout_I,
        p.scout_PP,
        row_number() over (
            partition by r.as_of_round_id, p.id
            order by p.round_id desc
        ) as rn
    from {{ ref('int_players') }} as p
    cross join all_rounds as r
    where
        p.season = 2026
        and p.has_played = true
        and p.round_id <= r.as_of_round_id
),

-- Combine: player info from round_status + stats from most recent played match
-- availability reflects current-round participation only
player_pts as (
    select
        s.as_of_round_id,
        s.id,
        s.name,
        s.club,
        s.club_logo_url,
        s.position,
        if(s.has_played, 1, 0) as matches_counted,
        if(s.has_played, 1.0, 0.0) as availability,
        -- Raw values from most recent played match (not averaged)
        lp.pts_round as pts_avg,
        lp.base_round as base_avg,
        lp.scout_G as avg_G,
        lp.scout_A as avg_A,
        lp.scout_FT as avg_FT,
        lp.scout_FD as avg_FD,
        lp.scout_FF as avg_FF,
        lp.scout_FS as avg_FS,
        lp.scout_PS as avg_PS,
        lp.scout_DS as avg_DS,
        lp.scout_SG as avg_SG,
        lp.scout_DE as avg_DE,
        lp.scout_DP as avg_DP,
        lp.scout_FC as avg_FC,
        lp.scout_PC as avg_PC,
        lp.scout_CA as avg_CA,
        lp.scout_CV as avg_CV,
        lp.scout_GC as avg_GC,
        lp.scout_GS as avg_GS,
        lp.scout_I as avg_I,
        lp.scout_PP as avg_PP
    from round_status as s
    left join last_played_stats as lp
        on
            s.as_of_round_id = lp.as_of_round_id
            and s.id = lp.id
            and lp.rn = 1  -- only the most recent played match
),

-- Enrichment: z-scores and DVS (see scouting_enrichment macro for details)
{{ scouting_enrichment(by_round=true) }}
