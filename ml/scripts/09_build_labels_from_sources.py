#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Build binary labels (healthy/pathologic) from diagnosis source folders."
        )
    )
    parser.add_argument(
        "--labels-source-root",
        required=True,
        type=Path,
        help="Path containing diagnosis folders (healthy, Dysphonie, ...).",
    )
    parser.add_argument(
        "--data-root",
        required=True,
        type=Path,
        help="Main data root with numeric subject folders.",
    )
    parser.add_argument(
        "--out-csv",
        type=Path,
        default=Path("ml/reports/metadata/labels_from_sources.csv"),
        help="Output binary labels CSV (subject_id,label).",
    )
    parser.add_argument(
        "--out-detailed-csv",
        type=Path,
        default=Path("ml/reports/metadata/labels_detailed.csv"),
        help="Output detailed mapping CSV (subject_id,diagnosis_group,binary_label).",
    )
    parser.add_argument(
        "--out-summary-json",
        type=Path,
        default=Path("ml/reports/metadata/labels_summary.json"),
        help="Output summary JSON.",
    )
    parser.add_argument(
        "--drop-conflicts",
        action="store_true",
        help=(
            "Drop subjects that appear in both healthy and pathologic groups. "
            "Default keeps them with conflict flag in detailed table and excludes from binary output."
        ),
    )
    return parser.parse_args()


def is_subject_dir(path: Path) -> bool:
    return path.is_dir() and path.name.isdigit()


def diagnosis_to_binary(name: str) -> str:
    return "healthy" if name.strip().lower() == "healthy" else "pathologic"


def main() -> None:
    args = parse_args()
    labels_root = args.labels_source_root.expanduser().resolve()
    data_root = args.data_root.expanduser().resolve()
    out_csv = args.out_csv.expanduser().resolve()
    out_detailed = args.out_detailed_csv.expanduser().resolve()
    out_summary = args.out_summary_json.expanduser().resolve()

    out_csv.parent.mkdir(parents=True, exist_ok=True)
    out_detailed.parent.mkdir(parents=True, exist_ok=True)
    out_summary.parent.mkdir(parents=True, exist_ok=True)

    dataset_subjects = {
        p.name for p in data_root.iterdir() if is_subject_dir(p)
    }

    subject_to_groups: defaultdict[str, set[str]] = defaultdict(set)
    subject_to_binary: defaultdict[str, set[str]] = defaultdict(set)
    detailed_rows: list[dict[str, str]] = []

    group_dirs = sorted([p for p in labels_root.iterdir() if p.is_dir()], key=lambda p: p.name.lower())
    for group_dir in group_dirs:
        diagnosis_group = group_dir.name
        binary = diagnosis_to_binary(diagnosis_group)

        for subject_dir in sorted(group_dir.iterdir()):
            if not is_subject_dir(subject_dir):
                continue
            subject_id = subject_dir.name
            in_dataset = subject_id in dataset_subjects
            subject_to_groups[subject_id].add(diagnosis_group)
            subject_to_binary[subject_id].add(binary)

            detailed_rows.append(
                {
                    "subject_id": subject_id,
                    "diagnosis_group": diagnosis_group,
                    "binary_label": binary,
                    "in_main_dataset": str(in_dataset),
                }
            )

    # Write detailed mapping
    with out_detailed.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "subject_id",
                "diagnosis_group",
                "binary_label",
                "in_main_dataset",
            ],
        )
        writer.writeheader()
        writer.writerows(detailed_rows)

    # Build binary labels with conflict handling
    binary_rows: list[dict[str, str]] = []
    conflict_subjects: list[str] = []
    outside_dataset: list[str] = []
    for subject_id in sorted(subject_to_binary, key=lambda s: int(s)):
        binaries = subject_to_binary[subject_id]
        if subject_id not in dataset_subjects:
            outside_dataset.append(subject_id)
            continue
        if len(binaries) > 1:
            conflict_subjects.append(subject_id)
            if args.drop_conflicts:
                continue
            # By default, keep conflicts excluded from binary output for safety.
            continue
        binary_rows.append({"subject_id": subject_id, "label": next(iter(binaries))})

    with out_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["subject_id", "label"])
        writer.writeheader()
        writer.writerows(binary_rows)

    healthy_count = sum(1 for r in binary_rows if r["label"] == "healthy")
    pathologic_count = sum(1 for r in binary_rows if r["label"] == "pathologic")
    unlabeled_in_dataset = len(dataset_subjects - {r["subject_id"] for r in binary_rows})

    summary = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "labels_source_root": str(labels_root),
        "data_root": str(data_root),
        "diagnosis_group_count": len(group_dirs),
        "detailed_rows_count": len(detailed_rows),
        "binary_rows_count": len(binary_rows),
        "healthy_count": healthy_count,
        "pathologic_count": pathologic_count,
        "conflict_subject_count": len(conflict_subjects),
        "outside_dataset_subject_count": len(outside_dataset),
        "unlabeled_subjects_in_dataset_count": unlabeled_in_dataset,
        "outputs": {
            "labels_csv": str(out_csv),
            "labels_detailed_csv": str(out_detailed),
            "summary_json": str(out_summary),
        },
    }
    out_summary.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print(f"[OK] labels_csv:      {out_csv}")
    print(f"[OK] detailed_csv:    {out_detailed}")
    print(f"[OK] summary_json:    {out_summary}")
    print(
        "[INFO] "
        f"healthy={healthy_count} pathologic={pathologic_count} "
        f"conflicts={len(conflict_subjects)} unlabeled_in_dataset={unlabeled_in_dataset}"
    )


if __name__ == "__main__":
    main()
