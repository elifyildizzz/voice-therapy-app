#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
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
        description="Train first baseline model (Gaussian NB) with subject-level split."
    )
    parser.add_argument(
        "--features-csv",
        type=Path,
        default=Path("ml/reports/features/features_v1.csv"),
        help="Feature table path.",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("ml/models/baseline_v1"),
        help="Directory for artifacts.",
    )
    parser.add_argument(
        "--test-size",
        type=float,
        default=0.2,
        help="Subject-level test split ratio.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed.",
    )
    parser.add_argument(
        "--drop-quality-excluded",
        action="store_true",
        help="Skip rows where quality_exclude=True.",
    )
    return parser.parse_args()


def safe_float(value: str) -> float:
    if value == "" or value is None:
        return np.nan
    try:
        return float(value)
    except Exception:
        return np.nan


def load_feature_rows(path: Path, drop_quality_excluded: bool) -> tuple[list[dict[str, str]], list[str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        rows = []
        feature_names: list[str] = []
        if reader.fieldnames:
            feature_names = [name for name in reader.fieldnames if name not in META_COLUMNS]

        for row in reader:
            if row.get("error", ""):
                continue
            if row.get("label", "") == "":
                continue
            if drop_quality_excluded and row.get("quality_exclude") == "True":
                continue
            rows.append(row)
    return rows, feature_names


def rows_to_matrix(rows: list[dict[str, str]], feature_names: list[str]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    x = np.array(
        [[safe_float(row[name]) for name in feature_names] for row in rows],
        dtype=np.float64,
    )
    y = np.array([row["label"] for row in rows], dtype=object)
    subjects = np.array([row["subject_id"] for row in rows], dtype=object)
    return x, y, subjects


def build_subject_labels(subjects: np.ndarray, labels: np.ndarray) -> dict[str, str]:
    subj_to_labels: defaultdict[str, list[str]] = defaultdict(list)
    for s, l in zip(subjects, labels):
        subj_to_labels[str(s)].append(str(l))

    subject_label: dict[str, str] = {}
    for subj, labs in subj_to_labels.items():
        counter = Counter(labs)
        subject_label[subj] = counter.most_common(1)[0][0]
    return subject_label


def stratified_subject_split(
    subject_label: dict[str, str], test_size: float, seed: int
) -> tuple[set[str], set[str]]:
    rng = np.random.default_rng(seed)
    label_to_subjects: defaultdict[str, list[str]] = defaultdict(list)
    for subj, label in subject_label.items():
        label_to_subjects[label].append(subj)

    train_subjects: set[str] = set()
    test_subjects: set[str] = set()

    for label, subjects in label_to_subjects.items():
        arr = np.array(subjects, dtype=object)
        rng.shuffle(arr)
        n_total = arr.size
        n_test = max(1, int(round(n_total * test_size))) if n_total > 1 else 0
        if n_test >= n_total:
            n_test = n_total - 1

        test_part = set(arr[:n_test].tolist())
        train_part = set(arr[n_test:].tolist())

        test_subjects |= test_part
        train_subjects |= train_part

    if not train_subjects or not test_subjects:
        all_subjects = list(subject_label.keys())
        rng.shuffle(all_subjects)
        cut = max(1, int(round(len(all_subjects) * (1 - test_size))))
        train_subjects = set(all_subjects[:cut])
        test_subjects = set(all_subjects[cut:])
    return train_subjects, test_subjects


def standardize_fit(x_train: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    mean = np.nanmean(x_train, axis=0)
    std = np.nanstd(x_train, axis=0)
    std[~np.isfinite(std) | (std < 1e-12)] = 1.0
    x_train = np.where(np.isfinite(x_train), x_train, mean)
    x_scaled = (x_train - mean) / std
    return x_scaled, mean, std


def standardize_apply(x: np.ndarray, mean: np.ndarray, std: np.ndarray) -> np.ndarray:
    x = np.where(np.isfinite(x), x, mean)
    return (x - mean) / std


def fit_gaussian_nb(x: np.ndarray, y: np.ndarray) -> dict[str, np.ndarray]:
    classes = np.array(sorted(set(y.tolist())), dtype=object)
    n_features = x.shape[1]
    priors = np.zeros(classes.size, dtype=np.float64)
    means = np.zeros((classes.size, n_features), dtype=np.float64)
    variances = np.zeros((classes.size, n_features), dtype=np.float64)

    for i, c in enumerate(classes):
        mask = y == c
        xc = x[mask]
        priors[i] = float(np.mean(mask))
        means[i] = np.mean(xc, axis=0)
        variances[i] = np.var(xc, axis=0) + 1e-6

    return {
        "classes": classes,
        "priors": priors,
        "means": means,
        "variances": variances,
    }


def predict_gaussian_nb(model: dict[str, np.ndarray], x: np.ndarray) -> np.ndarray:
    classes = model["classes"]
    priors = model["priors"]
    means = model["means"]
    variances = model["variances"]

    log_probs = []
    for i in range(classes.size):
        mean = means[i]
        var = variances[i]
        log_prior = np.log(priors[i] + 1e-12)
        # log gaussian density (diagonal covariance)
        ll = -0.5 * np.sum(np.log(2.0 * np.pi * var) + ((x - mean) ** 2) / var, axis=1)
        log_probs.append(log_prior + ll)
    log_probs = np.vstack(log_probs).T
    pred_idx = np.argmax(log_probs, axis=1)
    return classes[pred_idx]


def classification_metrics(y_true: np.ndarray, y_pred: np.ndarray) -> dict[str, object]:
    labels = sorted(set(y_true.tolist()) | set(y_pred.tolist()))
    label_to_idx = {label: i for i, label in enumerate(labels)}
    cm = np.zeros((len(labels), len(labels)), dtype=np.int64)
    for t, p in zip(y_true, y_pred):
        cm[label_to_idx[str(t)], label_to_idx[str(p)]] += 1

    acc = float(np.mean(y_true == y_pred))

    per_label = {}
    f1s = []
    for i, label in enumerate(labels):
        tp = cm[i, i]
        fp = int(np.sum(cm[:, i]) - tp)
        fn = int(np.sum(cm[i, :]) - tp)
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1 = (2 * precision * recall / (precision + recall)) if (precision + recall) > 0 else 0.0
        per_label[label] = {
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "support": int(np.sum(cm[i, :])),
        }
        f1s.append(f1)

    return {
        "accuracy": acc,
        "macro_f1": float(np.mean(f1s)) if f1s else 0.0,
        "labels": labels,
        "confusion_matrix": cm.tolist(),
        "per_label": per_label,
    }


def main() -> None:
    args = parse_args()
    out_dir = args.out_dir.expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    rows, feature_names = load_feature_rows(
        args.features_csv.expanduser().resolve(),
        drop_quality_excluded=args.drop_quality_excluded,
    )
    if not rows:
        raise SystemExit("No labeled rows found in features CSV.")
    if not feature_names:
        raise SystemExit("No feature columns found.")

    x, y, subjects = rows_to_matrix(rows, feature_names)
    subj_label = build_subject_labels(subjects, y)
    train_subjects, test_subjects = stratified_subject_split(
        subj_label, test_size=args.test_size, seed=args.seed
    )

    train_mask = np.array([s in train_subjects for s in subjects], dtype=bool)
    test_mask = np.array([s in test_subjects for s in subjects], dtype=bool)
    if not np.any(train_mask) or not np.any(test_mask):
        raise SystemExit("Train/Test split failed: empty partition.")

    x_train_raw, y_train = x[train_mask], y[train_mask]
    x_test_raw, y_test = x[test_mask], y[test_mask]

    x_train, scaler_mean, scaler_std = standardize_fit(x_train_raw)
    x_test = standardize_apply(x_test_raw, scaler_mean, scaler_std)

    model = fit_gaussian_nb(x_train, y_train)
    y_pred = predict_gaussian_nb(model, x_test)

    metrics = classification_metrics(y_test, y_pred)
    metrics["n_train_rows"] = int(x_train.shape[0])
    metrics["n_test_rows"] = int(x_test.shape[0])
    metrics["n_train_subjects"] = int(len(train_subjects))
    metrics["n_test_subjects"] = int(len(test_subjects))

    np.savez(
        out_dir / "model_arrays.npz",
        classes=model["classes"],
        priors=model["priors"],
        means=model["means"],
        variances=model["variances"],
        scaler_mean=scaler_mean,
        scaler_std=scaler_std,
    )

    (out_dir / "model_meta.json").write_text(
        json.dumps(
            {
                "model_type": "gaussian_nb_numpy",
                "feature_names": feature_names,
                "classes": model["classes"].tolist(),
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    (out_dir / "metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    (out_dir / "split.json").write_text(
        json.dumps(
            {
                "train_subjects": sorted(train_subjects),
                "test_subjects": sorted(test_subjects),
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    with (out_dir / "test_predictions.csv").open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["subject_id", "y_true", "y_pred"])
        writer.writeheader()
        test_subjects_arr = subjects[test_mask]
        for subj, yt, yp in zip(test_subjects_arr, y_test, y_pred):
            writer.writerow({"subject_id": subj, "y_true": yt, "y_pred": yp})

    print(f"[OK] Model dir: {out_dir}")
    print(f"[INFO] Train rows: {metrics['n_train_rows']}, Test rows: {metrics['n_test_rows']}")
    print(f"[INFO] Accuracy: {metrics['accuracy']:.4f}, Macro-F1: {metrics['macro_f1']:.4f}")


if __name__ == "__main__":
    main()
