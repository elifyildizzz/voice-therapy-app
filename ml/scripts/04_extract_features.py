#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import math
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, correlate, filtfilt, find_peaks


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract acoustic features from WAV files for model training."
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
        default=Path("ml/reports/features/features_v1.csv"),
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
    # Peak-based cycle estimation for sustained vowels.
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
    # Autocorrelation-based HNR approximation.
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


def base_features(signal: np.ndarray, sr: int) -> dict[str, float]:
    duration = signal.size / sr
    rms = float(np.sqrt(np.mean(signal**2)))
    zcr = float(np.mean(np.abs(np.diff(np.signbit(signal)))))

    analysis_signal = crop_for_analysis(signal, sr, max_seconds=5.0)
    bp = bandpass_voice(analysis_signal, sr)
    cycle = estimate_cycle_features(bp, sr)
    hnr = estimate_hnr(bp, sr)
    spec = spectral_features(analysis_signal, sr)

    return {
        "duration_sec": float(duration),
        "rms": rms,
        "zcr": zcr,
        "hnr_db": hnr,
        **cycle,
        **spec,
    }


def main() -> None:
    args = parse_args()
    out_csv = args.out_csv.expanduser().resolve()
    out_csv.parent.mkdir(parents=True, exist_ok=True)
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
                feats = base_features(sig, sr)
                out_row.update(feats)
                out_row["error"] = ""
            except Exception as exc:
                failed += 1
                out_row.update(
                    {
                        "error": str(exc),
                        "duration_sec": "",
                        "rms": "",
                        "zcr": "",
                        "hnr_db": "",
                        "f0_hz": "",
                        "jitter_local": "",
                        "shimmer_local": "",
                        "spec_centroid_hz": "",
                        "spec_rolloff_hz": "",
                        "spec_bandwidth_hz": "",
                    }
                )

            writer.writerow(out_row)
            written += 1
            if idx % 2000 == 0:
                print(f"[INFO] Processed {idx}/{len(rows)} metadata rows...")

    print(f"[OK] Features CSV: {out_csv}")
    print(f"[INFO] Rows written: {written}")
    print(f"[INFO] Failed rows: {failed}")


if __name__ == "__main__":
    main()
