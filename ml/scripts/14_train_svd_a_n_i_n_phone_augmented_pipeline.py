#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import importlib
import json
import os
import shutil
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

import joblib
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


def default_wav_root() -> Path:
    return env_path_or_default("BITIRME_WAV_ROOT", Path("ml/processed/wav_nsp"))


def portable_repo_path(path: Path) -> str:
    root = Path(__file__).resolve().parents[2]
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def require_dependency(module_name: str, package_hint: str):
    try:
        return importlib.import_module(module_name)
    except ModuleNotFoundError as exc:
        raise SystemExit(
            f"Missing dependency '{module_name}'. Install {package_hint} first."
        ) from exc


@dataclass(frozen=True)
class SubjectRecord:
    subject_id: str
    label: int
    files: dict[str, Path]


def parse_args() -> argparse.Namespace:
    load_env_file()

    parser = argparse.ArgumentParser(
        description=(
            "Train a phone-robust a_n+i_n Random Forest by adding "
            "controlled mobile-like augmentations only to the train split."
        )
    )
    parser.add_argument(
        "--base-features-csv",
        type=Path,
        default=Path("ml/models/svd_a_n_i_n_speaker_split_run1/features_subject_level.csv"),
        help="Clean feature table from the original speaker-split experiment.",
    )
    parser.add_argument(
        "--split-json",
        type=Path,
        default=Path("ml/models/svd_a_n_i_n_speaker_split_run1/split.json"),
        help="Speaker split JSON from the original experiment.",
    )
    parser.add_argument(
        "--wav-root",
        type=Path,
        default=default_wav_root(),
        help="Root directory containing per-subject WAV files.",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("ml/models/svd_a_n_i_n_phone_aug_run1"),
        help="Output directory for the phone-robust model and reports.",
    )
    parser.add_argument(
        "--backend-target-dir",
        type=Path,
        default=Path("backend/model_artifacts/svd_a_n_i_n_v2_phone_aug"),
        help="Optional backend artifact export directory.",
    )
    parser.add_argument(
        "--variants-per-subject",
        type=int,
        default=2,
        help="How many augmented variants to create per training subject.",
    )
    parser.add_argument(
        "--max-train-subjects",
        type=int,
        default=0,
        help="Optional debug limit for how many train subjects to augment (0 = all).",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed.",
    )
    parser.add_argument(
        "--rf-trees",
        type=int,
        default=400,
        help="Number of trees for the Random Forest model.",
    )
    return parser.parse_args()


def load_clean_feature_rows(
    features_csv: Path,
) -> tuple[list[dict[str, object]], list[str]]:
    with features_csv.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None:
            raise SystemExit(f"Missing header in CSV: {features_csv}")

        feature_names = [
            name for name in reader.fieldnames if name not in ("subject_id", "label")
        ]
        rows: list[dict[str, object]] = []
        for row in reader:
            rows.append(
                {
                    "subject_id": str(row["subject_id"]),
                    "label": int(row["label"]),
                    **{name: float(row[name]) for name in feature_names},
                }
            )
    return rows, feature_names


def rows_to_matrix(
    rows: list[dict[str, object]],
    feature_names: list[str],
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    x = np.array(
        [[float(row[name]) for name in feature_names] for row in rows],
        dtype=np.float64,
    )
    col_means = np.nanmean(np.where(np.isfinite(x), x, np.nan), axis=0)
    col_means = np.where(np.isfinite(col_means), col_means, 0.0)
    bad_mask = ~np.isfinite(x)
    if np.any(bad_mask):
        x[bad_mask] = np.take(col_means, np.where(bad_mask)[1])

    y = np.array([int(row["label"]) for row in rows], dtype=np.int64)
    subjects = np.array([str(row["subject_id"]) for row in rows], dtype=object)
    return x, y, subjects


def find_token_file(subject_vowels_dir: Path, subject_id: str, token: str) -> Path | None:
    candidates = [
        subject_vowels_dir / f"{subject_id}-{token}.wav",
        subject_vowels_dir / f"{token}.wav",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    matches = sorted(subject_vowels_dir.glob(f"*{token}.wav"))
    return matches[0] if matches else None


def build_train_records(
    wav_root: Path,
    clean_rows: list[dict[str, object]],
    train_subjects: set[str],
    max_train_subjects: int,
) -> list[SubjectRecord]:
    label_map = {
        str(row["subject_id"]): int(row["label"])
        for row in clean_rows
        if str(row["subject_id"]) in train_subjects
    }
    records: list[SubjectRecord] = []
    ordered_subject_ids = sorted(train_subjects, key=int)
    if max_train_subjects > 0:
        ordered_subject_ids = ordered_subject_ids[:max_train_subjects]

    for subject_id in ordered_subject_ids:
        subject_vowels_dir = wav_root / subject_id / "vowels"
        if not subject_vowels_dir.exists() or subject_id not in label_map:
            continue

        a_path = find_token_file(subject_vowels_dir, subject_id, "a_n")
        i_path = find_token_file(subject_vowels_dir, subject_id, "i_n")
        if a_path is None or i_path is None:
            continue

        records.append(
            SubjectRecord(
                subject_id=subject_id,
                label=label_map[subject_id],
                files={"a_n": a_path, "i_n": i_path},
            )
        )
    return records


def _normalize_peak(signal: np.ndarray, target_peak: float = 0.85) -> np.ndarray:
    peak = float(np.max(np.abs(signal))) if signal.size else 0.0
    if peak <= 1e-6:
        return signal
    return signal * (target_peak / peak)


def _augment_signal(
    signal: np.ndarray,
    sr: int,
    rng: np.random.Generator,
) -> tuple[np.ndarray, int]:
    librosa = require_dependency("librosa", "librosa")
    scipy_signal = require_dependency("scipy.signal", "scipy")

    x = signal.astype(np.float32).copy()
    x = _normalize_peak(x)

    target_phone_sr = int(rng.choice([16000, 22050, 32000, 44100]))
    if sr != target_phone_sr:
        x = librosa.resample(x, orig_sr=sr, target_sr=target_phone_sr)
        sr = target_phone_sr

    nyq = sr / 2.0
    low_hz = float(rng.uniform(90.0, 180.0))
    high_hz = float(min(rng.uniform(3200.0, 4200.0), nyq * 0.95))
    if low_hz < high_hz:
        b, a = scipy_signal.butter(
            4,
            [low_hz / nyq, high_hz / nyq],
            btype="bandpass",
        )
        x = scipy_signal.filtfilt(b, a, x).astype(np.float32)

    if rng.random() < 0.7:
        delay_sec = float(rng.uniform(0.025, 0.06))
        decay = float(rng.uniform(0.18, 0.38))
        delay_samples = max(1, int(delay_sec * sr))
        impulse = np.zeros(delay_samples * 2 + 1, dtype=np.float32)
        impulse[0] = 1.0
        impulse[delay_samples] = decay
        impulse[-1] = decay * float(rng.uniform(0.3, 0.7))
        x = scipy_signal.fftconvolve(x, impulse, mode="full")[: x.size].astype(
            np.float32
        )

    signal_rms = float(np.sqrt(np.mean(np.square(x)))) if x.size else 0.0
    snr_db = float(rng.uniform(16.0, 30.0))
    noise_rms = signal_rms / (10 ** (snr_db / 20.0)) if signal_rms > 1e-6 else 0.01
    noise = rng.normal(0.0, noise_rms, size=x.shape).astype(np.float32)
    hum_freq = float(rng.choice([50.0, 60.0]))
    t = np.arange(x.size, dtype=np.float32) / max(sr, 1)
    hum = (noise_rms * 0.3 * np.sin(2 * np.pi * hum_freq * t)).astype(np.float32)
    x = x + noise + hum

    gain = float(rng.uniform(0.75, 1.2))
    x = x * gain

    if rng.random() < 0.5:
        clip_level = float(rng.uniform(0.65, 0.9))
        x = np.clip(x, -clip_level, clip_level) / clip_level

    lead_pad = int(rng.uniform(0.0, 0.25) * sr)
    tail_pad = int(rng.uniform(0.0, 0.25) * sr)
    if lead_pad > 0 or tail_pad > 0:
        x = np.pad(x, (lead_pad, tail_pad))

    if sr != 50000:
        x = librosa.resample(x, orig_sr=sr, target_sr=50000)
        sr = 50000

    x = _normalize_peak(x)
    return x.astype(np.float32), sr


def _parselmouth_voice_features(signal: np.ndarray, sr: int) -> dict[str, float]:
    parselmouth = require_dependency("parselmouth", "praat-parselmouth")
    sound = parselmouth.Sound(signal, sampling_frequency=sr)
    pitch = sound.to_pitch()
    pulses = parselmouth.praat.call([sound, pitch], "To PointProcess (cc)")

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


def _librosa_mfcc_features(signal: np.ndarray, sr: int, n_mfcc: int = 13) -> dict[str, float]:
    librosa = require_dependency("librosa", "librosa")
    mfcc = librosa.feature.mfcc(y=signal, sr=sr, n_mfcc=n_mfcc)
    mfcc_means = np.mean(mfcc, axis=1)
    return {f"mfcc_{idx + 1}": float(value) for idx, value in enumerate(mfcc_means)}


def _extract_token_features(signal: np.ndarray, sr: int, token: str) -> dict[str, float]:
    voice = _parselmouth_voice_features(signal, sr)
    mfcc = _librosa_mfcc_features(signal, sr, n_mfcc=13)
    return {f"{token}_{name}": value for name, value in {**voice, **mfcc}.items()}


def build_augmented_rows(
    train_records: list[SubjectRecord],
    feature_names: list[str],
    variants_per_subject: int,
    seed: int,
) -> list[dict[str, object]]:
    librosa = require_dependency("librosa", "librosa")

    augmented_rows: list[dict[str, object]] = []
    total = len(train_records)
    for index, record in enumerate(train_records, start=1):
        if index == 1 or index % 25 == 0 or index == total:
            print(f"[INFO] Augmenting train subject {index}/{total} ({record.subject_id})")

        base_signals: dict[str, tuple[np.ndarray, int]] = {}
        for token, path in record.files.items():
            signal, sr = librosa.load(str(path), sr=50000, mono=True)
            base_signals[token] = (signal.astype(np.float32), sr)

        for variant_idx in range(variants_per_subject):
            rng = np.random.default_rng(seed + (int(record.subject_id) * 97) + variant_idx)
            row: dict[str, object] = {
                "subject_id": f"{record.subject_id}__aug{variant_idx + 1}",
                "label": record.label,
            }
            for token in ("a_n", "i_n"):
                signal, sr = base_signals[token]
                aug_signal, aug_sr = _augment_signal(signal, sr, rng)
                row.update(_extract_token_features(aug_signal, aug_sr, token))

            for feature_name in feature_names:
                value = float(row.get(feature_name, np.nan))
                row[feature_name] = value
            augmented_rows.append(row)

    return augmented_rows


def apply_smote(x_train: np.ndarray, y_train: np.ndarray, seed: int) -> tuple[np.ndarray, np.ndarray]:
    imblearn_over_sampling = require_dependency(
        "imblearn.over_sampling",
        "imbalanced-learn",
    )
    minority_count = min(Counter(y_train.tolist()).values())
    k_neighbors = max(1, min(5, minority_count - 1))
    smote = imblearn_over_sampling.SMOTE(random_state=seed, k_neighbors=k_neighbors)
    return smote.fit_resample(x_train, y_train)


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


def write_predictions_csv(
    subjects: np.ndarray,
    y_true: np.ndarray,
    y_pred: np.ndarray,
    probabilities: np.ndarray,
    out_path: Path,
) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["subject_id", "y_true", "prediction", "confidence"],
        )
        writer.writeheader()
        for idx, subject_id in enumerate(subjects):
            writer.writerow(
                {
                    "subject_id": str(subject_id),
                    "y_true": int(y_true[idx]),
                    "prediction": int(y_pred[idx]),
                    "confidence": float(np.max(probabilities[idx])),
                }
            )


def write_feature_csv(
    rows: list[dict[str, object]],
    feature_names: list[str],
    out_path: Path,
) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["subject_id", "label", *feature_names])
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    base_features_csv = args.base_features_csv.expanduser().resolve()
    split_json = args.split_json.expanduser().resolve()
    wav_root = args.wav_root.expanduser().resolve()
    out_dir = args.out_dir.expanduser().resolve()
    backend_target_dir = args.backend_target_dir.expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    backend_target_dir.mkdir(parents=True, exist_ok=True)

    clean_rows, feature_names = load_clean_feature_rows(base_features_csv)
    split_payload = json.loads(split_json.read_text(encoding="utf-8"))
    train_subjects = {str(item) for item in split_payload["train_subjects"]}
    val_subjects = {str(item) for item in split_payload["validation_subjects"]}
    test_subjects = {str(item) for item in split_payload["test_subjects"]}

    x_clean, y_clean, subjects_clean = rows_to_matrix(clean_rows, feature_names)
    train_mask = np.isin(subjects_clean, np.array(sorted(train_subjects), dtype=object))
    val_mask = np.isin(subjects_clean, np.array(sorted(val_subjects), dtype=object))
    test_mask = np.isin(subjects_clean, np.array(sorted(test_subjects), dtype=object))

    if args.max_train_subjects > 0:
        print(f"[INFO] Limiting augmentation to first {args.max_train_subjects} train subjects.")
    train_records = build_train_records(
        wav_root,
        clean_rows,
        train_subjects,
        args.max_train_subjects,
    )
    augmented_rows = build_augmented_rows(
        train_records=train_records,
        feature_names=feature_names,
        variants_per_subject=args.variants_per_subject,
        seed=args.seed,
    )
    write_feature_csv(augmented_rows, feature_names, out_dir / "augmented_train_features.csv")

    x_aug, y_aug, _ = rows_to_matrix(augmented_rows, feature_names)
    x_train_clean = x_clean[train_mask]
    y_train_clean = y_clean[train_mask]
    x_val = x_clean[val_mask]
    y_val = y_clean[val_mask]
    x_test = x_clean[test_mask]
    y_test = y_clean[test_mask]
    val_subject_ids = subjects_clean[val_mask]
    test_subject_ids = subjects_clean[test_mask]

    x_train = np.vstack([x_train_clean, x_aug])
    y_train = np.concatenate([y_train_clean, y_aug], axis=0)
    x_train_balanced, y_train_balanced = apply_smote(x_train, y_train, args.seed)

    sklearn_ensemble = require_dependency("sklearn.ensemble", "scikit-learn")
    model = sklearn_ensemble.RandomForestClassifier(
        n_estimators=args.rf_trees,
        random_state=args.seed,
        class_weight="balanced",
        n_jobs=-1,
    )
    model.fit(x_train_balanced, y_train_balanced)

    val_pred = model.predict(x_val)
    val_proba = model.predict_proba(x_val)
    test_pred = model.predict(x_test)
    test_proba = model.predict_proba(x_test)

    val_metrics = evaluate_predictions(y_val, val_pred)
    test_metrics = evaluate_predictions(y_test, test_pred)

    feature_fill_values = np.mean(x_train, axis=0)
    feature_mean = np.mean(x_train, axis=0)
    feature_std = np.std(x_train, axis=0)
    feature_std = np.where(feature_std < 1e-6, 1.0, feature_std)
    train_abs_z = np.abs((x_train - feature_mean) / feature_std)
    max_abs_zscore = np.max(train_abs_z, axis=1)
    mean_abs_zscore = np.mean(train_abs_z, axis=1)

    model_meta = {
        "artifact_version": "svd_a_n_i_n_v2_phone_aug",
        "model_type": "sklearn_random_forest",
        "model_name": "a_n_i_n_phone_augmented_random_forest",
        "tokens": ["a_n", "i_n"],
        "preprocessing": {
            "target_sample_rate_hz": 50000,
            "trim_top_db": 35,
            "target_analysis_seconds": 2.0,
            "peak_normalization_target": 0.85,
        },
        "decision_policy": {
            "min_confidence_healthy": 0.6,
            "min_confidence_pathologic": 0.75,
            "max_abs_zscore_threshold": float(np.percentile(max_abs_zscore, 99)),
            "mean_abs_zscore_threshold": float(np.percentile(mean_abs_zscore, 99)),
        },
        "classes": {
            "0": "healthy",
            "1": "pathologic",
        },
        "feature_names": feature_names,
        "feature_fill_values": [float(v) for v in feature_fill_values.tolist()],
        "feature_mean": [float(v) for v in feature_mean.tolist()],
        "feature_std": [float(v) for v in feature_std.tolist()],
        "augmentation": {
            "variants_per_subject": args.variants_per_subject,
            "train_subjects_augmented": len(train_records),
            "augmented_rows_count": len(augmented_rows),
            "description": [
                "random_phone_resample",
                "band_limit",
                "gain_shift",
                "white_noise_plus_hum",
                "optional_reverb",
                "optional_clipping",
                "random_lead_tail_silence",
            ],
        },
        "training": {
            "base_features_csv": str(base_features_csv),
            "split_json": str(split_json),
            "clean_train_rows": int(x_train_clean.shape[0]),
            "augmented_train_rows": int(x_aug.shape[0]),
            "combined_train_rows": int(x_train.shape[0]),
            "seed": args.seed,
            "rf_trees": args.rf_trees,
            "smote_train_distribution": {
                str(label): int(count)
                for label, count in sorted(Counter(y_train_balanced.tolist()).items())
            },
        },
        "evaluation": {
            "validation_random_forest": val_metrics,
            "test_random_forest": test_metrics,
        },
    }

    bundle = {
        "model_type": model_meta["model_type"],
        "model_name": model_meta["model_name"],
        "tokens": model_meta["tokens"],
        "classes": model_meta["classes"],
    }

    joblib.dump(model, out_dir / "model.joblib")
    (out_dir / "model_meta.json").write_text(json.dumps(model_meta, indent=2), encoding="utf-8")
    (out_dir / "metrics.json").write_text(
        json.dumps(
            {
                "validation_random_forest": val_metrics,
                "test_random_forest": test_metrics,
                "paths": {
                    "augmented_train_features_csv": portable_repo_path(
                        out_dir / "augmented_train_features.csv"
                    ),
                    "validation_predictions_csv": portable_repo_path(
                        out_dir / "validation_predictions.csv"
                    ),
                    "test_predictions_csv": portable_repo_path(
                        out_dir / "test_predictions.csv"
                    ),
                    "model_meta_json": portable_repo_path(out_dir / "model_meta.json"),
                },
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    (out_dir / "split.json").write_text(json.dumps(split_payload, indent=2), encoding="utf-8")
    (out_dir / "inference_bundle.json").write_text(json.dumps(bundle, indent=2), encoding="utf-8")

    write_predictions_csv(
        subjects=val_subject_ids,
        y_true=y_val,
        y_pred=val_pred,
        probabilities=val_proba,
        out_path=out_dir / "validation_predictions.csv",
    )
    write_predictions_csv(
        subjects=test_subject_ids,
        y_true=y_test,
        y_pred=test_pred,
        probabilities=test_proba,
        out_path=out_dir / "test_predictions.csv",
    )

    for filename in (
        "model.joblib",
        "model_meta.json",
        "metrics.json",
        "split.json",
        "inference_bundle.json",
        "validation_predictions.csv",
        "test_predictions.csv",
    ):
        src = out_dir / filename
        if src.exists():
            shutil.copy2(src, backend_target_dir / filename)

    print(f"[OK] Phone-robust model output: {out_dir}")
    print(f"[OK] Backend artifact export:   {backend_target_dir}")
    print(
        "[INFO] validation/random_forest: "
        f"accuracy={val_metrics['accuracy']:.4f} f1={val_metrics['f1_score']:.4f}"
    )
    print(
        "[INFO] test/random_forest: "
        f"accuracy={test_metrics['accuracy']:.4f} f1={test_metrics['f1_score']:.4f}"
    )


if __name__ == "__main__":
    main()
