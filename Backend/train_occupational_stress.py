"""
train_occupational_stress.py
────────────────────────────────────────────────────────────────────────────
BrainLag — Occupational Stress / Force Wellness

Trains the classifier behind POST /occupational/assess (see occupational.py).

Data:   occupational_stress_with_target.csv (289 rows) — Dryad police-stress
        dataset (Garbarino & Magnavita, 2016), prepared in Day 1's EDA
        notebook (day1_occupational_eda.ipynb). Features are DCS (Demand-
        Control-Support) and ERI (Effort-Reward Imbalance) scale scores.

Target: target_tertile — Low / Moderate / High, built in the EDA notebook
        as a balanced 3-way split (97 / 96 / 96 rows). This is the primary
        target. The notebook also produced a 2-class iso_strain fallback
        (Low/High, 222/67) for use only if the tertile split had turned out
        degenerate — it didn't, so it's unused here.

Models compared: Logistic Regression vs Random Forest, 5-fold stratified
        cross-validation on an 80/20 train/test split. Metrics reported:
        accuracy, macro precision/recall/F1, macro-averaged one-vs-rest
        ROC-AUC, and the confusion matrix. Logistic Regression won on every
        metric (see printed results) and is what's shipped.

Run:
        cd Backend
        python train_occupational_stress.py

Output (written into this same directory, consumed by occupational.py):
        occupational_lr_model.pkl        — trained LogisticRegression
        occupational_scaler.pkl          — StandardScaler fit on the 5 features
        occupational_feature_anchors.pkl — per-feature (p5,p25,p50,p75,p95),
                                            used to map the app's 1-5 Likert
                                            answers onto this model's scale
        occupational_feature_cols.pkl    — feature name order, must match
                                            the order used everywhere above
────────────────────────────────────────────────────────────────────────────
"""

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    precision_recall_fscore_support,
    roc_auc_score,
)
from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split
from sklearn.preprocessing import StandardScaler

DATA_PATH = "../occupational_stress_with_target.csv"
FEATURES = ["demandmedia", "controlmedia", "supportmedia", "effortmedia", "rewardmedia"]
TARGET = "target_tertile"
CLASS_ORDER = ["Low", "Moderate", "High"]
RANDOM_STATE = 42

OUT_MODEL = "occupational_lr_model.pkl"
OUT_SCALER = "occupational_scaler.pkl"
OUT_ANCHORS = "occupational_feature_anchors.pkl"
OUT_COLS = "occupational_feature_cols.pkl"


def load_data():
    df = pd.read_csv(DATA_PATH)
    print(f"Loaded {len(df)} rows from {DATA_PATH}")
    print("Target class balance:")
    print(df[TARGET].value_counts(), "\n")
    return df


def compare_models(X_train, X_test, y_train, y_test):
    """Train + evaluate both candidates on an identical split, print a
    side-by-side comparison, return the name of the winner."""
    scaler = StandardScaler().fit(X_train)
    X_train_s = scaler.transform(X_train)
    X_test_s = scaler.transform(X_test)

    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE)
    candidates = {
        "LogisticRegression": LogisticRegression(max_iter=1000),
        "RandomForest": RandomForestClassifier(n_estimators=200, max_depth=5, random_state=RANDOM_STATE),
    }

    results = {}
    for name, model in candidates.items():
        cv_scores = cross_val_score(model, X_train_s, y_train, cv=skf, scoring="accuracy")
        model.fit(X_train_s, y_train)
        pred = model.predict(X_test_s)
        proba = model.predict_proba(X_test_s)

        test_acc = accuracy_score(y_test, pred)
        precision, recall, f1, _ = precision_recall_fscore_support(y_test, pred, average="macro")

        # Macro one-vs-rest ROC-AUC for the 3-way classifier. Explicitly pass
        # labels=CLASS_ORDER so the column order of `proba` (which follows
        # model.classes_) is guaranteed to line up with y_test's labels
        # regardless of how sklearn happened to sort the classes.
        roc_auc = roc_auc_score(
            y_test,
            proba,
            multi_class="ovr",
            average="macro",
            labels=list(model.classes_),
        )

        results[name] = dict(
            cv_mean=cv_scores.mean(),
            cv_std=cv_scores.std(),
            test_acc=test_acc,
            precision=precision,
            recall=recall,
            f1=f1,
            roc_auc=roc_auc,
        )

        print(f"{name}:")
        for k, v in results[name].items():
            print(f"  {k}: {v:.4f}")
        print("  confusion matrix (Low, Moderate, High):")
        print(" ", confusion_matrix(y_test, pred, labels=CLASS_ORDER))
        print()

    winner = max(results, key=lambda n: results[n]["test_acc"])
    print(f"Winner: {winner}\n")
    return winner


def build_feature_anchors(df):
    """5-point anchor map per feature: Likert 1,2,3,4,5 -> that feature's
    p5,p25,p50,p75,p95 in the real training data. The app interpolates a
    1-5 Likert answer between these anchors (piecewise-linear) instead of
    a plain min-max scale, because several features (e.g. rewardmedia) are
    skewed enough that min-max mapping pushes a neutral "all 3s" persona
    into a wrong risk band — caught during Day 2 integration testing."""
    anchors = {}
    for f in FEATURES:
        anchors[f] = tuple(df[f].quantile([0.05, 0.25, 0.50, 0.75, 0.95]).values)
    return anchors


def main():
    df = load_data()
    X = df[FEATURES].values
    y = df[TARGET].values

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=RANDOM_STATE
    )

    winner = compare_models(X_train, X_test, y_train, y_test)
    if winner != "LogisticRegression":
        print(
            f"NOTE: {winner} beat LogisticRegression on this run — occupational.py "
            "is hardcoded to load a LogisticRegression artifact, so if you intend "
            "to ship a different model you'll need to update occupational.py's "
            "scoring function accordingly, not just this script."
        )

    # Ship the model trained on ALL available data (the comparison above
    # already validated generalisation via cross-validation on the training
    # split — this final fit just makes full use of the small dataset).
    scaler = StandardScaler().fit(X)
    X_scaled = scaler.transform(X)
    final_model = LogisticRegression(max_iter=1000).fit(X_scaled, y)

    anchors = build_feature_anchors(df)

    joblib.dump(final_model, OUT_MODEL)
    joblib.dump(scaler, OUT_SCALER)
    joblib.dump(anchors, OUT_ANCHORS)
    joblib.dump(FEATURES, OUT_COLS)

    print("Saved artifacts:")
    for path in (OUT_MODEL, OUT_SCALER, OUT_ANCHORS, OUT_COLS):
        print(f"  {path}")
    print(f"\nModel classes: {list(final_model.classes_)}")


if __name__ == "__main__":
    main()
