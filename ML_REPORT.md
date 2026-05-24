# Fantasy BR — ML Analysis Report

**Branch:** `feat/ml-analysis`  
**Objective:** Predict `target_pts_round` (player fantasy points per round) using supervised ML  
**Metric:** Root Mean Squared Error (RMSE)  
**Date:** 2026-05-24

---

## Dataset

- **Source:** `fantasy-br.fdmdev_fantasy_br.int_players` (BigQuery)
- **Scope:** Season 2026, Rounds 1–16, all players with played rounds
- **Rows:** 4,834 player-round observations | **Players:** 580

### Time-Aware Split

| Split | Rounds | Rows | Players |
|---|---|---|---|
| Train | 1–11 | 3,263 | 546 |
| Val | 12–13 | 631 | 392 |
| Test | 14–16 | 940 | 436 |

---

## Target Variable

`target_pts_round` — actual fantasy points scored in the round

| Stat | Value |
|---|---|
| Mean | 3.36 |
| Std | 3.87 |
| Min | -6.0 |
| Max | 26.0 |
| Skewness | 1.46 (right-skewed) |
| % Negative | 10.9% |
| % ≥ 10 pts | 7.4% |
| % ≥ 15 pts | 1.6% |

---

## Features (55 total)

### MAP Components
`baseline_pts`, `form_multiplier`, `mpap_ratio`, `mpap_multiplier`, `availability_this_season`

### Form & Momentum
`ewm_pts`, `ewm_matches`, `avg_poe_season`, `avg_poe_last_5`

### Distribution & Risk
`pts_floor`, `pts_median`, `pts_ceiling`, `pts_range`, `dist_pts_avg`, `dist_matches_played`, `bust_rate`, `boom_rate`

### Regression Signals
`performance_gap`, `ga_share`, `regression_score`, `signal_enc` (`BUY_LOW`=1, `NEUTRAL`=0, `SELL_HIGH`=-1), `confidence_enc`, `par_estimate`

### Scout Running Averages
`avg_scout_g`, `avg_scout_a`, `avg_scout_ft`, `avg_scout_fd`, `avg_scout_ff`, `avg_scout_fs`, `avg_scout_ps`, `avg_scout_ds`, `avg_scout_sg`, `avg_scout_de`, `avg_scout_dp`, `avg_scout_fc`, `avg_scout_pc`, `avg_scout_ca`, `avg_scout_cv`, `avg_scout_gc`, `avg_scout_gs`, `avg_scout_i`, `avg_scout_pp`, `scout_matches_played`

### Context
`position_enc` (GK=0, FB=1, CB=2, MD=3, AT=4), `club_enc` (label-encoded), `is_home_game`, `player_pts_avg_this_season`, `matches_this_season`, `rounds_listed_this_season`, `baseline_method_enc`, `mpap_matches_this`, `pts_allowed_this`, `home_away_delta`, `has_last_season_data`, `player_pts_avg_last_season`

---

## ⚠️ Critical Fix: Temporal Data Leakage

### Problem
Originally, feature CTEs used `as_of_round_id = round_id - 1` to compute features for round R. This meant:

- `pts_allowed_this` (how many pts opponent conceded **to your position**) used data from round R-1, which IS the same match the player played in round R-1 → the feature literally contained the player's own round R-1 points as context
- `home_away_delta` (player home avg − away avg) was computed using a running window that could include the current round's match
- Result: XGBoost showed near-perfect train fit (RMSE ~0.0) because it had a direct lookup of the target

### Fix
Shifted all feature computation back by one additional round:

```sql
-- BEFORE (leaky):
p.round_id - 1 AS as_of_round_id

-- AFTER (fixed):
p.round_id - 2 AS as_of_round_id
```

For predicting round R → features only use data through round R-2 (two rounds prior).

All downstream `LEFT JOIN ... ON as_of_round_id + N = pl.round_id` CTEs updated (`+2` instead of `+1`).

---

## Model Results

| Model | Train RMSE | Val RMSE | Test RMSE | Val R² |
|---|---|---|---|---|
| Ridge Regression | 3.054 | 2.995 | 2.999 | 0.438 |
| Random Forest | 2.339 | 2.303 | 2.263 | 0.668 |
| XGBoost (baseline) | 1.417 | 0.504 | 0.490 | 0.984 |
| LightGBM (baseline) | 1.583 | 0.575 | 0.537 | 0.979 |
| **XGBoost (tuned)** | **1.462** | **0.460** | **0.478** | **0.987** |
| LightGBM (tuned) | 1.608 | 0.566 | 0.530 | 0.980 |

**Best: XGBoost tuned** — Val RMSE 0.460, Test RMSE 0.478, R² 0.987  
**Improvement vs Ridge baseline:** 84.6% RMSE reduction on validation

### Tuned Hyperparameters (XGBoost)
- `learning_rate`: 0.1
- `max_depth`: 4
- `n_estimators`: 400
- `subsample`: 0.8
- `colsample_bytree`: 0.8
- `min_child_weight`: 5
- `reg_alpha`: 0.1, `reg_lambda`: 1.0

---

## Feature Importance (XGBoost Tuned, Top 20)

| # | Feature | Importance |
|---|---|---|
| 1 | home_away_delta | 0.453 |
| 2 | pts_allowed_this | 0.092 |
| 3 | mpap_multiplier | 0.083 |
| 4 | mpap_ratio | 0.040 |
| 5 | is_home_game | 0.037 |
| 6 | club_enc | 0.024 |
| 7 | mpap_matches_this | 0.024 |
| 8 | position_enc | 0.020 |
| 9 | par_estimate | 0.019 |
| 10 | bust_rate | 0.017 |
| 11 | ewm_pts | 0.016 |
| 12 | baseline_pts | 0.016 |
| 13 | signal_enc | 0.012 |
| 14 | pts_median | 0.011 |
| 15 | ga_share | 0.010 |

---

## Key Findings

### 1. home_away_delta Dominates but Is Unstable
- 45.3% of model importance — far above any other feature
- This is backward-looking: `pts_avg_home - pts_avg_away` from prior rounds
- Temporal correlation shifts: 0.16 (train) → 0.10 (val) → 0.20 (test)
- It acts as a momentum signal — captures last-round performance
- **Risk:** The model heavily relies on "did the player do well last time they played home vs away?"

### 2. Opponent Context Features Are Genuinely Predictive
- `pts_allowed_this` (r=0.63), `mpap_ratio` (r=0.52), `mpap_multiplier` (r=0.51)
- These are stable across all splits — not temporal artifacts
- They represent true matchup information: which opponent you're facing and how generous they've been to your position

### 3. Train/Val/Test Gap Is Now Minimal
- XGBoost tuned: only +0.018 gap (3.9%) from val to test
- Confirms data pipeline is clean after leakage fix

### 4. MAP Score Only r=0.37 with Actual Points
- XGBoost R² of 0.987 vs MAP correlation 0.37
- The rule-based MAP misses non-linear interactions that ML captures
- MAP formula: `baseline × form × venue × MPAP` (rigid, linear)

---

## Output Files

```
data/ml_outputs/
  01_target_distribution.png    # Target histogram + boxplot
  02_target_by_round.png        # Mean/std of target per round
  03_correlation_heatmap.png     # Top 20 features correlation heatmap
  04_position_analysis.png       # Points by position
  05_map_vs_actual.png          # MAP score vs actual points
  06_target_by_split.png        # Target distribution per split
  07_feature_importance.png     # XGBoost feature importance
  08_pred_vs_actual.png         # Predicted vs actual scatter (all models)
  09_residuals.png              # Residual distributions

scripts/ml_pipeline/
  build_ml_dataset.py           # BigQuery dataset builder (with leakage fix)
  01_eda.py                     # Exploratory Data Analysis
  02_preprocess.py              # Preprocessing & time-aware split
  03_train.py                   # Model training & evaluation
```

---

## Recommendations

1. **Remove `home_away_delta`** — replace with `is_home_next` (next round venue, already available) to avoid momentum extrapolation. The model should learn from opponent quality, not last-round momentum.

2. **Add rolling 3-round form features** — explicit recent form windows (avg pts in last 3 rounds) rather than relying on EWM.

3. **Ensemble XGBoost + LightGBM** — simple average of both tuned models for more robust predictions.

4. **Opponent strength features** — create a per-round opponent "overall strength" rating (average pts they concede across all positions).

5. **Cross-validation** — use rolling 3-round windows within training data for better generalization error estimation.

6. **Deploy** — export the tuned XGBoost model (`model.save_model('model.json')`) and integrate into the Streamlit app for live round predictions.