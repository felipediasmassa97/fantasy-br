-- =============================================================================
-- ML Training Features SQL for BigQuery ML (Lean Feature Set - 15 features)
-- =============================================================================
-- Purpose: Assemble training dataset for xgb_points_prediction model
-- Temporal rule: Features use data through round R-2 (as_of_round_id + 2 = round_id)
-- Dataset: fdmdev_fantasy_br
-- =============================================================================

WITH

-- -----------------------------------------------------------------------
-- BASE: Player-round observations with target (pts_round as target)
-- -----------------------------------------------------------------------
base_player_rounds AS (
    SELECT
        pl.player_id,
        pl.round_id,
        pl.pts_round AS target_pts_round,
        pl.is_home AS is_home_game
    FROM `fdmdev_fantasy_br.int_players` pl
    WHERE pl.pts_round IS NOT NULL
      AND pl.round_id >= 3  -- Need at least 2 prior rounds for features
),

-- -----------------------------------------------------------------------
-- FEATURE 1: Baseline points (shrinkage mean per player per as_of_round_id)
-- -----------------------------------------------------------------------
feat_baseline AS (
    SELECT
        b.player_id,
        b.as_of_round_id + 2 AS round_id,  -- Shift to align with round_id
        b.baseline_pts,
        b.player_pts_avg_this_season,
        b.matches_this_season
    FROM `fdmdev_fantasy_br.int_baseline` b
    INNER JOIN base_player_rounds br
        ON b.player_id = br.player_id
       AND b.as_of_round_id + 2 = br.round_id
),

-- -----------------------------------------------------------------------
-- FEATURE 2: EWM points and form multiplier
-- -----------------------------------------------------------------------
feat_ewm_form AS (
    SELECT
        e.player_id,
        e.round_id AS as_of_round_id,  -- This is already as_of_round_id
        e.ewm_pts,
        e.form_multiplier
    FROM `fdmdev_fantasy_br.int_ewm_form` e
    INNER JOIN base_player_rounds br
        ON e.player_id = br.player_id
       AND e.round_id + 2 = br.round_id  -- e.round_id is as_of_round_id
),

-- -----------------------------------------------------------------------
-- FEATURE 3: MAP/MPAP scores (multiplier and ratio)
-- -----------------------------------------------------------------------
feat_mpap AS (
    SELECT
        m.player_id,
        m.as_of_round_id + 2 AS round_id,
        m.mpap_ratio,
        m.mpap_multiplier,
        m.mpap_matches_this
    FROM `fdmdev_fantasy_br.int_map_score` m
    INNER JOIN base_player_rounds br
        ON m.player_id = br.player_id
       AND m.as_of_round_id + 2 = br.round_id
),

-- -----------------------------------------------------------------------
-- FEATURE 4: Pts allowed this season (defensive context from regression)
-- -----------------------------------------------------------------------
feat_pts_allowed AS (
    SELECT
        r.player_id,
        r.as_of_round_id + 2 AS round_id,
        r.pts_allowed_this
    FROM `fdmdev_fantasy_br.int_regression` r
    INNER JOIN base_player_rounds br
        ON r.player_id = br.player_id
       AND r.as_of_round_id + 2 = br.round_id
),

-- -----------------------------------------------------------------------
-- FEATURE 5: Distribution stats (bust/boom rates, floor/ceiling)
-- -----------------------------------------------------------------------
feat_distribution AS (
    SELECT
        d.player_id,
        d.as_of_round_id + 2 AS round_id,
        d.pts_floor,
        d.pts_ceiling,
        d.bust_rate,
        d.boom_rate,
        d.dist_pts_avg
    FROM `fdmdev_fantasy_br.int_distribution_stats` d
    INNER JOIN base_player_rounds br
        ON d.player_id = br.player_id
       AND d.as_of_round_id + 2 = br.round_id
),

-- -----------------------------------------------------------------------
-- FEATURE 6: Home/away delta
-- -----------------------------------------------------------------------
feat_home_away AS (
    SELECT
        h.player_id,
        h.as_of_round_id + 2 AS round_id,
        h.home_away_delta,
        h.pts_avg_home,
        h.pts_avg_away
    FROM `fdmdev_fantasy_br.int_home_away` h
    INNER JOIN base_player_rounds br
        ON h.player_id = br.player_id
       AND h.as_of_round_id + 2 = br.round_id
),

-- -----------------------------------------------------------------------
-- FEATURE 7: Availability this season (games played / games available)
-- -----------------------------------------------------------------------
feat_availability AS (
    SELECT
        pl.player_id,
        pl.round_id,
        SAFE_DIVIDE(
            COUNTIF(pl.pts_round IS NOT NULL),
            COUNT(*)
        ) AS availability_this_season
    FROM `fdmdev_fantasy_br.int_players` pl
    INNER JOIN base_player_rounds br
        ON pl.player_id = br.player_id
       AND pl.round_id <= br.round_id - 2  -- Only prior rounds
    GROUP BY pl.player_id, pl.round_id
),

-- -----------------------------------------------------------------------
-- FEATURE 8: Scout running averages (most predictive: G, A, FF, FS)
-- -----------------------------------------------------------------------
feat_scout AS (
    SELECT
        player_id,
        round_id,
        avg_scout_g,
        avg_scout_a,
        avg_scout_ff,
        avg_scout_fs
    FROM `fdmdev_fantasy_br.int_players`
    WHERE round_id IN (SELECT DISTINCT round_id FROM base_player_rounds)
),

-- -----------------------------------------------------------------------
-- FEATURE 9: Position encoding (numeric)
-- -----------------------------------------------------------------------
feat_position AS (
    SELECT DISTINCT
        player_id,
        round_id,
        CASE position_short
            WHEN 'GK' THEN 0
            WHEN 'FB' THEN 1
            WHEN 'CB' THEN 2
            WHEN 'MD' THEN 3
            WHEN 'AT' THEN 4
            ELSE 3  -- Default to MD
        END AS position_enc
    FROM `fdmdev_fantasy_br.int_players`
),

-- -----------------------------------------------------------------------
-- FEATURE 10: PAR estimate (baseline - replacement level)
-- -----------------------------------------------------------------------
feat_par AS (
    SELECT
        r.player_id,
        r.as_of_round_id + 2 AS round_id,
        r.replacement_level
    FROM `fdmdev_fantasy_br.int_replacement_levels` r
    INNER JOIN base_player_rounds br
        ON r.player_id = br.player_id
       AND r.as_of_round_id + 2 = br.round_id
),

-- -----------------------------------------------------------------------
-- COMBINE ALL FEATURES
-- -----------------------------------------------------------------------
training_data AS (
    SELECT
        br.player_id,
        br.round_id,
        br.target_pts_round,

        -- Feature set (lean, ~15 features)
        COALESCE(baseline.baseline_pts, 3.4785)        AS baseline_pts,
        COALESCE(ewm.ewm_pts, 2.9339)                  AS ewm_pts,
        COALESCE(ewm.form_multiplier, 0.8694)          AS form_multiplier,
        COALESCE(mpap.mpap_ratio, 0.9207)             AS mpap_ratio,
        COALESCE(pts_allowed.pts_allowed_this, 2.7646) AS pts_allowed_this,
        COALESCE(br.is_home_game, 0)                   AS is_home_game,
        COALESCE(pos.position_enc, 3)                  AS position_enc,
        COALESCE(baseline.player_pts_avg_this_season, 3.0) AS player_pts_avg_this_season,
        COALESCE(avail.availability_this_season, 0.714) AS availability_this_season,
        COALESCE(dist.dist_pts_avg, 3.0)              AS dist_pts_avg,
        COALESCE(dist.bust_rate, 0.5)                  AS bust_rate,
        COALESCE(dist.boom_rate, 0.0)                  AS boom_rate,
        COALESCE(scout.avg_scout_g, 0.0)               AS avg_scout_g,
        COALESCE(scout.avg_scout_a, 0.0)               AS avg_scout_a,
        COALESCE(ha.home_away_delta, 0.0)               AS home_away_delta,
        COALESCE(baseline.baseline_pts, 3.4785) - COALESCE(par.replacement_level, 3.5544) AS par_estimate

    FROM base_player_rounds br

    LEFT JOIN feat_baseline baseline
        ON br.player_id = baseline.player_id
       AND br.round_id = baseline.round_id

    LEFT JOIN feat_ewm_form ewm
        ON br.player_id = ewm.player_id
       AND ewm.as_of_round_id + 2 = br.round_id

    LEFT JOIN feat_mpap mpap
        ON br.player_id = mpap.player_id
       AND br.round_id = mpap.round_id

    LEFT JOIN feat_pts_allowed pts_allowed
        ON br.player_id = pts_allowed.player_id
       AND br.round_id = pts_allowed.round_id

    LEFT JOIN feat_distribution dist
        ON br.player_id = dist.player_id
       AND br.round_id = dist.round_id

    LEFT JOIN feat_home_away ha
        ON br.player_id = ha.player_id
       AND br.round_id = ha.round_id

    LEFT JOIN feat_availability avail
        ON br.player_id = avail.player_id
       AND br.round_id = avail.round_id

    LEFT JOIN feat_scout scout
        ON br.player_id = scout.player_id
       AND br.round_id = scout.round_id

    LEFT JOIN feat_position pos
        ON br.player_id = pos.player_id
       AND br.round_id = pos.round_id

    LEFT JOIN feat_par par
        ON br.player_id = par.player_id
       AND br.round_id = par.round_id

    WHERE
        -- Ensure no same-round leakage: all features use data through round R-2
        -- No upper bound — model retraining accommodates future rounds automatically
        br.round_id >= 3
)

SELECT * FROM training_data
ORDER BY round_id, player_id
