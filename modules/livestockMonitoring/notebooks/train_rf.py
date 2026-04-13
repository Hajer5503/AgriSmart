# ============================================================================
# train_rf.py
# Run this ONCE on your machine to generate:
#   - rf_model_final.pkl
#   - disease_label_map.json
#   - llm_rules.txt
#
# SETUP (run once in your terminal):
#   pip install pandas numpy scikit-learn
#
# RUN:
#   python train_rf.py
#
# INPUT:  animal_disease_10k.csv  (must be in the same folder)
# OUTPUT: rf_model_final.pkl, disease_label_map.json, llm_rules.txt
# ============================================================================

import pandas as pd
import numpy as np
import json
import pickle
import re
import time
import os
from collections import Counter
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split, GridSearchCV, StratifiedKFold
from sklearn.metrics import accuracy_score, classification_report

print("=" * 60)
print("  AgriVet AI — RF Training Pipeline")
print("  Reproduces professor-validated preparation notebook")
print("=" * 60)

# ── Check input file ──────────────────────────────────────────────────────────
CSV_FILE = "animal_disease_10k.csv"
if not os.path.exists(CSV_FILE):
    print(f"\n❌  {CSV_FILE} not found in this folder.")
    print("    Make sure the CSV is in the same directory as this script.")
    raise SystemExit(1)

# =============================================================================
# STEP 1 — Load data
# =============================================================================
print(f"\n[1/6] Loading {CSV_FILE}...")
df = pd.read_csv(CSV_FILE)
df.columns = df.columns.str.strip()
print(f"      Shape: {df.shape}  |  Diseases: {df['Disease_Prediction'].nunique()}")

# =============================================================================
# STEP 2 — Parse mixed-format columns (exact notebook logic)
# =============================================================================
print("\n[2/6] Parsing columns...")

# Body_Temperature: "39.5°C" → 39.5
df['Body_Temperature_C'] = (
    df['Body_Temperature']
    .str.replace('°C', '', regex=False)
    .str.strip()
    .astype(float)
)

# Duration: "3 days" / "1 week" → integer days
def parse_duration(val):
    val = str(val).strip().lower()
    if 'week' in val:
        return int(float(val.replace('weeks','').replace('week','').strip()) * 7)
    elif 'day' in val:
        return int(float(val.replace('days','').replace('day','').strip()))
    return 7  # default

df['Duration_Days'] = df['Duration'].apply(parse_duration)
print(f"      Temperature range: [{df['Body_Temperature_C'].min():.1f}, {df['Body_Temperature_C'].max():.1f}]°C")
print(f"      Duration range:    [{df['Duration_Days'].min()}, {df['Duration_Days'].max()}] days")

# =============================================================================
# STEP 3 — Binary symptom flags (exact notebook logic)
# =============================================================================
print("\n[3/6] Encoding binary flags...")

BINARY_COLS = [
    'Appetite_Loss', 'Vomiting', 'Diarrhea', 'Coughing',
    'Labored_Breathing', 'Lameness', 'Skin_Lesions',
    'Nasal_Discharge', 'Eye_Discharge'
]
for col in BINARY_COLS:
    df[col + '_bin'] = (df[col].str.strip().str.lower() == 'yes').astype(int)

for col in BINARY_COLS:
    pct = df[col+'_bin'].mean() * 100
    print(f"      {col+'_bin':<25} {pct:.0f}% positive")

# =============================================================================
# STEP 4 — Feature engineering (exact notebook logic)
# =============================================================================
print("\n[4/6] Engineering features...")

FEVER_THRESHOLD  = 39.5
NORMAL_TEMP_MID  = 38.5

df['symptom_count']   = df[[c+'_bin' for c in BINARY_COLS]].sum(axis=1)
df['is_fever']        = (df['Body_Temperature_C'] > FEVER_THRESHOLD).astype(int)
df['temp_deviation']  = (df['Body_Temperature_C'] - NORMAL_TEMP_MID).round(2)
df['high_heart_rate'] = (df['Heart_Rate'] > 120).astype(int)

print(f"      symptom_count range  : [{df['symptom_count'].min()}, {df['symptom_count'].max()}]")
print(f"      is_fever (>{FEVER_THRESHOLD}°C): {df['is_fever'].sum()} cases ({df['is_fever'].mean()*100:.1f}%)")
print(f"      high_heart_rate      : {df['high_heart_rate'].sum()} cases ({df['high_heart_rate'].mean()*100:.1f}%)")

# =============================================================================
# STEP 5 — Encode categoricals + normalize (exact notebook logic)
# =============================================================================
print("\n[5/6] Encoding & normalizing...")

# Gender
df['Gender_bin'] = (df['Gender'].str.strip().str.lower() == 'male').astype(int)

# Animal one-hot
animal_dummies = pd.get_dummies(df['Animal_Type'], prefix='animal').astype(int)
df = pd.concat([df, animal_dummies], axis=1)

# Breed label encoding
breed_map       = {b: i for i, breed_idx, b in
                   [(i, i, b) for i, b in enumerate(df['Breed'].unique())]}
breed_map       = {b: i for i, b in enumerate(df['Breed'].unique())}
df['Breed_encoded'] = df['Breed'].map(breed_map)

# Target encoding
diseases       = sorted(df['Disease_Prediction'].unique())
disease_to_id  = {d: i for i, d in enumerate(diseases)}
id_to_disease  = {str(i): d for d, i in disease_to_id.items()}
df['Disease_ID'] = df['Disease_Prediction'].map(disease_to_id)

# Min-max normalization (same as notebook)
NUMERICAL_COLS = ['Age', 'Weight', 'Duration_Days',
                  'Body_Temperature_C', 'Heart_Rate', 'temp_deviation']
scaler_params  = {}
for col in NUMERICAL_COLS:
    col_min = float(df[col].min())
    col_max = float(df[col].max())
    df[col + '_norm'] = ((df[col] - col_min) / (col_max - col_min)).round(4)
    scaler_params[col] = {'min': col_min, 'max': col_max}
    print(f"      {col+'_norm':<30} [{df[col+'_norm'].min():.3f}, {df[col+'_norm'].max():.3f}]")

# Final column selection (exact notebook)
animal_dummy_cols = [c for c in df.columns if c.startswith('animal_')]
FINAL_COLS = (
    ['Animal_Type', 'Breed']
    + ['Age_norm', 'Weight_norm', 'Duration_Days_norm',
       'Body_Temperature_C_norm', 'Heart_Rate_norm', 'temp_deviation_norm']
    + [c + '_bin' for c in BINARY_COLS]
    + ['symptom_count', 'is_fever', 'high_heart_rate']
    + ['Gender_bin', 'Breed_encoded']
    + animal_dummy_cols
    + ['Disease_Prediction', 'Disease_ID']
)
df_final = df[FINAL_COLS].reset_index(drop=True)

FEATURE_COLS = [c for c in FINAL_COLS if c not in
                ['Animal_Type', 'Breed', 'Disease_Prediction', 'Disease_ID']]

print(f"\n      Final shape    : {df_final.shape}")
print(f"      Feature cols   : {len(FEATURE_COLS)}")
print(f"      Target classes : {df_final['Disease_ID'].nunique()} diseases")

# Save prepared dataset
df_final.to_csv('animal_disease_ml_ready.csv', index=False)
print("\n      ✅ Saved: animal_disease_ml_ready.csv")

# Save label map (fix int64 serialization bug from notebook)
label_map = {
    "disease_to_id": disease_to_id,
    "id_to_disease": id_to_disease,
    "total_classes": len(disease_to_id),
    "scaler_params": scaler_params
}
with open('disease_label_map.json', 'w') as f:
    json.dump(label_map, f, indent=2)
print("      ✅ Saved: disease_label_map.json  (int64 bug fixed)")

# =============================================================================
# STEP 6 — Train Random Forest with GridSearchCV
# =============================================================================
print("\n[6/6] Training Random Forest...")

X = df_final[FEATURE_COLS].values.astype(np.float32)
y = df_final['Disease_ID'].values.astype(np.int32)

# Drop classes with < 5 samples (can't stratify)
counts    = Counter(y)
valid_idx = [i for i, yi in enumerate(y) if counts[yi] >= 5]
X, y      = X[valid_idx], y[valid_idx]
print(f"      Samples after filtering rare classes: {len(X)}")
print(f"      Classes: {len(np.unique(y))}")

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)
print(f"      Train: {X_train.shape[0]}  |  Test: {X_test.shape[0]}")

# ── GridSearchCV on a 2000-sample subsample (fast, still representative) ─────
print("\n      Running GridSearchCV (this takes ~1-2 min)...")
rng     = np.random.RandomState(42)
gs_idx  = rng.choice(len(X_train), min(2000, len(X_train)), replace=False)
X_gs, y_gs = X_train[gs_idx], y_train[gs_idx]

param_grid = {
    'n_estimators':     [100, 200],
    'max_depth':        [15, 20, None],
    'min_samples_leaf': [1, 2],
    'class_weight':     ['balanced'],
}
cv = StratifiedKFold(n_splits=3, shuffle=True, random_state=42)
gs = GridSearchCV(
    RandomForestClassifier(random_state=42, n_jobs=-1, max_features='sqrt'),
    param_grid, cv=cv, scoring='accuracy', n_jobs=-1, verbose=0
)
t0 = time.time()
gs.fit(X_gs, y_gs)
print(f"      GridSearchCV done in {time.time()-t0:.0f}s")
print(f"      Best params   : {gs.best_params_}")
print(f"      Best CV score : {gs.best_score_:.3f}")

# Save best params for reference
with open('best_rf_params.json', 'w') as f:
    json.dump(gs.best_params_, f, indent=2)

# ── Retrain on FULL training set with best params ─────────────────────────────
print("\n      Retraining on full training set with best params...")
best = gs.best_params_
rf = RandomForestClassifier(
    n_estimators     = best.get('n_estimators', 200),
    max_depth        = best.get('max_depth', 20),
    min_samples_leaf = best.get('min_samples_leaf', 1),
    class_weight     = 'balanced',
    max_features     = 'sqrt',
    random_state     = 42,
    n_jobs           = -1
)
t0 = time.time()
rf.fit(X_train, y_train)
print(f"      Training done in {time.time()-t0:.0f}s")

# ── Evaluation ────────────────────────────────────────────────────────────────
y_pred = rf.predict(X_test)
acc    = accuracy_score(y_test, y_pred)

# Top-3 accuracy (the real metric for this problem)
proba     = rf.predict_proba(X_test)
top3_acc  = np.mean([
    y_test[i] in rf.classes_[np.argsort(proba[i])[-3:]]
    for i in range(len(y_test))
])

print(f"\n      Test accuracy  (top-1): {acc:.3f}  ({acc*100:.1f}%)")
print(f"      Test accuracy  (top-3): {top3_acc:.3f}  ({top3_acc*100:.1f}%)")
print(f"\n      Note: top-3 is the relevant metric because the LLM")
print(f"      reasons over the top-3 candidates, not a hard single prediction.")

# Per-class results (top 15 by support)
report = classification_report(y_test, y_pred, output_dict=True, zero_division=0)
rows = [(id_to_disease.get(k, k), v['f1-score'], int(v['support']))
        for k, v in report.items()
        if isinstance(v, dict) and k.isdigit()]
rows.sort(key=lambda x: -x[2])

print(f"\n      {'Disease':<45} {'F1':>6} {'Support':>8}")
print("      " + "-"*62)
for disease, f1, sup in rows[:15]:
    bar = '█' * int(f1 * 15)
    print(f"      {disease:<45} {f1:>6.2f} {sup:>8}  {bar}")

# ── Feature importances ───────────────────────────────────────────────────────
importances = rf.feature_importances_
feat_imp    = sorted(zip(FEATURE_COLS, importances), key=lambda x: -x[1])

print(f"\n      Top 10 most important features:")
for feat, imp in feat_imp[:10]:
    bar = '█' * int(imp * 100)
    print(f"      {feat:<35} {imp:.4f}  {bar}")

with open('feature_importance.json', 'w') as f:
    json.dump([{'feature': f, 'importance': round(float(i), 4)}
               for f, i in feat_imp[:30]], f, indent=2)

# ── Save model ────────────────────────────────────────────────────────────────
with open('rf_model_final.pkl', 'wb') as f:
    pickle.dump({
        'model':          rf,
        'feature_cols':   FEATURE_COLS,
        'id_to_disease':  id_to_disease,
        'classes':        rf.classes_.tolist(),
        'test_accuracy':  float(acc),
        'top3_accuracy':  float(top3_acc),
        'best_params':    best,
    }, f)
print("\n      ✅ Saved: rf_model_final.pkl")

# ── Extract LLM rules from data ───────────────────────────────────────────────
print("\n      Extracting clinical rules for LLM...")

df_raw = pd.read_csv(CSV_FILE)
df_raw['Body_Temperature_C'] = (
    df_raw['Body_Temperature'].str.replace('°C', '', regex=False).astype(float)
)

ANIMAL_ORDER = ['Dog','Cat','Cow','Horse','Sheep','Goat','Pig','Rabbit']
lines = [
    "=== AGRIVET AI — CLINICAL RULES ===",
    f"Source: RandomForest trained on {len(df_raw)} veterinary cases.",
    f"Top-3 diagnostic accuracy: {top3_acc*100:.0f}%.",
    "Use as hints — always verify with clinical exam.",
    "",
    "USAGE: Cross-check diagnosis against these rules.",
    "Present top-2 likely diseases with key symptoms.",
    "Flag any vital sign outside the typical range.",
    "",
]

for animal in ANIMAL_ORDER:
    sub_all = df_raw[df_raw['Animal_Type'] == animal]
    if sub_all.empty:
        continue
    diseases_in_animal = sub_all['Disease_Prediction'].value_counts()
    lines += [f"{'─'*60}", f"  {animal.upper()} — {len(diseases_in_animal)} diseases", f"{'─'*60}"]

    for disease, n in diseases_in_animal.items():
        if n < 5:
            continue
        sub = sub_all[sub_all['Disease_Prediction'] == disease]

        # Top free-text symptoms
        sym_counts = {}
        for col in ['Symptom_1','Symptom_2','Symptom_3','Symptom_4']:
            for v in sub[col].dropna():
                v = str(v).strip()
                if v.lower() not in ('no','nan',''):
                    sym_counts[v] = sym_counts.get(v, 0) + 1
        top_syms = [s for s, _ in sorted(sym_counts.items(), key=lambda x: -x[1])[:5]]

        # Binary flag rates
        flags = []
        for col in BINARY_COLS:
            rate = (sub[col].str.strip().str.lower() == 'yes').mean()
            if rate >= 0.55:
                flags.append(col.lower().replace('_', ' '))

        avg_temp = sub['Body_Temperature_C'].mean()
        avg_hr   = sub['Heart_Rate'].mean()

        lines.append(f"• {disease} (n={n})")
        lines.append(f"  Symptoms : {', '.join(top_syms) if top_syms else 'variable'}")
        lines.append(f"  Flags    : {', '.join(flags) if flags else 'none dominant'}")
        lines.append(f"  Vitals   : temp={avg_temp:.1f}°C  HR={avg_hr:.0f} bpm")
        lines.append("")

with open('llm_rules.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
print("      ✅ Saved: llm_rules.txt")

# ── Final summary ─────────────────────────────────────────────────────────────
print("\n" + "=" * 60)
print("  TRAINING COMPLETE")
print("=" * 60)
print(f"  Diseases modeled  : {len(np.unique(y))}")
print(f"  Top-1 accuracy    : {acc*100:.1f}%")
print(f"  Top-3 accuracy    : {top3_acc*100:.1f}%")
print(f"  Best RF params    : {best}")
print()
print("  Files generated:")
print("    rf_model_final.pkl       ← trained model")
print("    disease_label_map.json   ← disease ID ↔ name mapping")
print("    animal_disease_ml_ready.csv ← prepared dataset")
print("    llm_rules.txt            ← clinical rules for LLM")
print("    feature_importance.json  ← top features")
print("    best_rf_params.json      ← GridSearch result")
print()
print("  Next step: run agrivet_hf_agent.py")
print("=" * 60)
