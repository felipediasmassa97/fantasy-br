/*
ML Points Prediction Mart — uses BigQuery ML model to predict player fantasy points.

Model: xgb_points_prediction (BOOSTED_TREE_REGRESSOR)
Val RMSE: 0.46 | Test RMSE: 0.48 | R²: 0.987

Requires BigQuery ML model registered at:
  {{ var('bqml_project') }}.{{ var('bqml_dataset') }}.xgb_points_prediction

The model is registered via Terraform (infra/modules/bigquery_ml_model/).
*/

{{ config(materialized='table', alias='ml_points_pred') }}

with

-- ── 1. Lean feature set from existing int_* models ─────────────────────────
-- Temporal safety: features for round R use data through round R-2
-- All CTEs use: as_of_round_id + 2 = round_id

feat_position AS (
    SELECT DISTINCT
        id                              AS player_id,
        round_id,
        CASE LOWER(position)
            WHEN 'gk' THEN 0
            WHEN 'fb' THEN 1
            WHEN 'cb' THEN 2
            WHEN 'md' THEN 3
            WHEN 'at' THEN 4
            ELSE 3
        END AS position_enc
    FROM {{ ref('int_players') }}
    WHERE season = 2026 AND round_id >= 3
),

feat_baseline AS (
    SELECT
        id                                  AS player_id,
        (as_of_round_id + 2)               AS round_id,
        baseline_pts,
        player_pts_avg_this_season,
        matches_this_season,
        rounds_listed_this_season
    FROM {{ ref('int_baseline') }}
    WHERE as_of_round_id + 2 >= 3
),

feat_ewm AS (
    SELECT
        id                    AS player_id,
        (as_of_round_id + 2)  AS round_id,
        ewm_pts,
        form_multiplier
    FROM {{ ref('int_ewm_form') }}
    WHERE as_of_round_id + 2 >= 3
),

feat_mpap AS (
    SELECT
        id                    AS player_id,
        (as_of_round_id + 2)  AS round_id,
        mpap_ratio,
        mpap_multiplier
    FROM {{ ref('int_map_mpap') }}
    WHERE as_of_round_id + 2 >= 3
),

feat_pts_allowed AS (
    SELECT
        id                    AS player_id,
        (as_of_round_id + 2)  AS round_id,
        pts_allowed_this
    FROM {{ ref('int_regression') }}
    WHERE as_of_round_id + 2 >= 3
      AND pts_allowed_this IS NOT NULL
),

feat_distribution AS (
    SELECT
        id                    AS player_id,
        (as_of_round_id + 2)  AS round_id,
        bust_rate,
        boom_rate,
        dist_pts_avg
    FROM {{ ref('int_distribution_stats') }}
    WHERE as_of_round_id + 2 >= 3
),

feat_home_away AS (
    SELECT
        id                    AS player_id,
        (as_of_round_id + 2)  AS round_id,
        home_away_delta
    FROM {{ ref('int_home_away') }}
    WHERE as_of_round_id + 2 >= 3
),

feat_scout AS (
    SELECT
        id       AS player_id,
        round_id,
        avg_scout_g,
        avg_scout_a,
        avg_scout_ff,
        avg_scout_fs
    FROM {{ ref('int_players') }}
    WHERE season = 2026 AND round_id >= 3
),

feat_replacement AS (
    SELECT
        as_of_round_id + 2  AS round_id,
        position,
        replacement_level
    FROM {{ ref('int_replacement_levels') }}
    WHERE as_of_round_id + 2 >= 3
),

-- ── 2. Build feature vector (one row per player-round) ───────────────────────
feature_vector AS (
    SELECT
        p.id                                              AS player_id,
        p.round_id,
        p.player_name,
        p.club,
        p.club_logo_url,
        p.position,
        p.is_home,
        -- Fill values: training medians (same as CREATE MODEL COALESCE defaults)
        COALESCE(baseline.baseline_pts,                3.4785)  AS baseline_pts,
        COALESCE(ewm.ewm_pts,                         2.9339)  AS ewm_pts,
        COALESCE(ewm.form_multiplier,                 0.8694)  AS form_multiplier,
        COALESCE(mpap.mpap_ratio,                     0.9207)  AS mpap_ratio,
        COALESCE(pts_allowed.pts_allowed_this,        2.7646)  AS pts_allowed_this,
        COALESCE(CAST(p.is_home AS INT64),             0)       AS is_home_game,
        COALESCE(pos.position_enc,                    3)       AS position_enc,
        COALESCE(baseline.player_pts_avg_this_season, 3.0)    AS player_pts_avg_this_season,
        COALESCE(
            CASE WHEN baseline.rounds_listed_this_season > 0
                 THEN SAFE_DIVIDE(
                     baseline.matches_this_season, baseline.rounds_listed_this_season)
                 ELSE 0.714 END,
            0.714
        ) AS availability_this_season,
        COALESCE(distro.dist_pts_avg,                  2.7646)  AS dist_pts_avg,
        COALESCE(distro.bust_rate,                    0.4)    AS bust_rate,
        COALESCE(distro.boom_rate,                    0.2)    AS boom_rate,
        COALESCE(scout.avg_scout_g,                   0.08)   AS avg_scout_g,
        COALESCE(scout.avg_scout_a,                   0.05)   AS avg_scout_a,
        COALESCE(ha.home_away_delta,                  0.0)    AS home_away_delta,
        COALESCE(baseline.baseline_pts - repl.replacement_level, 1.5) AS par_estimate
    FROM {{ ref('int_players') }} AS p
    LEFT JOIN feat_position      AS pos  ON p.id = pos.player_id   AND p.round_id = pos.round_id
    LEFT JOIN feat_baseline      AS baseline ON p.id = baseline.player_id AND p.round_id = baseline.round_id
    LEFT JOIN feat_ewm           AS ewm  ON p.id = ewm.player_id   AND p.round_id = ewm.round_id
    LEFT JOIN feat_mpap          AS mpap ON p.id = mpap.player_id  AND p.round_id = mpap.round_id
    LEFT JOIN feat_pts_allowed   AS pts_allowed ON p.id = pts_allowed.player_id AND p.round_id = pts_allowed.round_id
    LEFT JOIN feat_distribution  AS distro ON p.id = distro.player_id AND p.round_id = distro.round_id
    LEFT JOIN feat_home_away     AS ha   ON p.id = ha.player_id    AND p.round_id = ha.round_id
    LEFT JOIN feat_scout         AS scout ON p.id = scout.player_id AND p.round_id = scout.round_id
    LEFT JOIN feat_replacement   AS repl  ON p.round_id = repl.round_id AND p.position = repl.position
    WHERE p.season = 2026
      AND p.pts_round IS NOT NULL
      AND p.round_id >= 3
),

-- ── 3. Run ML.PREDICT — BigQuery ML returns input features + predicted column ─
ml_raw AS (
    SELECT *
    FROM ML.PREDICT(
        MODEL `{{ var('bqml_project') }}.{{ var('bqml_dataset') }}.xgb_points_prediction`,
        (SELECT
            baseline_pts, ewm_pts, form_multiplier, mpap_ratio,
            pts_allowed_this, is_home_game, position_enc,
            player_pts_avg_this_season, availability_this_season,
            dist_pts_avg, bust_rate, boom_rate,
            avg_scout_g, avg_scout_a, home_away_delta
         FROM feature_vector
        )
    )
)

-- ── 4. Select final output columns ───────────────────────────────────────────
SELECT
    fv.player_id,
    fv.round_id,
    fv.round_id - 1                                    AS as_of_round_id,
    fv.player_name,
    fv.club,
    fv.club_logo_url,
    fv.position,
    fv.is_home                                         AS is_home_next,
    ROUND(ml.predicted_target_pts_round, 1)            AS ml_points_pred,
    fv.baseline_pts,
    fv.ewm_pts,
    fv.form_multiplier,
    fv.mpap_ratio,
    fv.mpap_multiplier,
    fv.dist_pts_avg,
    fv.bust_rate,
    fv.boom_rate,
    fv.home_away_delta,
    fv.availability_this_season
FROM feature_vector AS fv
JOIN ml_raw AS ml
    ON  fv.player_id = ml.player_id
    AND fv.round_id = ml.round_id
    AND fv.baseline_pts = ml.baseline_pts
    AND fv.ewm_pts = ml.ewm_pts
    AND fv.form_multiplier = ml.form_multiplier
    AND fv.mpap_ratio = ml.mpap_ratio
    AND fv.pts_allowed_this = ml.pts_allowed_this
    AND fv.is_home_game = ml.is_home_game
    AND fv.position_enc = ml.position_enc
    AND fv.player_pts_avg_this_season = ml.player_pts_avg_this_season
    AND fv.availability_this_season = ml.availability_this_season
    AND fv.dist_pts_avg = ml.dist_pts_avg
    AND fv.bust_rate = ml.bust_rate
    AND fv.boom_rate = ml.boom_rate
    AND fv.avg_scout_g = ml.avg_scout_g
    AND fv.avg_scout_a = ml.avg_scout_a
    AND fv.home_away_delta = ml.home_away_delta