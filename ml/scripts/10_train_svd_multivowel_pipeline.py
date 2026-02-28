#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import importlib
import json
import os
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

import numpy as np


def load_env_file() -> None:
    env_path = Path(__file__).resolve().parents[2] / ".env"
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].strip()
        if "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if not key or key in os.environ:
            continue
        os.environ[key] = os.path.expandvars(value)


def env_path_or_default(name: str, fallback: Path) -> Path:
    raw = os.environ.get(name, str(fallback))
    return Path(os.path.expandvars(raw)).expanduser()


def default_labels_root() -> Path:
    return env_path_or_default(
        "BITIRME_LABELS_ROOT",
        Path.home() / "Desktop" / "bitirme" / "labels_source",
    )


def default_wav_root() -> Path:
    return env_path_or_default(
        "BITIRME_WAV_ROOT",
        Path("ml/processed/wav_nsp"),
    )


def portable_repo_path(path: Path) -> str:
    root = Path(__file__).resolve().parents[2]
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def parse_args() -> argparse.Namespace:
    load_env_file()

    parser = argparse.ArgumentParser(
        description=(
            "Train an SVD multi-vowel pathology pipeline using a_n, i_n and u_n "
            "with concatenated acoustic features."
        )
    )
    parser.add_argument(
        "--labels-source-root",
        type=Path,
        default=default_labels_root(),
        help=(
            "Path containing diagnosis folders. 'healthy' is mapped to label 0, "
            "all other folders to label 1."
        ),
    )
    parser.add_argument(
        "--wav-root",
        type=Path,
        default=default_wav_root(),
        help=(
            "Root directory containing per-subject WAV files. Expected layout is "
            "<subject_id>/vowels/*-a_n.wav, *-i_n.wav, *-u_n.wav."
        ),
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("ml/models/svd_experiment2"),
        help="Output directory for features, metrics and predictions.",
    )
    parser.add_argument(
        "--test-size",
        type=float,
        default=0.2,
        help="Hold-out ratio for the test split.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed.",
    )
    parser.add_argument(
        "--svm-c",
        type=float,
        default=1.0,
        help="C parameter for the SVM model.",
    )
    parser.add_argument(
        "--svm-kernel",
        default="rbf",
        choices=("linear", "rbf", "poly", "sigmoid"),
        help="Kernel for the SVM model.",
    )
    parser.add_argument(
        "--rf-trees",
        type=int,
        default=300,
        help="Number of trees for the Random Forest model.",
    )
    return parser.parse_args()


@dataclass(frozen=True)
class SubjectRecord:
    subject_id: str
    label: int
    files: dict[str, Path]


def require_dependency(module_name: str, package_hint: str):
    try:
        return importlib.import_module(module_name)
    except ModuleNotFoundError as exc:
        raise SystemExit(
            f"Missing dependency '{module_name}'. Install {package_hint} first."
        ) from exc


def collect_subject_labels(labels_root: Path) -> dict[str, int]:
    subject_labels: dict[str, int] = {}
    for group_dir in sorted(p for p in labels_root.iterdir() if p.is_dir()):
        label = 0 if group_dir.name.strip().lower() == "healthy" else 1
        for subject_dir in sorted(p for p in group_dir.iterdir() if p.is_dir() and p.name.isdigit()):
            subject_id = subject_dir.name
            old = subject_labels.get(subject_id)
            if old is not None and old != label:
                # Keep healthy/pathologic conflicts out of the dataset for safety.
                subject_labels[subject_id] = -1
                continue
            subject_labels[subject_id] = label
    return {subject_id: label for subject_id, label in subject_labels.items() if label in (0, 1)}


def find_token_file(subject_vowels_dir: Path, subject_id: str, token: str) -> Path | None:
    candidates = [
        subject_vowels_dir / f"{subject_id}-{token}.wav",
        subject_vowels_dir / f"{token}.wav",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate

    matches = sorted(subject_vowels_dir.glob(f"*{token}.wav"))
    if matches:
        return matches[0]
    return None


def build_subject_records(labels_root: Path, wav_root: Path) -> tuple[list[SubjectRecord], dict[str, int]]:
    subject_labels = collect_subject_labels(labels_root)
    token_names = ("a_n", "i_n", "u_n")
    records: list[SubjectRecord] = []
    stats = {
        "subjects_in_labels": len(subject_labels),
        "subjects_missing_wav_dir": 0,
        "subjects_missing_required_files": 0,
        "subjects_ready": 0,
    }

    for subject_id, label in sorted(subject_labels.items(), key=lambda item: int(item[0])):
        subject_vowels_dir = wav_root / subject_id / "vowels"
        if not subject_vowels_dir.exists():
            stats["subjects_missing_wav_dir"] += 1
            continue

        files: dict[str, Path] = {}
        missing = False
        for token in token_names:
            token_file = find_token_file(subject_vowels_dir, subject_id, token)
            if token_file is None:
                missing = True
                break
            files[token] = token_file

        if missing:
            stats["subjects_missing_required_files"] += 1
            continue

        records.append(SubjectRecord(subject_id=subject_id, label=label, files=files))
        stats["subjects_ready"] += 1

    return records, stats


def parselmouth_voice_features(path: Path) -> dict[str, float]:
    parselmouth = require_dependency("parselmouth", "praat-parselmouth")
    sound = parselmouth.Sound(str(path))
    pitch = sound.to_pitch()
    pulses = parselmouth.praat.call(
        [sound, pitch],
        "To PointProcess (cc)",
    )

    jitter_local = float(
        parselmouth.praat.call(
            pulses,
            "Get jitter (local)",
            0.0,
            0.0,
            0.0001,
            0.02,
            1.3,
        )
    )
    shimmer_local = float(
        parselmouth.praat.call(
            [sound, pulses],
            "Get shimmer (local)",
            0.0,
            0.0,
            0.0001,
            0.02,
            1.3,
            1.6,
        )
    )
    harmonicity = parselmouth.praat.call(
        sound,
        "To Harmonicity (cc)",
        0.01,
        75.0,
        0.1,
        1.0,
    )
    hnr = float(parselmouth.praat.call(harmonicity, "Get mean", 0.0, 0.0))
    return {
        "jitter_local": jitter_local,
        "shimmer_local": shimmer_local,
        "hnr": hnr,
    }


def librosa_mfcc_features(path: Path, n_mfcc: int = 13) -> dict[str, float]:
    librosa = require_dependency("librosa", "librosa")
    y, sr = librosa.load(str(path), sr=None, mono=True)
    if y.size == 0:
        raise ValueError(f"empty_audio:{path}")

    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=n_mfcc)
    mfcc_means = np.mean(mfcc, axis=1)
    return {f"mfcc_{idx + 1}": float(value) for idx, value in enumerate(mfcc_means)}


def extract_token_features(path: Path, token: str) -> dict[str, float]:
    voice = parselmouth_voice_features(path)
    mfcc = librosa_mfcc_features(path, n_mfcc=13)

    features: dict[str, float] = {}
    for name, value in {**voice, **mfcc}.items():
        features[f"{token}_{name}"] = value
    return features


def build_feature_table(records: list[SubjectRecord]) -> tuple[list[dict[str, object]], list[str]]:
    rows: list[dict[str, object]] = []
    feature_names: list[str] = []
    total = len(records)

    for index, record in enumerate(records, start=1):
        if index == 1 or index % 25 == 0 or index == total:
            print(
                f"[INFO] Extracting features: {index}/{total} "
                f"(subject_id={record.subject_id})"
            )
        row: dict[str, object] = {
            "subject_id": record.subject_id,
            "label": record.label,
        }
        for token in ("a_n", "i_n", "u_n"):
            token_features = extract_token_features(record.files[token], token)
            for feature_name in token_features.keys():
                if feature_name not in feature_names:
                    feature_names.append(feature_name)
            row.update(token_features)
        rows.append(row)

    return rows, feature_names


def rows_to_arrays(
    rows: list[dict[str, object]], feature_names: list[str]
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    x = np.array(
        [[float(row[name]) for name in feature_names] for row in rows],
        dtype=np.float64,
    )
    if not np.all(np.isfinite(x)):
        col_means = np.nanmean(np.where(np.isfinite(x), x, np.nan), axis=0)
        col_means = np.where(np.isfinite(col_means), col_means, 0.0)
        bad_mask = ~np.isfinite(x)
        if np.any(bad_mask):
            x[bad_mask] = np.take(col_means, np.where(bad_mask)[1])
    y = np.array([int(row["label"]) for row in rows], dtype=np.int64)
    subjects = np.array([str(row["subject_id"]) for row in rows], dtype=object)
    return x, y, subjects


def train_test_split_subjects(
    subjects: np.ndarray, labels: np.ndarray, test_size: float, seed: int
) -> tuple[np.ndarray, np.ndarray]:
    train_test_split = require_dependency(
        "sklearn.model_selection",
        "scikit-learn",
    ).train_test_split
    unique_subjects = np.array(subjects, dtype=object)
    unique_labels = np.array(labels, dtype=np.int64)
    train_subj, test_subj, _, _ = train_test_split(
        unique_subjects,
        unique_labels,
        test_size=test_size,
        random_state=seed,
        stratify=unique_labels,
    )
    return train_subj, test_subj


def evaluate_predictions(y_true: np.ndarray, y_pred: np.ndarray) -> dict[str, object]:
    metrics_mod = require_dependency("sklearn.metrics", "scikit-learn")
    accuracy = float(metrics_mod.accuracy_score(y_true, y_pred))
    f1 = float(metrics_mod.f1_score(y_true, y_pred, zero_division=0))
    cm = metrics_mod.confusion_matrix(y_true, y_pred, labels=[0, 1]).tolist()
    return {
        "accuracy": accuracy,
        "f1_score": f1,
        "confusion_matrix": cm,
    }


def train_models(
    x_train: np.ndarray,
    y_train: np.ndarray,
    x_test: np.ndarray,
    seed: int,
    svm_c: float,
    svm_kernel: str,
    rf_trees: int,
) -> dict[str, np.ndarray]:
    imblearn_over_sampling = require_dependency(
        "imblearn.over_sampling",
        "imbalanced-learn",
    )
    sklearn_ensemble = require_dependency("sklearn.ensemble", "scikit-learn")
    sklearn_pipeline = require_dependency("sklearn.pipeline", "scikit-learn")
    sklearn_preprocessing = require_dependency("sklearn.preprocessing", "scikit-learn")
    sklearn_svm = require_dependency("sklearn.svm", "scikit-learn")

    minority_count = min(Counter(y_train.tolist()).values())
    k_neighbors = max(1, min(5, minority_count - 1))
    smote = imblearn_over_sampling.SMOTE(random_state=seed, k_neighbors=k_neighbors)
    x_train_balanced, y_train_balanced = smote.fit_resample(x_train, y_train)

    svm_model = sklearn_pipeline.make_pipeline(
        sklearn_preprocessing.StandardScaler(),
        sklearn_svm.SVC(
            C=svm_c,
            kernel=svm_kernel,
            random_state=seed,
        ),
    )
    svm_model.fit(x_train_balanced, y_train_balanced)

    rf_model = sklearn_ensemble.RandomForestClassifier(
        n_estimators=rf_trees,
        random_state=seed,
        class_weight="balanced",
        n_jobs=-1,
    )
    rf_model.fit(x_train_balanced, y_train_balanced)

    return {
        "svm": svm_model.predict(x_test),
        "random_forest": rf_model.predict(x_test),
        "smote_y_train": y_train_balanced,
    }


def write_feature_csv(rows: list[dict[str, object]], feature_names: list[str], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["subject_id", "label", *feature_names])
        writer.writeheader()
        writer.writerows(rows)


def write_predictions_csv(
    subjects: np.ndarray,
    y_true: np.ndarray,
    predictions: dict[str, np.ndarray],
    out_path: Path,
) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8", newline="") as f:
        fieldnames = ["subject_id", "y_true", *predictions.keys()]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for idx, subject_id in enumerate(subjects):
            row = {
                "subject_id": str(subject_id),
                "y_true": int(y_true[idx]),
            }
            for model_name, y_pred in predictions.items():
                row[model_name] = int(y_pred[idx])
            writer.writerow(row)


def main() -> None:
    args = parse_args()

    labels_root = args.labels_source_root.expanduser().resolve()
    wav_root = args.wav_root.expanduser().resolve()
    out_dir = args.out_dir.expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    records, dataset_stats = build_subject_records(labels_root, wav_root)
    if not records:
        raise SystemExit(
            "No valid subjects found. Check labels_source/wav_root and ensure "
            "a_n, i_n and u_n WAV files exist for each subject."
        )
    print(
        "[INFO] Matched subjects: "
        f"{len(records)} "
        f"(missing_wav_dir={dataset_stats['subjects_missing_wav_dir']}, "
        f"missing_required_files={dataset_stats['subjects_missing_required_files']})"
    )

    feature_rows, feature_names = build_feature_table(records)
    x, y, subjects = rows_to_arrays(feature_rows, feature_names)
    print(f"[INFO] Built feature table with {len(feature_names)} features per subject.")

    train_subjects, test_subjects = train_test_split_subjects(
        subjects=subjects,
        labels=y,
        test_size=args.test_size,
        seed=args.seed,
    )

    train_mask = np.isin(subjects, train_subjects)
    test_mask = np.isin(subjects, test_subjects)
    x_train, y_train = x[train_mask], y[train_mask]
    x_test, y_test = x[test_mask], y[test_mask]
    test_subject_ids = subjects[test_mask]
    print(
        f"[INFO] Split complete: train={x_train.shape[0]} subjects, "
        f"test={x_test.shape[0]} subjects"
    )

    prediction_outputs = train_models(
        x_train=x_train,
        y_train=y_train,
        x_test=x_test,
        seed=args.seed,
        svm_c=args.svm_c,
        svm_kernel=args.svm_kernel,
        rf_trees=args.rf_trees,
    )
    print("[INFO] Model training complete. Evaluating predictions...")
    smote_y_train = prediction_outputs.pop("smote_y_train")

    metrics = {
        model_name: evaluate_predictions(y_test, y_pred)
        for model_name, y_pred in prediction_outputs.items()
    }

    summary = {
        "dataset": {
            **dataset_stats,
            "subjects_used": int(len(records)),
            "label_distribution": {
                "healthy_0": int(np.sum(y == 0)),
                "pathologic_1": int(np.sum(y == 1)),
            },
            "train_subject_count": int(np.sum(train_mask)),
            "test_subject_count": int(np.sum(test_mask)),
            "smote_train_distribution": {
                str(label): int(count)
                for label, count in sorted(Counter(smote_y_train.tolist()).items())
            },
        },
        "feature_count": len(feature_names),
        "feature_groups_per_vowel": ["jitter_local", "shimmer_local", "hnr", "mfcc_1..mfcc_13"],
        "models": metrics,
        "paths": {
            "features_csv": portable_repo_path(out_dir / "features_subject_level.csv"),
            "predictions_csv": portable_repo_path(out_dir / "test_predictions.csv"),
            "metrics_json": portable_repo_path(out_dir / "metrics.json"),
        },
    }

    write_feature_csv(feature_rows, feature_names, out_dir / "features_subject_level.csv")
    write_predictions_csv(
        subjects=test_subject_ids,
        y_true=y_test,
        predictions=prediction_outputs,
        out_path=out_dir / "test_predictions.csv",
    )
    (out_dir / "metrics.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print(f"[OK] Output dir: {out_dir}")
    print(
        "[INFO] Subjects used="
        f"{len(records)} train={int(np.sum(train_mask))} test={int(np.sum(test_mask))}"
    )
    for model_name, result in metrics.items():
        print(
            f"[INFO] {model_name}: "
            f"accuracy={result['accuracy']:.4f} f1={result['f1_score']:.4f}"
        )


if __name__ == "__main__":
    main()
