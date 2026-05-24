"""
Fantasy BR — ML Pipeline Step 3: Model Training & Evaluation

Models trained:
1. Ridge Regression (baseline, linear)
2. Random Forest (tree ensemble, handles non-linearity + missing values)
3. Gradient Boosted Trees (XGBoost + LightGBM — best for tabular data)

Evaluation: RMSE on validation and test sets
Best practices applied:
- Native missing value handling (RF/GBDT don't need imputation)
- Hyperparameter tuning via validation set
- Time-aware evaluation (no data leakage from future rounds)
"""

import json, os, sys, pickle
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
from sklearn.linear_model import Ridge
from sklearn.ensemble import RandomForestRegressor
import xgboost as xgb
import lightgbm as lgb

OUT_DIR   = "/data/.openclaw/workspace/data/ml_outputs"
MODEL_DIR = "/data/.openclaw/workspace/data/ml_outputs/models"
os.makedirs(MODEL_DIR, exist_ok=True)

# ── Load Preprocessed Data ────────────────────────────────────────────────────
with open(f"{OUT_DIR}/preprocessed_data.pkl", 'rb') as f:
    preprocessed = pickle.load(f)

X_train = preprocessed['X_train']
y_train = preprocessed['y_train']
X_val   = preprocessed['X_val']
y_val   = preprocessed['y_val']
X_test  = preprocessed['X_test']
y_test  = preprocessed['y_test']
all_features = preprocessed['all_features']
# Convert bool/object column that breaks XGBoost/LightGBM
def to_float(x): return pd.Series([True, False]).map({True: 1.0, False: 0.0}).get(x, -1.0) if pd.notna(x) else -1.0
for _X in [X_train, X_val, X_test]:
    _X['has_last_season_data'] = _X['has_last_season_data'].apply(lambda v: 1.0 if v is True else (0.0 if v is False else -1.0))


print(f"Train: {X_train.shape}, Val: {X_val.shape}, Test: {X_test.shape}")

def rmse(y_true, y_pred):
    return np.sqrt(mean_squared_error(y_true, y_pred))

def evaluate_model(name, model, X_tr, y_tr, X_v, y_v, X_te, y_te):
    """Train and evaluate a model, return metrics dict."""
    model.fit(X_tr, y_tr)

    preds_val = model.predict(X_v)
    preds_test = model.predict(X_te)
    preds_train = model.predict(X_tr)

    # Handle NaN predictions
    preds_val  = np.nan_to_num(preds_val,  nan=np.nanmedian(preds_val))
    preds_test = np.nan_to_num(preds_test, nan=np.median(preds_test))
    preds_train = np.nan_to_num(preds_train, nan=np.median(preds_train))

    train_rmse = rmse(y_tr, preds_train)
    val_rmse   = rmse(y_v, preds_val)
    test_rmse  = rmse(y_te, preds_test)
    val_mae    = mean_absolute_error(y_v, preds_val)
    test_mae   = mean_absolute_error(y_te, preds_test)
    val_r2     = r2_score(y_v, preds_val)
    test_r2    = r2_score(y_te, preds_test)

    print(f"\n{'='*60}")
    print(f"  {name}")
    print(f"{'='*60}")
    print(f"  Train RMSE: {train_rmse:.4f}")
    print(f"  Val   RMSE: {val_rmse:.4f}  MAE: {val_mae:.4f}  R²: {val_r2:.4f}")
    print(f"  Test  RMSE: {test_rmse:.4f}  MAE: {test_mae:.4f}  R²: {test_r2:.4f}")

    return {
        'name': name, 'model': model,
        'train_rmse': train_rmse, 'val_rmse': val_rmse, 'test_rmse': test_rmse,
        'val_mae': val_mae, 'test_mae': test_mae,
        'val_r2': val_r2, 'test_r2': test_r2,
        'preds_val': preds_val, 'preds_test': preds_test,
    }

# ════════════════════════════════════════════════════════════════════════════
# 1. Ridge Regression (Baseline)
# ════════════════════════════════════════════════════════════════════════════
print("\n── Training Ridge Regression (baseline) ──")

# Impute NaN for Ridge (it can't handle NaN)
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline as SKPipeline

ridge_imputer = SimpleImputer(strategy='median')
X_train_imp = pd.DataFrame(ridge_imputer.fit_transform(X_train), columns=X_train.columns)
X_val_imp   = pd.DataFrame(ridge_imputer.transform(X_val),       columns=X_val.columns)
X_test_imp  = pd.DataFrame(ridge_imputer.transform(X_test),     columns=X_test.columns)

ridge_results = evaluate_model(
    "Ridge Regression",
    Ridge(alpha=1.0),
    X_train_imp, y_train,
    X_val_imp,   y_val,
    X_test_imp,  y_test,
)

# Save ridge for comparison
ridge_results['imputer'] = ridge_imputer

# ════════════════════════════════════════════════════════════════════════════
# 2. Random Forest
# ════════════════════════════════════════════════════════════════════════════
print("\n── Training Random Forest ──")

rf_model = RandomForestRegressor(
    n_estimators=200,
    max_depth=10,
    min_samples_leaf=10,
    max_features='sqrt',
    random_state=42,
    n_jobs=-1,
)

rf_results = evaluate_model(
    "Random Forest",
    rf_model,
    X_train, y_train,
    X_val,   y_val,
    X_test,  y_test,
)

# Feature importance
rf_importance = pd.Series(rf_results['model'].feature_importances_, index=all_features)\
                 .sort_values(ascending=False)
print("\n  Top 15 RF Feature Importances:")
print(rf_importance.head(15).to_string())

# ════════════════════════════════════════════════════════════════════════════
# 3. XGBoost — Baseline
# ════════════════════════════════════════════════════════════════════════════
print("\n── Training XGBoost ──")

xgb_model = xgb.XGBRegressor(
    n_estimators=300,
    max_depth=6,
    learning_rate=0.05,
    subsample=0.8,
    colsample_bytree=0.8,
    min_child_weight=5,
    reg_alpha=0.1,
    reg_lambda=1.0,
    random_state=42,
    tree_method='hist',
    n_jobs=-1,
    verbosity=0,
)

xgb_results = evaluate_model(
    "XGBoost (baseline)",
    xgb_model,
    X_train, y_train,
    X_val,   y_val,
    X_test,  y_test,
)

# ════════════════════════════════════════════════════════════════════════════
# 4. LightGBM — Baseline
# ════════════════════════════════════════════════════════════════════════════
print("\n── Training LightGBM ──")

lgb_model = lgb.LGBMRegressor(
    n_estimators=300,
    max_depth=6,
    learning_rate=0.05,
    subsample=0.8,
    colsample_bytree=0.8,
    min_child_samples=20,
    reg_alpha=0.1,
    reg_lambda=1.0,
    random_state=42,
    n_jobs=-1,
    verbose=-1,
)

lgb_results = evaluate_model(
    "LightGBM (baseline)",
    lgb_model,
    X_train, y_train,
    X_val,   y_val,
    X_test,  y_test,
)

# ════════════════════════════════════════════════════════════════════════════
# 5. XGBoost — Hyperparameter Tuning
# ════════════════════════════════════════════════════════════════════════════
print("\n── Tuning XGBoost (learning rate + depth grid) ──")

best_xgb_rmse = float('inf')
best_xgb_cfg  = None

# Quick grid: learning_rate × max_depth
for lr in [0.01, 0.03, 0.05, 0.1]:
    for depth in [4, 6, 8]:
        for n_est in [200, 400]:
            xgb_candidate = xgb.XGBRegressor(
                n_estimators=n_est,
                max_depth=depth,
                learning_rate=lr,
                subsample=0.8,
                colsample_bytree=0.8,
                min_child_weight=5,
                reg_alpha=0.1,
                reg_lambda=1.0,
                random_state=42,
                tree_method='hist',
                n_jobs=-1,
                verbosity=0,
            )
            xgb_candidate.fit(X_train, y_train)
            val_preds = xgb_candidate.predict(X_val)
            val_preds = np.nan_to_num(val_preds, nan=np.median(val_preds))
            val_rmse = rmse(y_val, val_preds)
            if val_rmse < best_xgb_rmse:
                best_xgb_rmse = val_rmse
                best_xgb_cfg = {'lr': lr, 'depth': depth, 'n_est': n_est, 'val_rmse': val_rmse}

print(f"  Best XGBoost config: lr={best_xgb_cfg['lr']}, depth={best_xgb_cfg['depth']}, "
      f"n_est={best_xgb_cfg['n_est']} → Val RMSE={best_xgb_cfg['val_rmse']:.4f}")

best_xgb = xgb.XGBRegressor(
    n_estimators=best_xgb_cfg['n_est'],
    max_depth=best_xgb_cfg['depth'],
    learning_rate=best_xgb_cfg['lr'],
    subsample=0.8,
    colsample_bytree=0.8,
    min_child_weight=5,
    reg_alpha=0.1,
    reg_lambda=1.0,
    random_state=42,
    tree_method='hist',
    n_jobs=-1,
    verbosity=0,
)
xgb_tuned_results = evaluate_model(
    "XGBoost (tuned)",
    best_xgb,
    X_train, y_train,
    X_val,   y_val,
    X_test,  y_test,
)

# ════════════════════════════════════════════════════════════════════════════
# 6. LightGBM — Hyperparameter Tuning
# ════════════════════════════════════════════════════════════════════════════
print("\n── Tuning LightGBM ──")

best_lgb_rmse = float('inf')
best_lgb_cfg  = None

for lr in [0.01, 0.03, 0.05, 0.1]:
    for depth in [4, 6, 8, -1]:
        for n_est in [200, 400]:
            lgb_candidate = lgb.LGBMRegressor(
                n_estimators=n_est,
                max_depth=depth,
                learning_rate=lr,
                subsample=0.8,
                colsample_bytree=0.8,
                min_child_samples=20,
                reg_alpha=0.1,
                reg_lambda=1.0,
                random_state=42,
                n_jobs=-1,
                verbose=-1,
            )
            lgb_candidate.fit(X_train, y_train)
            val_preds = lgb_candidate.predict(X_val)
            val_preds = np.nan_to_num(val_preds, nan=np.median(val_preds))
            val_rmse = rmse(y_val, val_preds)
            if val_rmse < best_lgb_rmse:
                best_lgb_rmse = val_rmse
                best_lgb_cfg = {'lr': lr, 'depth': depth, 'n_est': n_est, 'val_rmse': val_rmse}

print(f"  Best LightGBM config: lr={best_lgb_cfg['lr']}, depth={best_lgb_cfg['depth']}, "
      f"n_est={best_lgb_cfg['n_est']} → Val RMSE={best_lgb_cfg['val_rmse']:.4f}")

best_lgb = lgb.LGBMRegressor(
    n_estimators=best_lgb_cfg['n_est'],
    max_depth=best_lgb_cfg['depth'],
    learning_rate=best_lgb_cfg['lr'],
    subsample=0.8,
    colsample_bytree=0.8,
    min_child_samples=20,
    reg_alpha=0.1,
    reg_lambda=1.0,
    random_state=42,
    n_jobs=-1,
    verbose=-1,
)
lgb_tuned_results = evaluate_model(
    "LightGBM (tuned)",
    best_lgb,
    X_train, y_train,
    X_val,   y_val,
    X_test,  y_test,
)

# ════════════════════════════════════════════════════════════════════════════
# Summary Comparison Table
# ════════════════════════════════════════════════════════════════════════════
all_results = [
    ridge_results, rf_results,
    xgb_results, lgb_results,
    xgb_tuned_results, lgb_tuned_results,
]

print("\n" + "="*70)
print("  MODEL COMPARISON SUMMARY")
print("="*70)
print(f"{'Model':<25} {'Train RMSE':>11} {'Val RMSE':>10} {'Test RMSE':>10} {'Val R²':>8}")
print("-"*70)
for r in all_results:
    print(f"{r['name']:<25} {r['train_rmse']:>11.4f} {r['val_rmse']:>10.4f} "
          f"{r['test_rmse']:>10.4f} {r['val_r2']:>8.4f}")
print("="*70)

# Save best model (by val RMSE)
best_model_result = min(all_results, key=lambda r: r['val_rmse'])
print(f"\n  Best model: {best_model_result['name']} (Val RMSE={best_model_result['val_rmse']:.4f})")

# ── Feature Importance (Best GBDT) ─────────────────────────────────────────
if 'XGBoost' in best_model_result['name'] or 'xgb' in best_model_result['name'].lower():
    best_importance = pd.Series(
        best_model_result['model'].feature_importances_, index=all_features
    ).sort_values(ascending=False)
elif 'LightGBM' in best_model_result['name'] or 'lgb' in best_model_result['name'].lower():
    best_importance = pd.Series(
        best_model_result['model'].feature_importances_, index=all_features
    ).sort_values(ascending=False)
else:
    best_importance = None

if best_importance is not None:
    print("\n  Top 20 Feature Importances (Best Model):")
    print(best_importance.head(20).to_string())

    fig, ax = plt.subplots(figsize=(10, 10))
    best_importance.head(30).sort_values().plot(kind='barh', ax=ax, color='steelblue')
    ax.set_title(f'Feature Importance — {best_model_result["name"]}')
    ax.set_xlabel('Importance')
    plt.tight_layout()
    plt.savefig(f"{OUT_DIR}/07_feature_importance.png", dpi=120)
    plt.close()
    print(f"  Saved → {OUT_DIR}/07_feature_importance.png")

# ── Prediction vs Actual Scatter ───────────────────────────────────────────
fig, axes = plt.subplots(2, 3, figsize=(15, 10))
for ax, r in zip(axes.flat, all_results):
    preds = r['preds_test']
    ax.scatter(y_test, preds, alpha=0.3, s=10)
    ax.plot([y_test.min(), y_test.max()], [y_test.min(), y_test.max()], 'r--', lw=1)
    ax.set_xlabel('Actual')
    ax.set_ylabel('Predicted')
    ax.set_title(f"{r['name']}\nTest RMSE={r['test_rmse']:.3f}")
plt.tight_layout()
plt.savefig(f"{OUT_DIR}/08_pred_vs_actual.png", dpi=120)
plt.close()
print(f"\n  Saved → {OUT_DIR}/08_pred_vs_actual.png")

# ── Residuals Distribution ─────────────────────────────────────────────────
fig, axes = plt.subplots(2, 3, figsize=(15, 8))
for ax, r in zip(axes.flat, all_results):
    residuals = y_test.values - r['preds_test']
    ax.hist(residuals, bins=40, edgecolor='black', alpha=0.7)
    ax.axvline(0, color='red', linestyle='--')
    ax.set_title(f"{r['name']}\nMean={residuals.mean():.3f}, Std={residuals.std():.3f}")
    ax.set_xlabel('Residual')
    ax.set_ylabel('Frequency')
plt.tight_layout()
plt.savefig(f"{OUT_DIR}/09_residuals.png", dpi=120)
plt.close()
print(f"  Saved → {OUT_DIR}/09_residuals.png")

# ── Save All Models & Results ────────────────────────────────────────────────
models_to_save = {r['name']: r['model'] for r in all_results}
results_to_save = []
for r in all_results:
    res = {k: v for k, v in r.items() if k not in ['model']}
    results_to_save.append(res)

with open(f"{OUT_DIR}/models/models.pkl", 'wb') as f:
    pickle.dump(models_to_save, f)

import json as json_lib
with open(f"{OUT_DIR}/models/results_summary.json", 'w') as f:
    json_lib.dump(results_to_save, f, indent=2, default=str)

print(f"\n✅ All models saved → {OUT_DIR}/models/")
print("✅ Complete")