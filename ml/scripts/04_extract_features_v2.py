#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, correlate, filtfilt, find_peaks


FEATURE_COLUMNS_ALL = [
    "duration_sec",
    "rms",
    "zcr",
    "hnr_db",
    "f0_hz",
    "jitter_local",
    "shimmer_local",
    "spec_centroid_hz",
    "spec_rolloff_hz",
    "spec_bandwidth_hz",
    "voiced_ratio",
    "frame_rms_mean",
    "frame_rms_std",
    "frame_rms_p10",
    "frame_rms_p90",
    "frame_zcr_mean",
    "frame_zcr_std",
    "frame_f0_mean",
    "frame_f0_std",
    "frame_f0_p10",
    "frame_f0_p90",
    "frame_hnr_mean",
    "frame_hnr_std",
    "frame_hnr_p10",
    "frame_hnr_p90",
    "frame_flatness_mean",
    "frame_flatness_std",
    "frame_entropy_mean",
    "frame_entropy_std",
    "frame_slope_mean",
    "frame_slope_std",
    "frame_flux_mean",
    "frame_flux_std",
    "band_low_ratio_mean",
    "band_mid_ratio_mean",
    "band_high_ratio_mean",
]

FEATURE_COLUMNS_TOP6 = [
    "f0_hz",
    "shimmer_local",
    "frame_flatness_std",
    "frame_entropy_mean",
    "frame_entropy_std",
    "band_mid_ratio_mean",
]

FEATURE_PROFILE_MAP = {
    "all": FEATURE_COLUMNS_ALL,
    "top6": FEATURE_COLUMNS_TOP6,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Extract v2 acoustic features (global + frame-level/voiced statistics) "
            "from WAV files for model training."
        )
    )
    parser.add_argument(
        "--metadata-csv",
        type=Path,
        default=Path("ml/reports/metadata/training_metadata_vowels.csv"),
        help="Metadata table with wav_path rows.",
    )
    parser.add_argument(
        "--out-csv",
        type=Path,
        default=Path("ml/reports/features/features_v2.csv"),
        help="Output feature table path.",
    )
    parser.add_argument(
        "--token-filter",
        default="",
        help='Comma list, e.g. "a_n,a_h". Empty means all tokens.',
    )
    parser.add_argument(
        "--drop-quality-excluded",
        action="store_true",
        help="Skip rows where quality_exclude=True in metadata.",
    )
    parser.add_argument(
        "--max-rows",
        type=int,
        default=0,
        help="Optional debug limit (0 = all).",
    )
    parser.add_argument(
        "--feature-profile",
        choices=tuple(FEATURE_PROFILE_MAP.keys()),
        default="top6",
        help=(
            "Which v2 feature profile to write. "
            "'top6' is the tuned compact set; 'all' writes the full set."
        ),
    )
    return parser.parse_args()


def load_wav_mono(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as wf:
        n_channels = wf.getnchannels()
        sample_width = wf.getsampwidth()
        sample_rate = wf.getframerate()
        n_frames = wf.getnframes()
        frames = wf.readframes(n_frames)

    if sample_width != 2:
        raise ValueError(f"unsupported_sample_width:{sample_width}")
    if n_channels != 1:
        raise ValueError(f"unsupported_channel_count:{n_channels}")

    x = np.frombuffer(frames, dtype="<i2").astype(np.float32)
    if x.size == 0:
        raise ValueError("empty_audio")
    x /= 32768.0
    return x, sample_rate


def trim_silence(signal: np.ndarray, threshold_db: float = -45.0) -> np.ndarray:
    eps = 1e-9
    mag = np.abs(signal)
    db = 20 * np.log10(mag + eps)
    mask = db > threshold_db
    if not np.any(mask):
        return signal
    idx = np.where(mask)[0]
    return signal[idx[0] : idx[-1] + 1]


def crop_for_analysis(signal: np.ndarray, sr: int, max_seconds: float = 5.0) -> np.ndarray:
    max_samples = int(sr * max_seconds)
    if signal.size <= max_samples:
        return signal
    start = (signal.size - max_samples) // 2
    end = start + max_samples
    return signal[start:end]


def bandpass_voice(signal: np.ndarray, sr: int, f_lo: float = 60, f_hi: float = 1200) -> np.ndarray:
    nyq = sr / 2.0
    lo = max(1e-3, f_lo / nyq)
    hi = min(0.999, f_hi / nyq)
    if lo >= hi:
        return signal
    b, a = butter(4, [lo, hi], btype="band")
    return filtfilt(b, a, signal)


def estimate_cycle_features(signal: np.ndarray, sr: int) -> dict[str, float]:
    min_f0 = 70.0
    max_f0 = 450.0
    min_dist = int(sr / max_f0)
    max_dist = int(sr / min_f0)
    if min_dist < 1:
        min_dist = 1

    peaks, _ = find_peaks(signal, distance=min_dist, prominence=0.01)
    if peaks.size < 4:
        return {"f0_hz": np.nan, "jitter_local": np.nan, "shimmer_local": np.nan}

    periods = np.diff(peaks).astype(np.float64)
    valid = (periods >= min_dist) & (periods <= max_dist)
    periods = periods[valid]
    if periods.size < 3:
        return {"f0_hz": np.nan, "jitter_local": np.nan, "shimmer_local": np.nan}

    amps = np.abs(signal[peaks[:-1]])[valid]
    if amps.size < 3:
        amps = np.abs(signal[peaks[: periods.size]])

    mean_period = float(np.mean(periods))
    f0 = float(sr / mean_period) if mean_period > 0 else np.nan

    if periods.size > 1 and mean_period > 0:
        jitter = float(np.mean(np.abs(np.diff(periods))) / mean_period)
    else:
        jitter = np.nan

    mean_amp = float(np.mean(amps)) if amps.size > 0 else np.nan
    if amps.size > 1 and mean_amp > 1e-9:
        shimmer = float(np.mean(np.abs(np.diff(amps))) / mean_amp)
    else:
        shimmer = np.nan

    return {"f0_hz": f0, "jitter_local": jitter, "shimmer_local": shimmer}


def estimate_hnr(signal: np.ndarray, sr: int) -> float:
    min_f0 = 70.0
    max_f0 = 450.0
    min_lag = max(1, int(sr / max_f0))
    max_lag = max(min_lag + 1, int(sr / min_f0))

    x = signal - np.mean(signal)
    if np.allclose(x, 0):
        return np.nan

    acf = correlate(x, x, mode="full", method="fft")
    acf = acf[len(acf) // 2 :]
    if acf.size <= max_lag:
        return np.nan

    r0 = float(acf[0])
    if r0 <= 0:
        return np.nan

    r_peak = float(np.max(acf[min_lag:max_lag]))
    if r_peak <= 0 or r_peak >= r0:
        return np.nan

    noise = r0 - r_peak
    if noise <= 1e-9:
        return np.nan
    return float(10.0 * np.log10(r_peak / noise))


def spectral_features(signal: np.ndarray, sr: int) -> dict[str, float]:
    x = signal.astype(np.float64)
    n = x.size
    if n < 4:
        return {
            "spec_centroid_hz": np.nan,
            "spec_rolloff_hz": np.nan,
            "spec_bandwidth_hz": np.nan,
        }

    window = np.hanning(n)
    mag = np.abs(np.fft.rfft(x * window))
    freqs = np.fft.rfftfreq(n, 1.0 / sr)
    total = float(np.sum(mag))
    if total <= 1e-12:
        return {
            "spec_centroid_hz": np.nan,
            "spec_rolloff_hz": np.nan,
            "spec_bandwidth_hz": np.nan,
        }

    centroid = float(np.sum(freqs * mag) / total)
    cum = np.cumsum(mag)
    rolloff_idx = int(np.searchsorted(cum, 0.85 * cum[-1], side="left"))
    rolloff = float(freqs[min(rolloff_idx, freqs.size - 1)])
    bandwidth = float(np.sqrt(np.sum(((freqs - centroid) ** 2) * mag) / total))

    return {
        "spec_centroid_hz": centroid,
        "spec_rolloff_hz": rolloff,
        "spec_bandwidth_hz": bandwidth,
    }


def frame_signal(signal: np.ndarray, frame_len: int, hop_len: int) -> np.ndarray:
    if frame_len <= 0 or hop_len <= 0:
        raise ValueError("invalid_frame_params")

    x = signal.astype(np.float64)
    if x.size < frame_len:
        x = np.pad(x, (0, frame_len - x.size), mode="constant")

    starts = np.arange(0, x.size - frame_len + 1, hop_len)
    if starts.size == 0:
        starts = np.array([0])
    frames = np.stack([x[start : start + frame_len] for start in starts], axis=0)
    return frames


def finite_stats(values: np.ndarray, prefix: str) -> dict[str, float]:
    finite = values[np.isfinite(values)]
    if finite.size == 0:
        return {
            f"{prefix}_mean": np.nan,
            f"{prefix}_std": np.nan,
            f"{prefix}_p10": np.nan,
            f"{prefix}_p90": np.nan,
        }
    return {
        f"{prefix}_mean": float(np.mean(finite)),
        f"{prefix}_std": float(np.std(finite)),
        f"{prefix}_p10": float(np.percentile(finite, 10)),
        f"{prefix}_p90": float(np.percentile(finite, 90)),
    }


def safe_mean(values: np.ndarray) -> float:
    finite = values[np.isfinite(values)]
    if finite.size == 0:
        return np.nan
    return float(np.mean(finite))


def safe_std(values: np.ndarray) -> float:
    finite = values[np.isfinite(values)]
    if finite.size == 0:
        return np.nan
    return float(np.std(finite))


def estimate_frame_f0_hnr(frame_bp: np.ndarray, sr: int) -> tuple[float, float]:
    min_f0 = 70.0
    max_f0 = 450.0
    min_lag = max(1, int(sr / max_f0))
    max_lag = max(min_lag + 1, int(sr / min_f0))

    x = frame_bp - np.mean(frame_bp)
    if np.allclose(x, 0):
        return np.nan, np.nan

    acf = correlate(x, x, mode="full", method="fft")
    acf = acf[len(acf) // 2 :]
    if acf.size <= max_lag:
        return np.nan, np.nan

    r0 = float(acf[0])
    if r0 <= 0:
        return np.nan, np.nan

    seg = acf[min_lag:max_lag]
    if seg.size == 0:
        return np.nan, np.nan
    rel_idx = int(np.argmax(seg))
    lag = min_lag + rel_idx
    r_peak = float(seg[rel_idx])
    periodicity = r_peak / (r0 + 1e-12)
    if periodicity < 0.2:
        return np.nan, np.nan

    f0 = float(sr / lag) if lag > 0 else np.nan
    noise = r0 - r_peak
    if noise <= 1e-9 or r_peak <= 0:
        hnr = np.nan
    else:
        hnr = float(10.0 * np.log10(r_peak / noise))
    return f0, hnr


def frame_spectral_values(
    frame_raw: np.ndarray, sr: int, previous_mag: np.ndarray | None
) -> tuple[float, float, float, float, float, float, float, np.ndarray]:
    eps = 1e-12
    n = frame_raw.size
    if n < 8:
        return np.nan, np.nan, np.nan, np.nan, np.nan, np.nan, np.nan, np.array([])

    window = np.hanning(n)
    mag = np.abs(np.fft.rfft(frame_raw * window)).astype(np.float64)
    freqs = np.fft.rfftfreq(n, d=1.0 / sr)
    total = float(np.sum(mag))
    if total <= eps:
        return np.nan, np.nan, np.nan, np.nan, np.nan, np.nan, np.nan, mag

    # Spectral flatness.
    flatness = float(np.exp(np.mean(np.log(mag + eps))) / (np.mean(mag + eps)))

    # Normalized spectral entropy in [0,1].
    prob = mag / total
    entropy = float(-np.sum(prob * np.log(prob + eps)) / np.log(prob.size + eps))

    # Spectral slope on log magnitude.
    if freqs.size >= 3:
        slope = float(np.polyfit(freqs, np.log(mag + eps), deg=1)[0])
    else:
        slope = np.nan

    low = float(np.sum(mag[freqs <= 500.0]) / total)
    mid = float(np.sum(mag[(freqs > 500.0) & (freqs <= 2000.0)]) / total)
    high = float(np.sum(mag[freqs > 2000.0]) / total)

    flux = np.nan
    if previous_mag is not None and previous_mag.size == mag.size:
        a = previous_mag / (np.linalg.norm(previous_mag) + eps)
        b = mag / (np.linalg.norm(mag) + eps)
        flux = float(np.sqrt(np.sum((b - a) ** 2)))

    return flatness, entropy, slope, low, mid, high, flux, mag


def v2_features(signal: np.ndarray, sr: int) -> dict[str, float]:
    analysis_signal = crop_for_analysis(signal, sr, max_seconds=5.0)
    bp_signal = bandpass_voice(analysis_signal, sr)

    duration = analysis_signal.size / sr
    rms = float(np.sqrt(np.mean(analysis_signal**2)))
    zcr = float(np.mean(np.abs(np.diff(np.signbit(analysis_signal)))))

    cycle = estimate_cycle_features(bp_signal, sr)
    hnr_global = estimate_hnr(bp_signal, sr)
    spec_global = spectral_features(analysis_signal, sr)

    frame_len = max(256, int(sr * 0.04))
    hop_len = max(128, int(sr * 0.01))
    raw_frames = frame_signal(analysis_signal, frame_len=frame_len, hop_len=hop_len)
    bp_frames = frame_signal(bp_signal, frame_len=frame_len, hop_len=hop_len)

    frame_rms = np.sqrt(np.mean(raw_frames**2, axis=1))
    frame_zcr = np.mean(np.abs(np.diff(np.signbit(raw_frames), axis=1)), axis=1)

    rms_threshold = max(1e-4, float(np.percentile(frame_rms, 30) * 0.8))
    voiced_mask = frame_rms > rms_threshold
    if not np.any(voiced_mask):
        voiced_mask = frame_rms >= float(np.median(frame_rms))
    voiced_ratio = float(np.mean(voiced_mask)) if voiced_mask.size > 0 else np.nan

    f0_vals: list[float] = []
    hnr_vals: list[float] = []
    flatness_vals: list[float] = []
    entropy_vals: list[float] = []
    slope_vals: list[float] = []
    flux_vals: list[float] = []
    band_low_vals: list[float] = []
    band_mid_vals: list[float] = []
    band_high_vals: list[float] = []

    previous_mag: np.ndarray | None = None
    for i in range(raw_frames.shape[0]):
        if not voiced_mask[i]:
            continue

        f0, hnr = estimate_frame_f0_hnr(bp_frames[i], sr)
        f0_vals.append(f0)
        hnr_vals.append(hnr)

        flatness, entropy, slope, low, mid, high, flux, mag = frame_spectral_values(
            raw_frames[i], sr, previous_mag=previous_mag
        )
        flatness_vals.append(flatness)
        entropy_vals.append(entropy)
        slope_vals.append(slope)
        band_low_vals.append(low)
        band_mid_vals.append(mid)
        band_high_vals.append(high)
        if np.isfinite(flux):
            flux_vals.append(flux)
        previous_mag = mag

    f0_arr = np.array(f0_vals, dtype=np.float64)
    hnr_arr = np.array(hnr_vals, dtype=np.float64)
    flatness_arr = np.array(flatness_vals, dtype=np.float64)
    entropy_arr = np.array(entropy_vals, dtype=np.float64)
    slope_arr = np.array(slope_vals, dtype=np.float64)
    flux_arr = np.array(flux_vals, dtype=np.float64)
    band_low_arr = np.array(band_low_vals, dtype=np.float64)
    band_mid_arr = np.array(band_mid_vals, dtype=np.float64)
    band_high_arr = np.array(band_high_vals, dtype=np.float64)

    out = {
        "duration_sec": float(duration),
        "rms": rms,
        "zcr": zcr,
        "hnr_db": hnr_global,
        "f0_hz": cycle["f0_hz"],
        "jitter_local": cycle["jitter_local"],
        "shimmer_local": cycle["shimmer_local"],
        "spec_centroid_hz": spec_global["spec_centroid_hz"],
        "spec_rolloff_hz": spec_global["spec_rolloff_hz"],
        "spec_bandwidth_hz": spec_global["spec_bandwidth_hz"],
        "voiced_ratio": voiced_ratio,
        "frame_rms_mean": float(np.mean(frame_rms)),
        "frame_rms_std": float(np.std(frame_rms)),
        "frame_rms_p10": float(np.percentile(frame_rms, 10)),
        "frame_rms_p90": float(np.percentile(frame_rms, 90)),
        "frame_zcr_mean": float(np.mean(frame_zcr)),
        "frame_zcr_std": float(np.std(frame_zcr)),
        **finite_stats(f0_arr, prefix="frame_f0"),
        **finite_stats(hnr_arr, prefix="frame_hnr"),
        "frame_flatness_mean": safe_mean(flatness_arr),
        "frame_flatness_std": safe_std(flatness_arr),
        "frame_entropy_mean": safe_mean(entropy_arr),
        "frame_entropy_std": safe_std(entropy_arr),
        "frame_slope_mean": safe_mean(slope_arr),
        "frame_slope_std": safe_std(slope_arr),
        "frame_flux_mean": safe_mean(flux_arr),
        "frame_flux_std": safe_std(flux_arr),
        "band_low_ratio_mean": safe_mean(band_low_arr),
        "band_mid_ratio_mean": safe_mean(band_mid_arr),
        "band_high_ratio_mean": safe_mean(band_high_arr),
    }
    return out


def main() -> None:
    args = parse_args()
    out_csv = args.out_csv.expanduser().resolve()
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    selected_features = FEATURE_PROFILE_MAP[args.feature_profile]
    token_filter = {token.strip() for token in args.token_filter.split(",") if token.strip()}

    with args.metadata_csv.expanduser().resolve().open("r", encoding="utf-8", newline="") as in_f:
        rows = list(csv.DictReader(in_f))

    if args.max_rows > 0:
        rows = rows[: args.max_rows]

    written = 0
    failed = 0

    with out_csv.open("w", encoding="utf-8", newline="") as out_f:
        fieldnames = [
            "subject_id",
            "label",
            "modality",
            "token",
            "wav_path",
            "remarks_flags",
            "quality_exclude",
            "error",
            *selected_features,
        ]
        writer = csv.DictWriter(out_f, fieldnames=fieldnames)
        writer.writeheader()

        for idx, row in enumerate(rows, start=1):
            token = row["token"]
            if token_filter and token not in token_filter:
                continue
            if args.drop_quality_excluded and row.get("quality_exclude") == "True":
                continue

            wav_path = Path(row["wav_path"])
            out_row = {
                "subject_id": row["subject_id"],
                "label": row.get("label", ""),
                "modality": row["modality"],
                "token": token,
                "wav_path": str(wav_path),
                "remarks_flags": row.get("remarks_flags", ""),
                "quality_exclude": row.get("quality_exclude", ""),
            }

            try:
                sig, sr = load_wav_mono(wav_path)
                sig = trim_silence(sig)
                feats = v2_features(sig, sr)
                for col in selected_features:
                    out_row[col] = feats.get(col, np.nan)
                out_row["error"] = ""
            except Exception as exc:
                failed += 1
                out_row["error"] = str(exc)
                for col in selected_features:
                    out_row[col] = ""

            writer.writerow(out_row)
            written += 1
            if idx % 1000 == 0:
                print(f"[INFO] Processed {idx}/{len(rows)} metadata rows...")

    print(f"[OK] Features CSV: {out_csv}")
    print(f"[INFO] Feature profile: {args.feature_profile} ({len(selected_features)} columns)")
    print(f"[INFO] Rows written: {written}")
    print(f"[INFO] Failed rows: {failed}")


if __name__ == "__main__":
    main()
