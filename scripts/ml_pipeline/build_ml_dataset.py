"""
Fantasy BR — ML Training Dataset Builder

Each row = one player in one played round (round_id >= 2).
Features are computed as-of (round_id - 1), i.e. BEFORE the round started.
Target = actual pts_round scored that round.

Usage:
    python3 scripts/build_ml_dataset.py [-o /path/to/output.csv]
"""

import argparse
import json
import os
import sys

import pandas as pd
from google.oauth2 import service_account


DSN = "fantasy-br.fdmdev_fantasy_br"
K = 5  # shrinkage constant


def client():
    creds = json.loads(os.environ["GCP_SERVICE_ACCOUNT_CREDENTIALS"])
    credentials = service_account.Credentials.from_service_account_info(creds)
    import google.cloud.bigquery as bq
    return bq.Client(credentials=credentials, project="fantasy-br")


SQL = f"""
WITH

-- ── 1. Next opponent per player per round ────────────────────────────────────────
next_match_info AS (
    SELECT
        p.season,
        p.round_id,
        p.id AS player_id,
        CASE WHEN m.club_home_id = p.club_id THEN m.club_away_id ELSE m.club_home_id END AS next_opponent_id,
        CASE WHEN m.club_home_id = p.club_id THEN FALSE ELSE TRUE END AS is_home_next
    FROM `{{DSN}}.int_players` AS p
    INNER JOIN `{{DSN}}.int_matches` AS m
        ON m.season = p.season AND m.round_id = p.round_id + 1
        AND (m.club_home_id = p.club_id OR m.club_away_id = p.club_id)
    WHERE p.season = 2026
),

-- ── 2. League-average pts per position per round (this season, up to as_of_round) ─
league_avg AS (
    SELECT
        p.round_id - 2 AS as_of_round_id,
        p.position,
        AVG(IF(p.has_played, p.pts_round, NULL)) AS league_avg_pts
    FROM `{{DSN}}.int_players` AS p
    WHERE p.season = 2026 AND p.round_id >= 3
    GROUP BY as_of_round_id, p.position
),

-- ── 3. Per-opponent per-position pts-allowed (this season, up to as_of_round) ─────
opp_pts_allowed AS (
    SELECT
        p.round_id - 2 AS as_of_round_id,
        p.opponent_id,
        p.position,
        AVG(IF(p.has_played, p.pts_round, NULL)) AS pts_allowed_this,
        COUNTIF(p.has_played) AS matches_this
    FROM `{{DSN}}.int_players` AS p
    WHERE p.season = 2026 AND p.round_id >= 3 AND p.opponent_id IS NOT NULL
    GROUP BY as_of_round_id, p.opponent_id, p.position
),

-- ── 4. MPAP multiplier ───────────────────────────────────────────────────────────
-- Shrinkage toward neutral (ratio=1.0) when sample is small; no prior-season data.
mpap AS (
    SELECT
        la.as_of_round_id,
        opa.opponent_id                          AS defending_club_id,
        opa.position,
        opa.pts_allowed_this,
        opa.matches_this,
        la.league_avg_pts,
        -- Shrinkage toward neutral (1.0) using min(matches_this/k, 1.0)
        CASE WHEN la.league_avg_pts > 0 AND opa.matches_this > 0
             THEN (opa.pts_allowed_this * LEAST(SAFE_DIVIDE(opa.matches_this, {K}), 1.0)
                   + la.league_avg_pts * (1.0 - LEAST(SAFE_DIVIDE(opa.matches_this, {K}), 1.0))
                  ) / la.league_avg_pts
             ELSE NULL END AS mpap_ratio
    FROM league_avg AS la
    INNER JOIN opp_pts_allowed AS opa
        ON la.as_of_round_id = opa.as_of_round_id AND la.position = opa.position
),

-- ── 6. Venue: per-player home/away split (manually computed) ────────────────────
venue AS (
    SELECT
        p.round_id - 2 AS as_of_round_id,
        p.id AS player_id,
        AVG(IF(p.has_played AND p.is_home, p.pts_round, NULL)) AS pts_avg_home,
        AVG(IF(p.has_played AND NOT p.is_home, p.pts_round, NULL)) AS pts_avg_away,
        COUNTIF(p.has_played AND p.is_home) AS matches_home,
        COUNTIF(p.has_played AND NOT p.is_home) AS matches_away
    FROM `{{DSN}}.int_players` AS p
    WHERE p.season = 2026 AND p.round_id >= 3
    GROUP BY as_of_round_id, p.id
),

-- ── 7. Scout running averages (prior rounds only) ───────────────────────────────
scout_running AS (
    SELECT
        p.round_id                               AS target_round_id,
        p.id                                     AS player_id,
        AVG(s.scout_g)                           AS avg_scout_g,
        AVG(s.scout_a)                           AS avg_scout_a,
        AVG(s.scout_ft)                          AS avg_scout_ft,
        AVG(s.scout_fd)                          AS avg_scout_fd,
        AVG(s.scout_ff)                          AS avg_scout_ff,
        AVG(s.scout_fs)                          AS avg_scout_fs,
        AVG(s.scout_ps)                          AS avg_scout_ps,
        AVG(s.scout_ds)                          AS avg_scout_ds,
        AVG(s.scout_sg)                          AS avg_scout_sg,
        AVG(s.scout_de)                          AS avg_scout_de,
        AVG(s.scout_dp)                          AS avg_scout_dp,
        AVG(s.scout_fc)                          AS avg_scout_fc,
        AVG(s.scout_pc)                          AS avg_scout_pc,
        AVG(s.scout_ca)                          AS avg_scout_ca,
        AVG(s.scout_cv)                          AS avg_scout_cv,
        AVG(s.scout_gc)                          AS avg_scout_gc,
        AVG(s.scout_gs)                          AS avg_scout_gs,
        AVG(s.scout_i)                           AS avg_scout_i,
        AVG(s.scout_pp)                          AS avg_scout_pp,
        COUNT(*)                                 AS scout_matches
    FROM `{{DSN}}.int_players` AS p
    INNER JOIN `{{DSN}}.int_players` AS s
        ON  s.season = 2026
        AND s.has_played = TRUE
AND s.round_id < p.round_id - 1
        AND s.id = p.id
    WHERE p.season = 2026 AND p.has_played = TRUE AND p.round_id >= 3
    GROUP BY p.round_id, p.id
),

-- ── 8. Replacement level per position per round ─────────────────────────────────
replacement AS (
    SELECT
        as_of_round_id + 1 AS round_id,
        position,
        replacement_level
    FROM `{{DSN}}.int_replacement_levels`
WHERE as_of_round_id >= 2
),

-- ── 9. Played rounds (target rows) ─────────────────────────────────────────────
played AS (
    SELECT
        round_id,
        id                              AS player_id,
        player_name,
        club,
        position,
        club_id,
        opponent_id                     AS current_opponent_id,
        pts_round                       AS target_pts_round,
        pts_avg                         AS pts_avg_season,
        matches_played                  AS matches_played_season,
        is_home                         AS is_home_game
    FROM `{{DSN}}.int_players`
    WHERE season = 2026 AND has_played = TRUE AND round_id >= 1
),

-- ── 10. Assemble ───────────────────────────────────────────────────────────────
dataset AS (
    SELECT
        pl.round_id,
        pl.player_id,
        pl.player_name,
        pl.club,
        pl.position,
        pl.club_id,
        pl.current_opponent_id,
        pl.is_home_game,

        -- TARGET
        pl.target_pts_round,

        -- Baseline (int_baseline)
        b.player_pts_avg_this_season,
        b.matches_this_season,
        b.rounds_listed_this_season,
        b.player_pts_avg_last_season,
        b.matches_last_season,
        b.availability_last_season,
        b.position_pts_avg_last_season,
        b.has_last_season_data,
        b.baseline_pts,
        b.shrinking_method             AS baseline_shrinking_method,

        -- Availability
        CASE WHEN b.rounds_listed_this_season > 0
             THEN SAFE_DIVIDE(b.matches_this_season, b.rounds_listed_this_season)
             ELSE NULL END             AS availability_this_season,

        -- EWM Form (int_ewm_form)
        e.ewm_pts,
        e.form_multiplier,
        e.matches_used                 AS ewm_matches,

        -- Venue (manually computed)
        v.pts_avg_home,
        v.pts_avg_away,
        v.matches_home,
        v.matches_away,
        CASE WHEN b.baseline_pts > 0
             THEN GREATEST(0.85, LEAST(1.15, SAFE_DIVIDE(v.pts_avg_home, b.baseline_pts)))
             ELSE NULL END             AS multiplier_home,
        CASE WHEN b.baseline_pts > 0
             THEN GREATEST(0.85, LEAST(1.15, SAFE_DIVIDE(v.pts_avg_away, b.baseline_pts)))
             ELSE NULL END             AS multiplier_away,
        (IFNULL(v.pts_avg_home, 0) - IFNULL(v.pts_avg_away, 0)) AS home_away_delta,

        nmi.is_home_next,
        nmi.next_opponent_id,
        -- MPAP (manually computed)
        mp.pts_allowed_this,
        mp.matches_this               AS mpap_matches_this,
        mp.mpap_ratio,
        CASE WHEN mp.mpap_ratio IS NOT NULL
             THEN GREATEST(0.85, LEAST(1.20, mp.mpap_ratio))
             ELSE NULL END            AS mpap_multiplier,

        -- MAP = baseline × form × venue × MPAP
        CASE WHEN b.baseline_pts IS NOT NULL AND e.form_multiplier IS NOT NULL
             THEN b.baseline_pts
                  * e.form_multiplier
                  * COALESCE(
                        CASE WHEN nmi.is_home_next
                             THEN GREATEST(0.85, LEAST(1.15, SAFE_DIVIDE(v.pts_avg_home, b.baseline_pts)))
                             ELSE GREATEST(0.85, LEAST(1.15, SAFE_DIVIDE(v.pts_avg_away, b.baseline_pts)))
                        END, 1.0)
                  * COALESCE(
                        CASE WHEN mp.mpap_ratio IS NOT NULL
                             THEN GREATEST(0.85, LEAST(1.20, mp.mpap_ratio))
                             ELSE 1.0 END, 1.0)
        END             AS map_score_computed,


        -- PoE (int_poe)
        po.avg_poe_season,
        po.avg_poe_last_5,

        -- Distribution (int_distribution_stats)
        d.matches_played              AS dist_matches_played,
        d.pts_avg                     AS dist_pts_avg,
        d.pts_stddev,
        d.pts_floor,
        d.pts_median,
        d.pts_ceiling,
        d.pts_range,
        d.cv                          AS cv_points,
        d.consistency_rating,
        d.boom_rate,
        d.bust_rate,

        -- Regression (int_regression)
        rg.performance_gap,
        rg.ga_share,
        rg.consistency_rating         AS reg_consistency_rating,
        rg.regression_score,
        rg.signal_label,
        rg.confidence_flag,

        -- PAR
        b.baseline_pts - COALESCE(rpl.replacement_level, 0) AS par_estimate,

        -- Scout running averages
        sr.avg_scout_g,
        sr.avg_scout_a,
        sr.avg_scout_ft,
        sr.avg_scout_fd,
        sr.avg_scout_ff,
        sr.avg_scout_fs,
        sr.avg_scout_ps,
        sr.avg_scout_ds,
        sr.avg_scout_sg,
        sr.avg_scout_de,
        sr.avg_scout_dp,
        sr.avg_scout_fc,
        sr.avg_scout_pc,
        sr.avg_scout_ca,
        sr.avg_scout_cv,
        sr.avg_scout_gc,
        sr.avg_scout_gs,
        sr.avg_scout_i,
        sr.avg_scout_pp,
        sr.scout_matches             AS scout_matches_played

    FROM played AS pl

    -- Baseline
LEFT JOIN `{{DSN}}.int_baseline`    AS b   ON b.as_of_round_id + 2 = pl.round_id AND b.id = pl.player_id

    -- EWM Form
LEFT JOIN `{{DSN}}.int_ewm_form`   AS e   ON e.as_of_round_id + 2 = pl.round_id AND e.id = pl.player_id

    -- Venue
LEFT JOIN venue                    AS v   ON v.as_of_round_id + 2 = pl.round_id AND v.player_id = pl.player_id

    -- Next opponent
    LEFT JOIN next_match_info                 AS nmi  ON nmi.season = 2026 AND nmi.round_id = pl.round_id - 1 AND nmi.player_id = pl.player_id

    -- MPAP: opponent faced in this round (current_opponent_id = club being attacked)
LEFT JOIN mpap                      AS mp  ON mp.as_of_round_id = pl.round_id - 2
                                               AND mp.defending_club_id = pl.current_opponent_id
                                               AND mp.position = pl.position

    -- PoE
LEFT JOIN `{{DSN}}.int_poe`        AS po  ON po.as_of_round_id + 2 = pl.round_id AND po.id = pl.player_id

    -- Distribution
LEFT JOIN `{{DSN}}.int_distribution_stats` AS d ON d.as_of_round_id + 2 = pl.round_id AND d.id = pl.player_id

    -- Regression
LEFT JOIN `{{DSN}}.int_regression` AS rg  ON rg.as_of_round_id + 2 = pl.round_id AND rg.id = pl.player_id

    -- PAR
    LEFT JOIN replacement               AS rpl ON rpl.round_id = pl.round_id AND rpl.position = pl.position

    -- Scout running avg
    LEFT JOIN scout_running             AS sr  ON sr.target_round_id = pl.round_id AND sr.player_id = pl.player_id
)

SELECT * FROM dataset
ORDER BY round_id, player_id
"""


def run_query(sql: str) -> pd.DataFrame:
    # Expand DSN placeholder
    sql = sql.replace("{DSN}", DSN)
    df = client().query(sql).to_dataframe()
    return df


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Fantasy BR ML training dataset")
    parser.add_argument("-o", "--output",
        default="/data/.openclaw/workspace/data/fantasy_br_ml_dataset.csv",
        help="Output CSV path")
    args = parser.parse_args()

    out = os.path.expanduser(args.output)
    os.makedirs(os.path.dirname(out), exist_ok=True)

    print("Querying BigQuery (this may take ~1 min)...", flush=True)
    df = run_query(SQL)
    print(f"Got {len(df):,} rows × {len(df.columns)} columns", flush=True)

    df.to_csv(out, index=False, encoding="utf-8")
    print(f"Saved → {out}", flush=True)

    print("\n── Dataset Summary ──")
    print(f"Rounds  : {df['round_id'].min()} – {df['round_id'].max()}")
    print(f"Players : {df['player_id'].nunique():,}")
    print(f"Rows    : {len(df):,}")
    t = df["target_pts_round"]
    print(f"Target  : target_pts_round  (mean={t.mean():.2f}, std={t.std():.2f}, "
          f"min={t.min():.1f}, max={t.max():.1f})")

    nulls = df.isnull().mean().round(4) * 100
    high = nulls[nulls > 0].sort_values(ascending=False)
    print(f"\nColumns with nulls (top 10):")
    print(high.head(10).to_string())

    print(f"\nColumn list:")
    print(list(df.columns))


if __name__ == "__main__":
    main()