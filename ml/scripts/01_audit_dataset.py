#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import os
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


SUPPORTED_AUDIO_EXTENSIONS = {".nsp", ".egg"}
REMARK_KEYWORDS = {
    "noisy_signal": ("rauscht", "verrauscht", "geräusch", "geräusch", "kriselig"),
    "signal_crackle": ("knistert", "knistern"),
    "unusable_signal": ("nicht brauchbar", "unbrauchbar"),
    "relabel_note": ("gelabelt",),
    "short_segment": ("kürzer", "kuerzer", "zu kurz"),
}


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


def parse_args() -> argparse.Namespace:
    load_env_file()

    parser = argparse.ArgumentParser(
        description="Audit DS16/IFF voice dataset before conversion and training."
    )
    parser.add_argument(
        "--data-root",
        type=Path,
        default=env_path_or_default(
            "BITIRME_DATA_ROOT",
            Path.home() / "Desktop" / "bitirme" / "data",
        ),
        help=(
            "Path to dataset root (contains numeric subject folders). "
            "Default: $BITIRME_DATA_ROOT or ~/Desktop/bitirme/data"
        ),
    )
    parser.add_argument(
        "--out-dir",
        default=Path("ml/reports/audit"),
        type=Path,
        help="Output directory for CSV/JSON reports.",
    )
    return parser.parse_args()


def parse_ds16_header(path: Path) -> dict[str, object]:
    result: dict[str, object] = {
        "sample_rate_hz": "",
        "sample_count": "",
        "duration_sec": "",
        "chunk_id": "",
        "chunk_length": "",
        "payload_match": "",
        "parse_error": "",
    }

    try:
        header = path.read_bytes()[:0x3C]
    except Exception as exc:  # pragma: no cover - filesystem errors
        result["parse_error"] = f"read_error:{exc}"
        return result

    if len(header) < 0x3C:
        result["parse_error"] = "header_too_short"
        return result

    if header[0:4] != b"FORM" or header[4:8] != b"DS16":
        result["parse_error"] = "not_form_ds16"
        return result

    sample_rate_hz = int.from_bytes(header[0x28:0x2C], "little", signed=False)
    sample_count = int.from_bytes(header[0x2C:0x30], "little", signed=False)
    chunk_id = header[0x34:0x38].decode("latin1", errors="replace")
    chunk_length = int.from_bytes(header[0x38:0x3C], "little", signed=False)

    if sample_rate_hz <= 0 or sample_rate_hz > 500_000:
        result["parse_error"] = "invalid_sample_rate"
        return result

    duration_sec = sample_count / sample_rate_hz
    expected_payload = sample_count * 2  # 16-bit mono samples.
    payload_match = chunk_length == expected_payload

    result.update(
        {
            "sample_rate_hz": sample_rate_hz,
            "sample_count": sample_count,
            "duration_sec": f"{duration_sec:.6f}",
            "chunk_id": chunk_id,
            "chunk_length": chunk_length,
            "payload_match": payload_match,
        }
    )
    return result


def extract_token(subject_id: str, stem: str) -> str:
    subject_prefix = f"{subject_id}-"
    token = stem[len(subject_prefix) :] if stem.startswith(subject_prefix) else stem
    if token.endswith("-egg"):
        token = token[:-4]
    return token


def parse_remarks_flags(remarks_path: Path | None) -> tuple[str, str]:
    if remarks_path is None:
        return "", ""

    try:
        text = remarks_path.read_text(errors="ignore").lower()
    except Exception:
        return "", ""

    flags: list[str] = []
    for flag, keywords in REMARK_KEYWORDS.items():
        if any(keyword in text for keyword in keywords):
            flags.append(flag)
    return ";".join(flags), text[:500].replace("\n", " | ")


def main() -> None:
    args = parse_args()
    data_root: Path = args.data_root.expanduser().resolve()
    out_dir: Path = args.out_dir.expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    subject_dirs = sorted(
        [path for path in data_root.iterdir() if path.is_dir() and path.name.isdigit()],
        key=lambda path: int(path.name),
    )

    file_report_path = out_dir / "file_audit.csv"
    subject_report_path = out_dir / "subject_audit.csv"
    summary_path = out_dir / "summary.json"

    ext_counter: Counter[str] = Counter()
    modality_counter: Counter[str] = Counter()
    parse_error_count = 0
    token_counters = {"vowels": Counter(), "sentences": Counter()}

    with file_report_path.open("w", newline="", encoding="utf-8") as file_csv:
        file_writer = csv.DictWriter(
            file_csv,
            fieldnames=[
                "subject_id",
                "modality",
                "ext",
                "token",
                "path",
                "file_size_bytes",
                "sample_rate_hz",
                "sample_count",
                "duration_sec",
                "chunk_id",
                "chunk_length",
                "payload_match",
                "parse_error",
            ],
        )
        file_writer.writeheader()

        subject_rows: list[dict[str, object]] = []

        for subject_dir in subject_dirs:
            subject_id = subject_dir.name

            vowel_nsp_tokens: set[str] = set()
            vowel_egg_tokens: set[str] = set()
            sentence_nsp_tokens: set[str] = set()
            sentence_egg_tokens: set[str] = set()

            counts = {
                "vowel_nsp_count": 0,
                "vowel_egg_count": 0,
                "sentence_nsp_count": 0,
                "sentence_egg_count": 0,
            }

            for modality in ("vowels", "sentences"):
                modality_dir = subject_dir / modality
                if not modality_dir.exists():
                    continue

                for file_path in sorted(modality_dir.iterdir()):
                    if not file_path.is_file():
                        continue
                    ext = file_path.suffix.lower()
                    if ext not in SUPPORTED_AUDIO_EXTENSIONS:
                        continue

                    token = extract_token(subject_id, file_path.stem)
                    header_info = parse_ds16_header(file_path)
                    if header_info["parse_error"]:
                        parse_error_count += 1

                    ext_counter[ext] += 1
                    modality_counter[modality] += 1
                    token_counters[modality][token] += 1

                    if modality == "vowels":
                        if ext == ".nsp":
                            vowel_nsp_tokens.add(token)
                            counts["vowel_nsp_count"] += 1
                        else:
                            vowel_egg_tokens.add(token)
                            counts["vowel_egg_count"] += 1
                    else:
                        if ext == ".nsp":
                            sentence_nsp_tokens.add(token)
                            counts["sentence_nsp_count"] += 1
                        else:
                            sentence_egg_tokens.add(token)
                            counts["sentence_egg_count"] += 1

                    file_writer.writerow(
                        {
                            "subject_id": subject_id,
                            "modality": modality,
                            "ext": ext,
                            "token": token,
                            "path": str(file_path),
                            "file_size_bytes": file_path.stat().st_size,
                            **header_info,
                        }
                    )

            remarks_dir = subject_dir / "remarks"
            remarks_path = None
            if remarks_dir.exists():
                txt_files = sorted(remarks_dir.glob("*.txt"))
                if txt_files:
                    remarks_path = txt_files[0]
            remarks_flags, remarks_excerpt = parse_remarks_flags(remarks_path)

            missing_vowel_nsp = sorted(vowel_egg_tokens - vowel_nsp_tokens)
            missing_vowel_egg = sorted(vowel_nsp_tokens - vowel_egg_tokens)
            missing_sentence_nsp = sorted(sentence_egg_tokens - sentence_nsp_tokens)
            missing_sentence_egg = sorted(sentence_nsp_tokens - sentence_egg_tokens)

            subject_rows.append(
                {
                    "subject_id": subject_id,
                    "has_vowels": (subject_dir / "vowels").exists(),
                    "has_sentences": (subject_dir / "sentences").exists(),
                    "has_remarks": remarks_path is not None,
                    **counts,
                    "vowel_pair_complete": not missing_vowel_nsp and not missing_vowel_egg,
                    "sentence_pair_complete": not missing_sentence_nsp
                    and not missing_sentence_egg,
                    "missing_vowel_nsp_tokens": ";".join(missing_vowel_nsp),
                    "missing_vowel_egg_tokens": ";".join(missing_vowel_egg),
                    "missing_sentence_nsp_tokens": ";".join(missing_sentence_nsp),
                    "missing_sentence_egg_tokens": ";".join(missing_sentence_egg),
                    "remarks_flags": remarks_flags,
                    "remarks_excerpt": remarks_excerpt,
                    "remarks_path": str(remarks_path) if remarks_path else "",
                }
            )

    with subject_report_path.open("w", newline="", encoding="utf-8") as subject_csv:
        subject_writer = csv.DictWriter(
            subject_csv,
            fieldnames=[
                "subject_id",
                "has_vowels",
                "has_sentences",
                "has_remarks",
                "vowel_nsp_count",
                "vowel_egg_count",
                "sentence_nsp_count",
                "sentence_egg_count",
                "vowel_pair_complete",
                "sentence_pair_complete",
                "missing_vowel_nsp_tokens",
                "missing_vowel_egg_tokens",
                "missing_sentence_nsp_tokens",
                "missing_sentence_egg_tokens",
                "remarks_flags",
                "remarks_excerpt",
                "remarks_path",
            ],
        )
        subject_writer.writeheader()
        subject_writer.writerows(subject_rows)

    summary = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "data_root": str(data_root),
        "subject_count": len(subject_dirs),
        "file_count": sum(ext_counter.values()),
        "file_count_by_extension": dict(ext_counter),
        "file_count_by_modality": dict(modality_counter),
        "parse_error_count": parse_error_count,
        "unique_vowel_tokens": len(token_counters["vowels"]),
        "unique_sentence_tokens": len(token_counters["sentences"]),
        "top_vowel_tokens": token_counters["vowels"].most_common(20),
        "top_sentence_tokens": token_counters["sentences"].most_common(20),
        "reports": {
            "subject_audit_csv": str(subject_report_path),
            "file_audit_csv": str(file_report_path),
        },
    }
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print(f"[OK] Subject report: {subject_report_path}")
    print(f"[OK] File report:    {file_report_path}")
    print(f"[OK] Summary JSON:  {summary_path}")
    print(f"[INFO] Subjects: {summary['subject_count']}, Files: {summary['file_count']}")
    print(f"[INFO] Parse errors: {summary['parse_error_count']}")


if __name__ == "__main__":
    main()
