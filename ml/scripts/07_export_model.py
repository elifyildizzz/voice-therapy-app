#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export trained model artifacts to backend folder."
    )
    parser.add_argument(
        "--model-dir",
        type=Path,
        default=Path("ml/models/baseline_v1"),
        help="Source model artifact directory.",
    )
    parser.add_argument(
        "--target-dir",
        type=Path,
        default=Path("backend/model_artifacts/baseline_v1"),
        help="Target directory for backend inference files.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    model_dir = args.model_dir.expanduser().resolve()
    target_dir = args.target_dir.expanduser().resolve()
    target_dir.mkdir(parents=True, exist_ok=True)

    required = [
        "model_arrays.npz",
        "model_meta.json",
        "metrics.json",
        "split.json",
    ]

    missing = [name for name in required if not (model_dir / name).exists()]
    if missing:
        raise SystemExit(f"Missing artifacts in {model_dir}: {', '.join(missing)}")

    for name in required:
        shutil.copy2(model_dir / name, target_dir / name)

    # Optional files
    for optional in ("test_predictions.csv", "eval_metrics.json"):
        src = model_dir / optional
        if src.exists():
            shutil.copy2(src, target_dir / optional)

    print(f"[OK] Exported model artifacts to: {target_dir}")


if __name__ == "__main__":
    main()
