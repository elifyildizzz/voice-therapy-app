#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create lightweight inference bundle manifest for backend."
    )
    parser.add_argument(
        "--artifact-dir",
        type=Path,
        default=Path("backend/model_artifacts/baseline_v1"),
        help="Directory containing exported model artifacts.",
    )
    parser.add_argument(
        "--out-json",
        type=Path,
        default=Path("backend/model_artifacts/baseline_v1/inference_bundle.json"),
        help="Output manifest file.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    artifact_dir = args.artifact_dir.expanduser().resolve()
    out_json = args.out_json.expanduser().resolve()
    out_json.parent.mkdir(parents=True, exist_ok=True)

    meta_path = artifact_dir / "model_meta.json"
    arrays_path = artifact_dir / "model_arrays.npz"
    if not meta_path.exists() or not arrays_path.exists():
        raise SystemExit(
            f"Artifacts missing in {artifact_dir}. "
            "Run 05_train_baseline.py then 07_export_model.py first."
        )

    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    bundle = {
        "model_type": meta.get("model_type", "gaussian_nb_numpy"),
        "classes": meta.get("classes", []),
        "feature_names": meta.get("feature_names", []),
        "artifact_files": {
            "arrays": str(arrays_path),
            "meta": str(meta_path),
        },
    }
    out_json.write_text(json.dumps(bundle, indent=2), encoding="utf-8")
    print(f"[OK] Inference bundle manifest: {out_json}")


if __name__ == "__main__":
    main()
