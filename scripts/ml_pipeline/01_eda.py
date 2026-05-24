"""
Fantasy BR — ML Pipeline Step 1: Exploratory Data Analysis

Best practices applied:
- Load and profile the dataset
- Check target distribution, class balance, outliers
- Feature distributions and correlations
- Time-aware summary statistics
- Missing data patterns
"""

import json, os, sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats

DATA_PATH = "/data/.openclaw/workspace/data/fantasy_br_ml_dataset.csv"
OUT_DIR   = "/data/.openclaw/workspace/data/ml_outputs"
os.makedirs(OUT_DIR, exist_ok=True)

# ── Load ──────────────────────────────────────────────────────────────────────
df = pd.read_csv(DATA_PATH)
print(f"Dataset: {df.shape[0]} rows × {df.shape[1]} columns")
print(f"Rounds: {df['round_id'].min()} – {df['round_id'].max()}")
print(f"Players: {df['player_id'].nunique()}")
print(f"\nColumns:\n{list(df.columns)}\n")

# ── Target Distribution ────────────────────────────────────────────────────────
target = df['target_pts_round']
print("── Target (target_pts_round) ──")
print(target.describe())
print(f"Skewness: {target.skew():.3f}")
print(f"Kurtosis: {target.kurtosis():.3f}")
print(f"Negative pts: {(target < 0).sum()} ({(target < 0).mean()*100:.1f}%)")
print(f"Zero pts:    {(target == 0).sum()} ({(target == 0).mean()*100:.1f}%)")
print(f">= 10 pts:   {(target >= 10).sum()} ({(target >= 10).mean()*100:.1f}%)")
print(f">= 15 pts:   {(target >= 15).sum()} ({(target >= 15).mean()*100:.1f}%)")

fig, axes = plt.subplots(1, 3, figsize=(15, 4))
axes[0].hist(target, bins=50, edgecolor='black', alpha=0.7)
axes[0].set_title('Target Distribution')
axes[0].set_xlabel('Points')
axes[1].hist(np.log1p(np.maximum(target, 0)), bins=50, edgecolor='black', alpha=0.7, color='orange')
axes[1].set_title('Log(1 + max(pts, 0))')
axes[2].boxplot(target, vert=True)
axes[2].set_title('Boxplot')
plt.tight_layout()
plt.savefig(f"{OUT_DIR}/01_target_distribution.png", dpi=120)
plt.close()
print(f"Saved → {OUT_DIR}/01_target_distribution.png")

# ── Time-aware Target Stats ───────────────────────────────────────────────────
time_stats = df.groupby('round_id')['target_pts_round'].agg(['mean','std','median','min','max'])
print("\n── Target by Round ──")
print(time_stats.round(3).to_string())
time_stats.plot(subplots=True, figsize=(12, 8), marker='o')
plt.tight_layout()
plt.savefig(f"{OUT_DIR}/02_target_by_round.png", dpi=120)
plt.close()

# ── Feature Null Rates ─────────────────────────────────────────────────────────
null_rates = df.isnull().mean().round(4) * 100
null_rates = null_rates[null_rates > 0].sort_values(ascending=False)
print("\n── Null Rates (>0%) ──")
print(null_rates.to_string())

# ── Numerical Features Summary ─────────────────────────────────────────────────
numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
exclude = ['round_id', 'player_id', 'club_id', 'current_opponent_id', 'next_opponent_id']
num_feats = [c for c in numeric_cols if c not in exclude]
print(f"\n── Numerical Features ({len(num_feats)}) ──")
print(df[num_feats].describe().round(3).to_string())

# ── Feature Correlations with Target ──────────────────────────────────────────
corrs = df[num_feats].corrwith(df['target_pts_round']).sort_values(key=abs, ascending=False)
print("\n── Top 20 Correlations with Target ──")
print(corrs.head(20).to_string())
print("\n── Bottom 10 Correlations with Target ──")
print(corrs.tail(10).to_string())

# Heatmap of top correlated features
top_corr = corrs.abs().nlargest(20).index.tolist()
fig, ax = plt.subplots(figsize=(10, 8))
sns.heatmap(df[top_corr + ['target_pts_round']].corr(), annot=True, fmt='.2f', cmap='RdBu_r',
            center=0, ax=ax, annot_kws={'size': 7}, square=True)
ax.set_title('Correlation Heatmap — Top 20 Features vs Target')
plt.tight_layout()
plt.savefig(f"{OUT_DIR}/03_correlation_heatmap.png", dpi=120)
plt.close()
print(f"Saved → {OUT_DIR}/03_correlation_heatmap.png")

# ── Categorical Features ───────────────────────────────────────────────────────
for cat_col in ['position', 'club', 'is_home_game', 'signal_label', 'confidence_flag']:
    if cat_col in df.columns:
        print(f"\n── {cat_col} value counts ──")
        print(df[cat_col].value_counts().to_string())

# ── Position Analysis ──────────────────────────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(12, 4))
df.boxplot(column='target_pts_round', by='position', ax=axes[0])
axes[0].set_title('Points by Position')
axes[0].set_xlabel('Position')
axes[0].set_ylabel('Points')
plt.suptitle('')
df.groupby('position')['target_pts_round'].mean().sort_values().plot(kind='bar', ax=axes[1], color='steelblue')
axes[1].set_title('Mean Points by Position')
axes[1].set_ylabel('Mean Points')
plt.tight_layout()
plt.savefig(f"{OUT_DIR}/04_position_analysis.png", dpi=120)
plt.close()

# ── Outlier Analysis ───────────────────────────────────────────────────────────
q1 = target.quantile(0.25)
q3 = target.quantile(0.75)
iqr = q3 - q1
lower = q1 - 1.5 * iqr
upper = q3 + 1.5 * iqr
outliers = df[(target < lower) | (target > upper)]
print(f"\n── Outliers (IQR method) ──")
print(f"Lower: {lower:.2f}, Upper: {upper:.2f}")
print(f"Outliers: {len(outliers)} ({len(outliers)/len(df)*100:.1f}%)")
print(f"Outlier pts range: [{outliers['target_pts_round'].min()}, {outliers['target_pts_round'].max()}]")

# ── Availability & Missing Data Patterns ────────────────────────────────────────
print("\n── Availability vs Target ──")
if 'availability_this_season' in df.columns:
    df['avail_bin'] = pd.cut(df['availability_this_season'], bins=[0, 0.25, 0.5, 0.75, 1.0], labels=['0-25%','25-50%','50-75%','75-100%'])
    print(df.groupby('avail_bin')['target_pts_round'].agg(['mean','std','count']).round(3).to_string())

# ── MAP Score vs Actual ────────────────────────────────────────────────────────
if 'map_score_computed' in df.columns:
    map_df = df.dropna(subset=['map_score_computed'])
    map_corr = map_df['map_score_computed'].corr(map_df['target_pts_round'])
    print(f"\n── MAP Score vs Actual (non-null MAP) ──")
    print(f"N = {len(map_df)}, Correlation = {map_corr:.4f}")
    fig, ax = plt.subplots(figsize=(6, 6))
    ax.scatter(map_df['map_score_computed'], map_df['target_pts_round'], alpha=0.3, s=10)
    ax.set_xlabel('MAP Score (computed)')
    ax.set_ylabel('Actual Points')
    ax.set_title(f'MAP Score vs Actual (r = {map_corr:.3f})')
    # Add diagonal
    lims = [min(ax.get_xlim()[0], ax.get_ylim()[0]), max(ax.get_xlim()[1], ax.get_ylim()[1])]
    ax.plot(lims, lims, 'r--', alpha=0.5, label='y=x')
    ax.legend()
    plt.tight_layout()
    plt.savefig(f"{OUT_DIR}/05_map_vs_actual.png", dpi=120)
    plt.close()
    print(f"Saved → {OUT_DIR}/05_map_vs_actual.png")

print("\n✅ EDA complete. Figures saved to", OUT_DIR)
