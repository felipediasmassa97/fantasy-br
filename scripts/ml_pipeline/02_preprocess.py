"""
Fantasy BR — ML Pipeline Step 2: Data Preprocessing & Feature Engineering

Cleans the dataset:
- Removes/leaks problematic features (venue multipliers with 1.0 target correlation)
- Clips extreme outliers in regression/cv features
- Encodes categoricals
- Splits into train/val/test using time-aware split
- Saves processed data
"""

import json, os, sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder, StandardScaler

DATA_PATH  = "/data/.openclaw/workspace/data/fantasy_br_ml_dataset.csv"
OUT_DIR    = "/data/.openclaw/workspace/data/ml_outputs"
os.makedirs(OUT_DIR, exist_ok=True)

df = pd.read_csv(DATA_PATH)
print(f"Loaded: {df.shape}")

TARGET = "target_pts_round"
RUND_ID = "round_id"
PLAYER_ID = "player_id"

# ── 1. Identify & Remove Leaky Features ──────────────────────────────────────
# IMPORTANT: pts_avg_home, pts_avg_away, multiplier_home, multiplier_away
# have perfect (1.0) correlation with target — this is backward-looking leakage
# from how the venue CTE was computed (running avg includes target round data).
# We remove them and recompute from the raw data if needed.
leaky_venue_cols = [
    'pts_avg_home', 'pts_avg_away',
    'multiplier_home', 'multiplier_away',
]
existing_leaky = [c for c in leaky_venue_cols if c in df.columns]
print(f"\nRemoving leaky venue features: {existing_leaky}")
df = df.drop(columns=existing_leaky, errors='ignore')

# ── 2. Handle Extreme Outliers in Regression/CV Features ─────────────────────
# Features like cv_points, regression_score, consistency_rating have values ~1e13
# These are artifact values from small-sample division; cap them.
extreme_cap_cols = ['cv_points', 'regression_score', 'reg_consistency_rating',
                    'consistency_rating', 'pts_stddev', 'pts_range']
for col in extreme_cap_cols:
    if col in df.columns:
        # Cap at |value| > 100 to something reasonable
        mask = df[col].abs() > 100
        pct = mask.mean() * 100
        if pct > 0:
            print(f"  Capping {col}: {pct:.2f}% extreme values capped")
            df.loc[mask, col] = np.nan  # set to NaN instead of capping arbitrarily

# ── 3. Encode Categorical Variables ──────────────────────────────────────────
# Position: ordinal-like (GK, FB, CB, MD, AT)
pos_order = {'GK': 0, 'FB': 1, 'CB': 2, 'MD': 3, 'AT': 4}
if 'position' in df.columns:
    df['position_enc'] = df['position'].map(pos_order).fillna(-1).astype(int)
    print(f"\nPosition encoding applied: {dict(df['position_enc'].value_counts().sort_index())}")

# Signal label: ordinal encoding
signal_map = {'BUY_LOW': 1, 'NEUTRAL': 0, 'SELL_HIGH': -1}
if 'signal_label' in df.columns:
    df['signal_enc'] = df['signal_label'].map(signal_map).fillna(0).astype(int)

# Confidence flag: binary
if 'confidence_flag' in df.columns:
    df['confidence_enc'] = (df['confidence_flag'] == 'OK').astype(int)

# Club: label encode (tree models handle this)
club_encoder = LabelEncoder()
df['club_enc'] = club_encoder.fit_transform(df['club'].fillna('UNK').astype(str))

# Baseline shrinking method: encode
if 'baseline_shrinking_method' in df.columns:
    sm_encoder = LabelEncoder()
    df['baseline_method_enc'] = sm_encoder.fit_transform(
        df['baseline_shrinking_method'].fillna('UNK').astype(str))

# ── 4. Define Feature Set ────────────────────────────────────────────────────
# Core MAP-component features
map_feats = [
    'baseline_pts', 'form_multiplier', 'mpap_ratio', 'mpap_multiplier',
    'availability_this_season', 'ewm_pts', 'ewm_matches',
    'avg_poe_season', 'avg_poe_last_5',
]

# Distribution & regression features
dist_feats = [
    'pts_floor', 'pts_median', 'pts_ceiling', 'pts_range',
    'dist_pts_avg', 'dist_matches_played',
    'bust_rate', 'boom_rate',
    'performance_gap', 'ga_share',
    'regression_score', 'signal_enc', 'confidence_enc',
    'par_estimate',
]

# Scout features
scout_feats = [
    'avg_scout_g', 'avg_scout_a', 'avg_scout_ft', 'avg_scout_fd',
    'avg_scout_ff', 'avg_scout_fs', 'avg_scout_ps', 'avg_scout_ds',
    'avg_scout_sg', 'avg_scout_de', 'avg_scout_dp', 'avg_scout_fc',
    'avg_scout_pc', 'avg_scout_ca', 'avg_scout_cv',
    'avg_scout_gc', 'avg_scout_gs', 'avg_scout_i', 'avg_scout_pp',
    'scout_matches_played',
]

# Context features
context_feats = [
    'position_enc', 'club_enc', 'is_home_game',
    'player_pts_avg_this_season', 'matches_this_season',
    'rounds_listed_this_season',
    'baseline_method_enc',
    'mpap_matches_this', 'pts_allowed_this',
    'home_away_delta',
    'has_last_season_data',
    'player_pts_avg_last_season',
]

all_features = map_feats + dist_feats + scout_feats + context_feats
# Filter to only features that exist in the dataframe
all_features = [f for f in all_features if f in df.columns]
print(f"\nTotal features: {len(all_features)}")
print(f"Features:\n{all_features}")

# ── 5. Time-Aware Train / Validation / Test Split ───────────────────────────
# Rationale: Fantasy sports performance evolves over season.
# Using first rounds for training (stable), latest for test (simulates real use).
# Train: rounds 1-11 (learn patterns)
# Val:    rounds 12-13 (hyperparameter tuning)
# Test:   rounds 14-16 (final evaluation)
train_rounds = sorted(df['round_id'].unique())[:-5]   # [1..11]
val_rounds   = sorted(df['round_id'].unique())[-5:-3]  # [12, 13]
test_rounds  = sorted(df['round_id'].unique())[-3:]     # [14, 15, 16]

df_train = df[df['round_id'].isin(train_rounds)].copy()
df_val   = df[df['round_id'].isin(val_rounds)].copy()
df_test  = df[df['round_id'].isin(test_rounds)].copy()

print(f"\nTime-aware split:")
print(f"  Train: rounds {sorted(df_train['round_id'].unique())} → {len(df_train)} rows, {df_train['player_id'].nunique()} players")
print(f"  Val:   rounds {sorted(df_val['round_id'].unique())} → {len(df_val)} rows, {df_val['player_id'].nunique()} players")
print(f"  Test:  rounds {sorted(df_test['round_id'].unique())} → {len(df_test)} rows, {df_test['player_id'].nunique()} players")

# ── 6. Prepare X / y ────────────────────────────────────────────────────────
X_train = df_train[all_features].copy()
y_train = df_train[TARGET].copy()

X_val   = df_val[all_features].copy()
y_val   = df_val[TARGET].copy()

X_test  = df_test[all_features].copy()
y_test  = df_test[TARGET].copy()

print(f"\nX_train: {X_train.shape}, y_train: {y_train.shape}")
print(f"X_val:   {X_val.shape},   y_val:   {y_val.shape}")
print(f"X_test:  {X_test.shape},  y_test:  {y_test.shape}")

# ── 7. Missing Data Summary ──────────────────────────────────────────────────
print("\n── Missing Rate by Split ──")
for name, X in [("Train", X_train), ("Val", X_val), ("Test", X_test)]:
    null_pct = X.isnull().mean()
    high_null = null_pct[null_pct > 0.1].sort_values(ascending=False)
    print(f"  {name}: {len(high_null)} features with >10% nulls")
    if len(high_null) > 0:
        print(high_null.head(5).to_string())

# ── 8. Save Preprocessed Data ────────────────────────────────────────────────
preprocessed = {
    'X_train': X_train, 'y_train': y_train,
    'X_val':   X_val,   'y_val':   y_val,
    'X_test':  X_test,  'y_test':  y_test,
    'all_features': all_features,
    'df_train': df_train, 'df_val': df_val, 'df_test': df_test,
}
import pickle
with open(f"{OUT_DIR}/preprocessed_data.pkl", 'wb') as f:
    pickle.dump(preprocessed, f)
print(f"\nSaved preprocessed data → {OUT_DIR}/preprocessed_data.pkl")

# ── 9. Feature Importance Preview (Correlation) ────────────────────────────
print("\n── Target Correlation of Final Features (Train) ──")
corr_with_target = X_train.corrwith(y_train).sort_values(key=abs, ascending=False)
print(corr_with_target.head(20).to_string())
print(f"\nSaved preprocessing report")

# ── 10. Target Distribution by Split ───────────────────────────────────────
fig, axes = plt.subplots(1, 3, figsize=(15, 4))
for ax, (name, y) in zip(axes, [("Train", y_train), ("Val", y_val), ("Test", y_test)]):
    ax.hist(y, bins=40, edgecolor='black', alpha=0.7)
    ax.set_title(f'{name} Distribution\nmean={y.mean():.2f}, std={y.std():.2f}')
    ax.set_xlabel('Points')
plt.tight_layout()
plt.savefig(f"{OUT_DIR}/06_target_by_split.png", dpi=120)
plt.close()
print(f"Saved → {OUT_DIR}/06_target_by_split.png")

print("\n✅ Preprocessing complete")