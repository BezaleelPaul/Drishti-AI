"""Latency benchmark suite: per-stage timings across image sizes.

Usage:
    python benchmark_latency.py [--sizes 256 512 1024] [--repeats 3]
                               [--out results/benchmark.json]

Measures wall-clock time for each pipeline stage (quality gate,
segmentation, classifier, gradcam, full router pass) on synthetic fundus
images at each size plus one real sample. Prints a table and writes JSON.
No clinical meaning — capacity planning only.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import statistics
import time

import numpy as np

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))


def _hardware_info() -> dict:
    info = {
        "system": platform.system(),
        "machine": platform.machine(),
        "processor": platform.processor(),
        "python": platform.python_version(),
    }
    try:
        if platform.system() == "Darwin":
            import subprocess
            info["cpu_brand"] = subprocess.run(
                ["sysctl", "-n", "machdep.cpu.brand_string"],
                capture_output=True, text=True, timeout=5,
            ).stdout.strip()
    except Exception:
        pass
    return info


def _time(fn, repeats: int):
    fn()  # warmup (caches, lazy TF init) — not counted
    vals = []
    for _ in range(repeats):
        t0 = time.perf_counter()
        fn()
        vals.append((time.perf_counter() - t0) * 1000.0)
    return {"median_ms": round(statistics.median(vals), 1),
            "min_ms": round(min(vals), 1), "max_ms": round(max(vals), 1)}


def main() -> int:
    ap = argparse.ArgumentParser(description="Per-stage latency benchmark.")
    ap.add_argument("--sizes", type=int, nargs="+", default=[256, 512, 1024])
    ap.add_argument("--repeats", type=int, default=3)
    ap.add_argument("--out", default=os.path.join(PROJECT_ROOT, "results", "benchmark.json"))
    args = ap.parse_args()

    from src.quality.checker import ImageQualityChecker, QualityThresholds
    from src.quality.enhancer import AdaptiveQualityEnhancer  # noqa: F401 (import cost counted)
    from src.classification.classifier import DRClassifier
    from src.classification.gradcam import GradCAMExplainer
    from src.segmentation.structure_segmenter import RetinalStructureSegmenter
    from src.pipeline.router import ScreeningPipelineRouter
    from src.synthetic_fixtures import create_synthetic_fundus_image

    checker = ImageQualityChecker(QualityThresholds())
    segmenter = RetinalStructureSegmenter(use_dl_toolbox=False)
    clf = DRClassifier()
    explainer = GradCAMExplainer(classifier_backend=clf)
    router = ScreeningPipelineRouter()
    print(f"model_backend={clf.get_backend()}")

    report = {
        "model_backend": clf.get_backend(),
        "hardware": _hardware_info(),
        "note": "Wall-clock on the machine that ran the script; not transferable "
                "to field hardware. Re-run on target devices for capacity planning.",
        "sizes": {},
    }
    for size in args.sizes:
        img = create_synthetic_fundus_image((size, size))
        pred = clf.predict(img)
        entry = {
            "quality_gate": _time(lambda: checker.assess_image(img), args.repeats),
            "segmentation": _time(lambda: segmenter.segment_structures(img), args.repeats),
            "classifier": _time(lambda: clf.predict(img), args.repeats),
            "gradcam": _time(lambda: explainer.generate_heatmap(img, pred.predicted_grade, classifier=clf), args.repeats),
            "full_router": _time(lambda: router.process_image(img, output_dir=None), args.repeats),
        }
        report["sizes"][str(size)] = entry

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w") as fh:
        json.dump(report, fh, indent=2)

    stages = ["quality_gate", "segmentation", "classifier", "gradcam", "full_router"]
    print(f"{'size':>6} " + " ".join(f"{s:>14}" for s in stages) + "  (median ms)")
    for size in args.sizes:
        row = " ".join(f"{report['sizes'][str(size)][s]['median_ms']:>14}" for s in stages)
        print(f"{size:>6} {row}")
    print(f"-> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
