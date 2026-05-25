-- =============================================================================
-- BigQuery ML Model: xgb_points_prediction
-- Type: BOOSTED_TREE_REGRESSOR (XGBoost)
-- Dataset: fdmdev_fantasy_br  -- Reference only; actual dataset set via DUMMY_DATASET_PLACEHOLDER
-- =============================================================================
-- This model predicts player fantasy points for a given round.
-- Training data uses features computed up to round R-2 to predict pts_round for round R.
-- =============================================================================

CREATE OR REPLACE MODEL `DUMMY_DATASET_PLACEHOLDER.xgb_points_prediction`
OPTIONS(
    model_type = 'BOOSTED_TREE_REGRESSOR',
    booster_type = 'GBTREE',
    num_boosted_rounds = 400,
    max_depth = 4,
    learning_rate = 0.1,
    subsample = 0.8,
    colsample_bytree = 0.8,
    min_child_weight = 5,
    l1_reg = 0.1,
    l2_reg = 1.0,
    early_stop = TRUE,
    min_relative_loss = 0.01,
    input_label_cols = ['target_pts_round'],
    enable_global_explain = TRUE
)
AS

-- Inline the training data query (Lean 15-feature set)
WITH

base_player_rounds AS (
    SELECT
        pl.player_id,
        pl.round_id,
        pl.pts_round AS target_pts_round,
        pl.is_home AS is_home_game
    FROM `DUMMY_DATASET_PLACEHOLDER.int_players` pl
    WHERE pl.pts_round IS NOT NULL
      AND pl.round_id >= 3
),

feat_baseline AS (
    SELECT
        b.player_id,
        b.as_of_round_id + 2 AS round_id,
        b.baseline_pts,
        b.player_pts_avg_this_season
    FROM `DUMMY_DATASET_PLACEHOLDER.int_baseline` b
    INNER JOIN base_player_rounds br
        ON b.player_id = br.player_id
       AND b.as_of_round_id + 2 = br.round_id
),

feat_ewm_form AS (
    SELECT
        e.player_id,
        e.round_id AS as_of_round_id,
        e.ewm_pts,
        e.form_multiplier
    FROM `DUMMY_DATASET_PLACEHOLDER.int_ewm_form` e
    INNER JOIN base_player_rounds br
        ON e.player_id = br.player_id
       AND e.round_id + 2 = br.round_id
),

feat_mpap AS (
    SELECT
        m.player_id,
        m.as_of_round_id + 2 AS round_id,
        m.mpap_ratio,
        m.mpap_multiplier
    FROM `DUMMY_DATASET_PLACEHOLDER.int_map_score` m
    INNER JOIN base_player_rounds br
        ON m.player_id = br.player_id
       AND m.as_of_round_id + 2 = br.round_id
),

feat_pts_allowed AS (
    SELECT
        r.player_id,
        r.as_of_round_id + 2 AS round_id,
        r.pts_allowed_this
    FROM `DUMMY_DATASET_PLACEHOLDER.int_regression` r
    INNER JOIN base_player_rounds br
        ON r.player_id = br.player_id
       AND r.as_of_round_id + 2 = br.round_id
),

feat_distribution AS (
    SELECT
        d.player_id,
        d.as_of_round_id + 2 AS round_id,
        d.bust_rate,
        d.boom_rate,
        d.dist_pts_avg
    FROM `DUMMY_DATASET_PLACEHOLDER.int_distribution_stats` d
    INNER JOIN base_player_rounds br
        ON d.player_id = br.player_id
       AND d.as_of_round_id + 2 = br.round_id
),

feat_home_away AS (
    SELECT
        h.player_id,
        h.as_of_round_id + 2 AS round_id,
        h.home_away_delta
    FROM `DUMMY_DATASET_PLACEHOLDER.int_home_away` h
    INNER JOIN base_player_rounds br
        ON h.player_id = br.player_id
       AND h.as_of_round_id + 2 = br.round_id
),

feat_availability AS (
    SELECT
        pl.player_id,
        pl.round_id,
        SAFE_DIVIDE(
            COUNTIF(pl.pts_round IS NOT NULL),
            COUNT(*)
        ) AS availability_this_season
    FROM `DUMMY_DATASET_PLACEHOLDER.int_players` pl
    INNER JOIN base_player_rounds br
        ON pl.player_id = br.player_id
       AND pl.round_id <= br.round_id - 2
    GROUP BY pl.player_id, pl.round_id
),

feat_scout AS (
    SELECT
        player_id,
        round_id,
        avg_scout_g,
        avg_scout_a,
        avg_scout_ff,
        avg_scout_fs
    FROM `DUMMY_DATASET_PLACEHOLDER.int_players`
),

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
            ELSE 3
        END AS position_enc
    FROM `DUMMY_DATASET_PLACEHOLDER.int_players`
),

feat_par AS (
    SELECT
        r.player_id,
        r.as_of_round_id + 2 AS round_id,
        r.replacement_level
    FROM `DUMMY_DATASET_PLACEHOLDER.int_replacement_levels` r
    INNER JOIN base_player_rounds br
        ON r.player_id = br.player_id
       AND r.as_of_round_id + 2 = br.round_id
),

training_data AS (
    SELECT
        br.player_id,
        br.round_id,
        br.target_pts_round,

        -- Fill values: training medians from historical data (2024 season).
        -- These ensure the model has complete feature vectors even when
        -- a player's history is sparse (e.g., rookie, few games played).
        COALESCE(baseline.baseline_pts,     3.4785)  AS baseline_pts,   -- median baseline pts
        COALESCE(ewm.ewm_pts,               2.9339)  AS ewm_pts,          -- median EWM pts
        COALESCE(ewm.form_multiplier,       0.8694)  AS form_multiplier,  -- median form multiplier
        COALESCE(mpap.mpap_ratio,           0.9207)  AS mpap_ratio,      -- median MPAP ratio
        COALESCE(pts_allowed.pts_allowed_this, 2.7646) AS pts_allowed_this, -- median pts allowed
        COALESCE(br.is_home_game,           0)       AS is_home_game,    -- default neutral
        COALESCE(pos.position_enc,          3)       AS position_enc,     -- default MD
        COALESCE(baseline.player_pts_avg_this_season, 3.0) AS player_pts_avg_this_season, -- median player avg
        COALESCE(avail.availability_this_season, 0.714) AS availability_this_season, -- median availability
        COALESCE(dist.dist_pts_avg,         3.0)    AS dist_pts_avg,     -- median distribution avg
        COALESCE(dist.bust_rate,            0.5)    AS bust_rate,        -- median bust rate
        COALESCE(dist.boom_rate,            0.0)    AS boom_rate,        -- median boom rate
        COALESCE(scout.avg_scout_g,        0.0)    AS avg_scout_g,       -- median goals per scout
        COALESCE(scout.avg_scout_a,        0.0)    AS avg_scout_a,       -- median assists per scout
        COALESCE(ha.home_away_delta,       0.0)    AS home_away_delta,  -- median home/away delta
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

    WHERE br.round_id >= 3
)

SELECT
    target_pts_round AS label,
    baseline_pts,
    ewm_pts,
    form_multiplier,
    mpap_ratio,
    pts_allowed_this,
    is_home_game,
    position_enc,
    player_pts_avg_this_season,
    availability_this_season,
    dist_pts_avg,
    bust_rate,
    boom_rate,
    avg_scout_g,
    avg_scout_a,
    home_away_delta,
    par_estimate
FROM training_data