from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import joblib
import librosa
import numpy as np
import parselmouth


ARTIFACT_DIR = (
    Path(__file__).resolve().parent / "model_artifacts" / "svd_a_n_i_n_v2_phone_aug_lite"
)
MIN_DURATION_SEC = 1.0
MIN_RMS = 0.003
MIN_PEAK = 0.015
MIN_ACTIVE_RATIO = 0.1


@dataclass(frozen=True)
class VoiceScreeningResult:
    label: str
    confidence: float
    title: str
    summary: str
    recommendation: str

    def to_dict(self) -> dict[str, object]:
        return {
            "label": label_to_api_value(self.label),
            "confidence": round(self.confidence, 4),
            "confidence_percent": round(self.confidence * 100, 1),
            "title": self.title,
            "summary": self.summary,
            "recommendation": self.recommendation,
        }


class AudioQualityError(ValueError):
    pass


def label_to_api_value(label: str) -> str:
    if label == "healthy":
        return "healthy"
    if label == "inconclusive":
        return "retake_required"
    return "pathology_risk"


@lru_cache(maxsize=1)
def load_artifact() -> tuple[object, dict[str, object]]:
    model_path = ARTIFACT_DIR / "model.joblib"
    meta_path = ARTIFACT_DIR / "model_meta.json"

    if not model_path.exists() or not meta_path.exists():
        raise FileNotFoundError(
            "Voice screening model artifacts are missing. "
            "Run ml/scripts/13_export_svd_a_n_i_n_inference_model.py first."
        )

    model = joblib.load(model_path)
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    return model, meta


def _parselmouth_voice_features(signal: np.ndarray, sr: int) -> dict[str, float]:
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
    if signal.size == 0:
        raise ValueError("empty_audio")

    mfcc = librosa.feature.mfcc(y=signal, sr=sr, n_mfcc=n_mfcc)
    mfcc_means = np.mean(mfcc, axis=1)
    return {f"mfcc_{idx + 1}": float(value) for idx, value in enumerate(mfcc_means)}


def _validate_audio_quality(path: Path, token_label: str) -> None:
    y, sr = librosa.load(str(path), sr=None, mono=True)
    if y.size == 0 or sr <= 0:
        raise AudioQualityError(
            f"{token_label} kaydında yeterli ses algılanamadı. Lütfen normal tonda tekrar kayıt alın."
        )

    duration_sec = float(y.size / sr)
    rms_total = float(np.sqrt(np.mean(np.square(y))))
    peak_abs = float(np.max(np.abs(y)))

    frame_rms = librosa.feature.rms(y=y, frame_length=2048, hop_length=512)[0]
    max_frame_rms = float(frame_rms.max()) if frame_rms.size else 0.0
    active_threshold = max(max_frame_rms * 0.2, 0.003)
    active_ratio = float(np.mean(frame_rms >= active_threshold)) if frame_rms.size else 0.0

    if (
        duration_sec < MIN_DURATION_SEC
        or rms_total < MIN_RMS
        or peak_abs < MIN_PEAK
        or active_ratio < MIN_ACTIVE_RATIO
    ):
        raise AudioQualityError(
            f"{token_label} kaydında yeterli ses algılanamadı. "
            "Lütfen mikrofonu açık tutup sesi normal konuşma tonunda tekrar kaydedin."
        )


def _preprocess_audio_for_inference(path: Path) -> tuple[np.ndarray, int]:
    _, meta = load_artifact()
    preprocessing = meta.get("preprocessing", {})
    target_sr = int(preprocessing.get("target_sample_rate_hz", 50000))
    trim_top_db = float(preprocessing.get("trim_top_db", 35))
    target_seconds = float(preprocessing.get("target_analysis_seconds", 2.0))
    target_peak = float(preprocessing.get("peak_normalization_target", 0.85))

    signal, sr = librosa.load(str(path), sr=None, mono=True)
    if signal.size == 0:
        raise AudioQualityError(
            "Kayıtta yeterli ses algılanamadı. Lütfen tekrar kayıt alın."
        )

    trimmed, _ = librosa.effects.trim(signal, top_db=trim_top_db)
    if trimmed.size > 0:
        signal = trimmed

    if sr != target_sr:
        signal = librosa.resample(signal, orig_sr=sr, target_sr=target_sr)
        sr = target_sr

    peak = float(np.max(np.abs(signal))) if signal.size else 0.0
    if peak > 1e-6:
        signal = signal * (target_peak / peak)

    max_samples = max(1, int(target_seconds * sr))
    if signal.size > max_samples:
        start = (signal.size - max_samples) // 2
        signal = signal[start : start + max_samples]

    return signal.astype(np.float32), sr


def _extract_token_features(signal: np.ndarray, sr: int, token: str) -> dict[str, float]:
    voice = _parselmouth_voice_features(signal, sr)
    mfcc = _librosa_mfcc_features(signal, sr, n_mfcc=13)
    return {f"{token}_{name}": value for name, value in {**voice, **mfcc}.items()}


def _build_feature_vector(a_path: Path, i_path: Path) -> tuple[np.ndarray, dict[str, float]]:
    _, meta = load_artifact()
    feature_names = [str(name) for name in meta["feature_names"]]
    fill_values = [float(value) for value in meta["feature_fill_values"]]

    _validate_audio_quality(a_path, "A")
    _validate_audio_quality(i_path, "İ")

    a_signal, a_sr = _preprocess_audio_for_inference(a_path)
    i_signal, i_sr = _preprocess_audio_for_inference(i_path)

    feature_map: dict[str, float] = {}
    feature_map.update(_extract_token_features(a_signal, a_sr, "a_n"))
    feature_map.update(_extract_token_features(i_signal, i_sr, "i_n"))

    values: list[float] = []
    for index, feature_name in enumerate(feature_names):
        value = feature_map.get(feature_name, fill_values[index])
        if not np.isfinite(value):
            value = fill_values[index]
        values.append(float(value))

    vector = np.array(values, dtype=np.float64).reshape(1, -1)

    feature_mean = np.array(meta.get("feature_mean", fill_values), dtype=np.float64)
    feature_std = np.array(meta.get("feature_std", np.ones_like(feature_mean)), dtype=np.float64)
    feature_std = np.where(feature_std < 1e-6, 1.0, feature_std)
    abs_z = np.abs((vector[0] - feature_mean) / feature_std)
    diagnostics = {
        "max_abs_zscore": float(np.max(abs_z)),
        "mean_abs_zscore": float(np.mean(abs_z)),
    }

    return vector, diagnostics


def _build_result(label: str, confidence: float) -> VoiceScreeningResult:
    if label == "inconclusive":
        return VoiceScreeningResult(
            label="inconclusive",
            confidence=confidence,
            title="Ön tarama sonucu oluşturulamadı",
            summary=(
                "Kayıt koşulları eğitim verisine yeterince yakın bulunmadı. "
                "Bu nedenle güvenilir bir ön tarama sonucu üretilemedi."
            ),
            recommendation=(
                "Lütfen sessiz bir ortamda, telefonu sabit tutarak ve sesi normal "
                "konuşma tonunda yeniden kaydedin. Sorun sürerse bir Kulak Burun "
                "Boğaz uzmanına başvurmanız önerilir."
            ),
        )

    if label == "healthy":
        return VoiceScreeningResult(
            label="healthy",
            confidence=confidence,
            title="Ön tarama sonucu: sağlıklı örüntüye daha yakın",
            summary=(
                "Paylaştığınız 'a' ve 'i' ses kayıtları, model tarafından "
                "sağlıklı ses örüntülerine daha yakın değerlendirilmiştir."
            ),
            recommendation=(
                "Bu sonuç tıbbi tanı yerine geçmez. Ses kısıklığı, ağrı, çabuk "
                "yorulma veya benzeri yakınmalarınız sürüyorsa bir Kulak Burun "
                "Boğaz uzmanına başvurmanız önerilir."
            ),
        )

    return VoiceScreeningResult(
        label="pathologic",
        confidence=confidence,
        title="Ön tarama sonucu: ses patolojisi olasılığı değerlendirildi",
        summary=(
            "Paylaştığınız 'a' ve 'i' ses kayıtları, model tarafından ses "
            "patolojisi ile ilişkili olabilecek örüntülere daha yakın "
            "değerlendirilmiştir."
        ),
        recommendation=(
            "Kesin tanı ve ayrıntılı değerlendirme için bir Kulak Burun Boğaz "
            "uzmanına başvurmanız önerilir."
        ),
    )


def analyze_voice_pair(a_path: Path, i_path: Path) -> dict[str, object]:
    model, meta = load_artifact()
    feature_vector, diagnostics = _build_feature_vector(a_path, i_path)
    predicted_index = int(model.predict(feature_vector)[0])

    confidence = 0.5
    if hasattr(model, "predict_proba"):
        probabilities = model.predict_proba(feature_vector)[0]
        confidence = float(np.max(probabilities))

    label_map = {int(key): value for key, value in meta["classes"].items()}
    label = label_map.get(predicted_index, "pathologic")
    decision_policy = meta.get("decision_policy", {})
    min_confidence_healthy = float(
        decision_policy.get("min_confidence_healthy", 0.6)
    )
    min_confidence_pathologic = float(
        decision_policy.get("min_confidence_pathologic", 0.75)
    )
    max_abs_z_limit = float(decision_policy.get("max_abs_zscore_threshold", 6.0))
    mean_abs_z_limit = float(decision_policy.get("mean_abs_zscore_threshold", 1.5))
    min_confidence = (
        min_confidence_healthy if label == "healthy" else min_confidence_pathologic
    )

    if (
        confidence < min_confidence
        or diagnostics["max_abs_zscore"] > max_abs_z_limit
        or diagnostics["mean_abs_zscore"] > mean_abs_z_limit
    ):
        label = "inconclusive"

    result = _build_result(label, confidence)

    return {
        "success": True,
        "screening": result.to_dict(),
        "model": {
            "name": meta.get("model_name", "a_n_i_n_screening"),
            "artifact_version": meta.get("artifact_version", "unknown"),
            "tokens": meta.get("tokens", ["a_n", "i_n"]),
        },
        "quality": diagnostics,
    }
