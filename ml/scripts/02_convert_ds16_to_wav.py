#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import os
import wave
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


@dataclass
class Ds16Audio:
    sample_rate_hz: int
    sample_count: int
    chunk_id: str
    chunk_length: int
    pcm_bytes: bytes

    @property
    def duration_sec(self) -> float:
        return self.sample_count / self.sample_rate_hz


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


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def portable_data_path(path: Path, data_root: Path) -> str:
    try:
        return str(path.relative_to(data_root))
    except ValueError:
        return str(path)


def portable_repo_path(path: Path) -> str:
    root = repo_root()
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def parse_args() -> argparse.Namespace:
    load_env_file()

    parser = argparse.ArgumentParser(
        description="Convert DS16/IFF .nsp/.egg files to WAV (16-bit PCM mono)."
    )
    parser.add_argument(
        "--data-root",
        type=Path,
        default=env_path_or_default(
            "BITIRME_DATA_ROOT",
            Path.home() / "Desktop" / "bitirme" / "data",
        ),
        help=(
            "Dataset root path. "
            "Default: $BITIRME_DATA_ROOT or ~/Desktop/bitirme/data"
        ),
    )
    parser.add_argument(
        "--out-dir",
        default=Path("ml/processed/wav"),
        type=Path,
        help="Output root for WAV files.",
    )
    parser.add_argument(
        "--ext",
        default="nsp",
        choices=("nsp", "egg", "both"),
        help="Which source extension to convert.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Optional max number of files to convert (0 = all).",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing WAV files.",
    )
    return parser.parse_args()


def parse_ds16(path: Path) -> Ds16Audio:
    payload_offset = 0x3C
    data = path.read_bytes()

    if len(data) < payload_offset:
        raise ValueError("header_too_short")
    if data[0:4] != b"FORM" or data[4:8] != b"DS16":
        raise ValueError("not_form_ds16")

    sample_rate_hz = int.from_bytes(data[0x28:0x2C], "little", signed=False)
    sample_count = int.from_bytes(data[0x2C:0x30], "little", signed=False)
    chunk_id = data[0x34:0x38].decode("latin1", errors="replace")
    chunk_length = int.from_bytes(data[0x38:0x3C], "little", signed=False)

    if sample_rate_hz <= 0 or sample_rate_hz > 500_000:
        raise ValueError(f"invalid_sample_rate:{sample_rate_hz}")
    if sample_count <= 0:
        raise ValueError(f"invalid_sample_count:{sample_count}")
    if chunk_length <= 0:
        raise ValueError(f"invalid_chunk_length:{chunk_length}")
    if chunk_id not in {"SDA_", "VSDA"}:
        raise ValueError(f"unsupported_chunk_id:{chunk_id}")

    end = payload_offset + chunk_length
    if len(data) < end:
        raise ValueError(
            f"truncated_payload:file_size={len(data)},required={end}"
        )

    pcm_bytes = data[payload_offset:end]
    expected_pcm = sample_count * 2
    if len(pcm_bytes) != expected_pcm:
        raise ValueError(
            f"payload_mismatch:expected={expected_pcm},actual={len(pcm_bytes)}"
        )

    return Ds16Audio(
        sample_rate_hz=sample_rate_hz,
        sample_count=sample_count,
        chunk_id=chunk_id,
        chunk_length=chunk_length,
        pcm_bytes=pcm_bytes,
    )


def write_wav(target_path: Path, audio: Ds16Audio) -> None:
    target_path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target_path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(audio.sample_rate_hz)
        wf.writeframes(audio.pcm_bytes)


def collect_source_files(data_root: Path, ext_mode: str) -> list[Path]:
    exts = [".nsp", ".egg"] if ext_mode == "both" else [f".{ext_mode}"]
    files: list[Path] = []
    for ext in exts:
        files.extend(data_root.rglob(f"*{ext}"))
    return sorted(path for path in files if path.is_file())


def main() -> None:
    args = parse_args()
    data_root = args.data_root.expanduser().resolve()
    out_dir = args.out_dir.expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    source_files = collect_source_files(data_root, args.ext)
    if args.limit > 0:
        source_files = source_files[: args.limit]

    report_path = out_dir / "conversion_report.csv"
    summary_path = out_dir / "conversion_summary.json"

    converted = 0
    skipped = 0
    failed = 0

    with report_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(
            csv_file,
            fieldnames=[
                "source_path",
                "target_path",
                "status",
                "error",
                "sample_rate_hz",
                "sample_count",
                "duration_sec",
                "source_size_bytes",
                "target_size_bytes",
            ],
        )
        writer.writeheader()

        for index, source_path in enumerate(source_files, start=1):
            rel_path = source_path.relative_to(data_root)
            target_path = (out_dir / rel_path).with_suffix(".wav")

            if target_path.exists() and not args.overwrite:
                skipped += 1
                writer.writerow(
                    {
                        "source_path": portable_data_path(source_path, data_root),
                        "target_path": portable_repo_path(target_path),
                        "status": "skipped_exists",
                        "error": "",
                        "sample_rate_hz": "",
                        "sample_count": "",
                        "duration_sec": "",
                        "source_size_bytes": source_path.stat().st_size,
                        "target_size_bytes": target_path.stat().st_size,
                    }
                )
                continue

            try:
                audio = parse_ds16(source_path)
                write_wav(target_path, audio)
                converted += 1
                writer.writerow(
                    {
                        "source_path": portable_data_path(source_path, data_root),
                        "target_path": portable_repo_path(target_path),
                        "status": "converted",
                        "error": "",
                        "sample_rate_hz": audio.sample_rate_hz,
                        "sample_count": audio.sample_count,
                        "duration_sec": f"{audio.duration_sec:.6f}",
                        "source_size_bytes": source_path.stat().st_size,
                        "target_size_bytes": target_path.stat().st_size,
                    }
                )
            except Exception as exc:
                failed += 1
                writer.writerow(
                    {
                        "source_path": portable_data_path(source_path, data_root),
                        "target_path": portable_repo_path(target_path),
                        "status": "failed",
                        "error": str(exc),
                        "sample_rate_hz": "",
                        "sample_count": "",
                        "duration_sec": "",
                        "source_size_bytes": source_path.stat().st_size,
                        "target_size_bytes": "",
                    }
                )

            if index % 1000 == 0:
                print(f"[INFO] Processed {index}/{len(source_files)} files...")

    summary = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "data_root_env_var": "BITIRME_DATA_ROOT",
        "data_root_default": "~/Desktop/bitirme/data",
        "out_dir": portable_repo_path(out_dir),
        "source_file_count": len(source_files),
        "converted_count": converted,
        "skipped_count": skipped,
        "failed_count": failed,
        "report_csv": portable_repo_path(report_path),
    }
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print(f"[OK] Conversion report: {report_path}")
    print(f"[OK] Conversion summary: {summary_path}")
    print(
        "[INFO] "
        f"source={len(source_files)} converted={converted} "
        f"skipped={skipped} failed={failed}"
    )


if __name__ == "__main__":
    main()
