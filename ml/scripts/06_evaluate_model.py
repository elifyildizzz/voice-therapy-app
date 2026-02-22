#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import numpy as np


META_COLUMNS = {
    "subject_id",
    "label",
    "modality",
    "token",
    "wav_path",
    "remarks_flags",
    "quality_exclude",
    "error",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Evaluate saved baseline model on test subjects."
    )
    parser.add_argument(
        "--features-csv",
        type=Path,
        default=Path("ml/reports/features/features_v1.csv"),
        help="Features table used in training.",
    )
    parser.add_argument(
        "--model-dir",
        type=Path,
        default=Path("ml/models/baseline_v1"),
        help="Directory with model_arrays.npz/model_meta.json/split.json",
    )
    parser.add_argument(
        "--out-json",
        type=Path,
        default=Path("ml/models/baseline_v1/eval_metrics.json"),
        help="Output metrics json.",
    )
    return parser.parse_args()


def safe_float(value: str) -> float:
    if value == "" or value is None:
        return np.nan
    try:
        return float(value)
    except Exception:
        return np.nan


def predict_gnb(classes, priors, means, variances, x):
    logs = []
    for i in range(classes.size):
        ll = -0.5 * np.sum(
            np.log(2.0 * np.pi * variances[i]) + ((x - means[i]) ** 2) / variances[i],
            axis=1,
        )
        logs.append(np.log(priors[i] + 1e-12) + ll)
    logs = np.vstack(logs).T
    idx = np.argmax(logs, axis=1)
    return classes[idx]


def metrics(y_true: np.ndarray, y_pred: np.ndarray) -> dict[str, object]:
    labels = sorted(set(y_true.tolist()) | set(y_pred.tolist()))
    label_to_idx = {l: i for i, l in enumerate(labels)}
    cm = np.zeros((len(labels), len(labels)), dtype=np.int64)
    for t, p in zip(y_true, y_pred):
        cm[label_to_idx[str(t)], label_to_idx[str(p)]] += 1

    per_label = {}
    f1s = []
    for i, l in enumerate(labels):
        tp = cm[i, i]
        fp = np.sum(cm[:, i]) - tp
        fn = np.sum(cm[i, :]) - tp
        prec = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        rec = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1 = (2 * prec * rec / (prec + rec)) if (prec + rec) > 0 else 0.0
        per_label[l] = {
            "precision": float(prec),
            "recall": float(rec),
            "f1": float(f1),
            "support": int(np.sum(cm[i, :])),
        }
        f1s.append(f1)

    return {
        "accuracy": float(np.mean(y_true == y_pred)),
        "macro_f1": float(np.mean(f1s)) if f1s else 0.0,
        "labels": labels,
        "confusion_matrix": cm.tolist(),
        "per_label": per_label,
        "n_rows": int(y_true.size),
    }


def main() -> None:
    args = parse_args()
    model_dir = args.model_dir.expanduser().resolve()

    arrays = np.load(model_dir / "model_arrays.npz", allow_pickle=True)
    meta = json.loads((model_dir / "model_meta.json").read_text(encoding="utf-8"))
    split = json.loads((model_dir / "split.json").read_text(encoding="utf-8"))
    test_subjects = set(split["test_subjects"])

    feature_names = meta["feature_names"]
    classes = arrays["classes"]
    priors = arrays["priors"]
    means = arrays["means"]
    variances = arrays["variances"]
    scaler_mean = arrays["scaler_mean"]
    scaler_std = arrays["scaler_std"]

    x_list = []
    y_list = []
    with args.features_csv.expanduser().resolve().open("r", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if row.get("error"):
                continue
            if row.get("label", "") == "":
                continue
            if row["subject_id"] not in test_subjects:
                continue
            x_list.append([safe_float(row[name]) for name in feature_names])
            y_list.append(row["label"])

    if not x_list:
        raise SystemExit("No test rows found for evaluation.")

    x = np.array(x_list, dtype=np.float64)
    x = np.where(np.isfinite(x), x, scaler_mean)
    x = (x - scaler_mean) / scaler_std
    y_true = np.array(y_list, dtype=object)
    y_pred = predict_gnb(classes, priors, means, variances, x)

    result = metrics(y_true, y_pred)
    out_path = args.out_json.expanduser().resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(result, indent=2), encoding="utf-8")

    print(f"[OK] Eval metrics: {out_path}")
    print(f"[INFO] Accuracy={result['accuracy']:.4f} Macro-F1={result['macro_f1']:.4f}")


if __name__ == "__main__":
    main()
