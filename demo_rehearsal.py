"""End-to-end demo rehearsal against the real HTTP API.

Boots uvicorn, then twice runs the full screening story:

    status -> register patient -> diabetes risk -> quality gate -> analyze
    -> history round-trip -> result image fetch -> adverse-input safety leg
    -> doctor review queue

Every step is timed and asserted. Evidence lands in
``results/demo_rehearsal/`` (one JSON per run + summary).

Usage:
    python demo_rehearsal.py                 # 2 runs, port 8077
    python demo_rehearsal.py --runs 1 --port 8078
"""

from __future__ import annotations

import argparse
import importlib
import json
import os
import subprocess
import sys
import time

httpx = importlib.import_module("httpx")

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
OP = {"X-API-Key": "dev-operator-key"}
DR = {"X-API-Key": "dev-doctor-key"}
FUNDUS = os.path.join(
    PROJECT_ROOT, "test_samples", "04_section24_demo_scenarios", "scenario_1_good.jpg"
)
FACE = os.path.join(
    PROJECT_ROOT, "test_samples", "03_adversarial_non_fundus", "external_face_closeup.jpg"
)


class RehearsalFailure(AssertionError):
    pass


def _step(steps: list, name: str, fn):
    t0 = time.time()
    try:
        response = fn()
    except Exception as exc:  # noqa: BLE001 - record then fail the rehearsal
        steps.append(
            {
                "step": name,
                "ok": False,
                "ms": round((time.time() - t0) * 1000, 1),
                "error": f"{type(exc).__name__}: {exc}",
            }
        )
        raise RehearsalFailure(f"{name}: {type(exc).__name__}: {exc}") from exc
    entry = {
        "step": name,
        "ok": 200 <= response.status_code < 300,
        "status": response.status_code,
        "ms": round((time.time() - t0) * 1000, 1),
    }
    steps.append(entry)
    if not entry["ok"]:
        raise RehearsalFailure(f"{name}: HTTP {response.status_code}: {response.text[:400]}")
    return response


def _require(condition: bool, message: str, steps: list) -> None:
    steps.append({"assert": message, "ok": bool(condition)})
    if not condition:
        raise RehearsalFailure(message)


def run_once(client, run: int) -> dict:
    steps: list[dict] = []
    started = time.time()
    patient_id = f"PT-DEMO-R{run}-{int(started)}"

    r = _step(steps, "GET /status", lambda: client.get("/status", headers=OP))
    status = r.json()

    r = _step(
        steps,
        "POST /patients",
        lambda: client.post(
            "/patients",
            headers=OP,
            json={
                "patient_id": patient_id,
                "name": f"Demo Patient R{run}",
                "age": 54,
                "gender": "Female",
                "known_diabetes": "Yes",
                "hba1c": 8.1,
                "bmi": 28.4,
                "family_history": True,
                "physical_activity": "Sedentary",
                "symptoms": ["Blurry vision"],
            },
        ),
    )
    _require(r.json()["patient_id"] == patient_id, "patient id echoed back", steps)

    r = _step(
        steps,
        "POST /diabetes-risk",
        lambda: client.post(
            "/diabetes-risk",
            headers=OP,
            json={
                "patient_id": patient_id,
                "age": 54,
                "gender": "Female",
                "bmi": 28.4,
                "family_history": True,
                "physical_activity": "Sedentary",
                "hba1c": 8.1,
            },
        ),
    )
    risk = r.json()
    _require(risk["risk_level"] in ("LOW", "MODERATE", "HIGH"), "risk level enum", steps)

    with open(FUNDUS, "rb") as fh:
        fundus_bytes = fh.read()

    r = _step(
        steps,
        "POST /retinal/quality (real fundus)",
        lambda: client.post(
            "/retinal/quality",
            headers=OP,
            files={"file": ("patient1.jpg", fundus_bytes, "image/jpeg")},
        ),
    )
    quality = r.json()
    _require(
        quality["quality_grade"] == "GOOD" and quality["error_code"] is None,
        f"GOOD image passes quality gate (got {quality['quality_grade']}/{quality['error_code']})",
        steps,
    )

    r = _step(
        steps,
        "POST /retinal/analyze (real fundus)",
        lambda: client.post(
            "/retinal/analyze",
            headers=OP,
            data={"patient_id": patient_id, "eye_side": "Right"},
            files={"file": ("patient1.jpg", fundus_bytes, "image/jpeg")},
        ),
    )
    analysis = r.json()
    screening_id = analysis["screening_id"]
    _require(
        analysis["error_code"] in (None, "AI_LOW_CONFIDENCE"),
        f"no hard failure on real fundus (got {analysis['error_code']})",
        steps,
    )
    _require(analysis["model_backend"] == "keras", "shipped keras backend used", steps)
    _require(analysis["inference_time_ms"] is not None, "inference time recorded", steps)

    r = _step(
        steps,
        f"GET /screenings/{patient_id}",
        lambda: client.get(f"/screenings/{patient_id}", headers=OP),
    )
    history = r.json()
    _require(len(history) == 1, "screening persisted once", steps)
    _require("error_code" in history[0], "history exposes error_code contract", steps)

    overlay = analysis.get("gradcam_overlay_url")
    if overlay:
        r = _step(steps, "GET overlay image", lambda: client.get(overlay, headers=OP))
        _require(
            r.headers.get("content-type", "").startswith("image/"), "overlay is an image", steps
        )

    with open(FACE, "rb") as fh:
        face_bytes = fh.read()

    r = _step(
        steps,
        "POST /retinal/analyze (adverse: human face)",
        lambda: client.post(
            "/retinal/analyze",
            headers=OP,
            data={"patient_id": patient_id, "eye_side": "Left"},
            files={"file": ("face.jpg", face_bytes, "image/jpeg")},
        ),
    )
    adverse = r.json()
    _require(adverse["error_code"] == "IMG_NOT_FUNDUS", "face rejected as non-retinal", steps)
    _require(adverse["dr_grade"] is None, "no DR grade invented for a face", steps)
    _require(adverse.get("is_referable") is not True, "no referral fabricated for a face", steps)

    r = _step(steps, "GET /review/pending", lambda: client.get("/review/pending", headers=DR))
    pending = r.json()
    _require(isinstance(pending, (list, dict)), "review queue reachable by doctor key", steps)

    return {
        "run": run,
        "ok": True,
        "wall_seconds": round(time.time() - started, 2),
        "patient_id": patient_id,
        "screening_id": screening_id,
        "engine": status.get("ai_engine"),
        "quality": {"grade": quality["quality_grade"], "error_code": quality["error_code"]},
        "analysis": {
            "dr_grade": analysis["dr_grade"],
            "dr_label": analysis["dr_label"],
            "error_code": analysis["error_code"],
            "model_backend": analysis["model_backend"],
            "is_referable": analysis["is_referable"],
            "inference_time_ms": analysis["inference_time_ms"],
            "requires_human_review": analysis["requires_human_review"],
        },
        "adverse_input": {
            "error_code": adverse["error_code"],
            "dr_grade": adverse["dr_grade"],
        },
        "steps": steps,
    }


def wait_ready(base_url: str, timeout_s: float = 120.0) -> None:
    deadline = time.time() + timeout_s
    last_error = None
    while time.time() < deadline:
        try:
            r = httpx.get(base_url + "/", timeout=3.0)
            if r.status_code == 200:
                return
        except Exception as exc:  # noqa: BLE001 - server still booting
            last_error = exc
        time.sleep(0.5)
    raise RehearsalFailure(f"server not ready after {timeout_s}s: {last_error}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Drishti-AI end-to-end demo rehearsal.")
    ap.add_argument("--runs", type=int, default=2)
    ap.add_argument("--port", type=int, default=8077)
    args = ap.parse_args()

    out_dir = os.path.join(PROJECT_ROOT, "results", "demo_rehearsal")
    os.makedirs(out_dir, exist_ok=True)
    base_url = f"http://127.0.0.1:{args.port}"

    server = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "uvicorn",
            "api.main:app",
            "--host",
            "127.0.0.1",
            "--port",
            str(args.port),
            "--log-level",
            "warning",
        ],
        cwd=PROJECT_ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.STDOUT,
    )
    runs: list[dict] = []
    try:
        wait_ready(base_url)
        with httpx.Client(base_url=base_url, timeout=180.0) as client:
            for run in range(1, args.runs + 1):
                print(f"--- rehearsal run {run}/{args.runs} ---")
                result = run_once(client, run)
                runs.append(result)
                for step in result["steps"]:
                    label = step.get("step") or f"assert: {step.get('assert')}"
                    mark = "ok" if step.get("ok") else "FAIL"
                    timing = f" {step['ms']}ms" if "ms" in step else ""
                    print(f"  [{mark}]{timing} {label}")
                print(
                    f"  grade={result['analysis']['dr_grade']} "
                    f"({result['analysis']['dr_label']}) backend={result['analysis']['model_backend']} "
                    f"inference={result['analysis']['inference_time_ms']}ms "
                    f"wall={result['wall_seconds']}s"
                )
                with open(os.path.join(out_dir, f"rehearsal_run{run}.json"), "w") as fh:
                    json.dump(result, fh, indent=2)
    finally:
        server.terminate()
        try:
            server.wait(timeout=15)
        except subprocess.TimeoutExpired:
            server.kill()

    summary = {
        "runs": len(runs),
        "all_ok": bool(runs) and all(r["ok"] for r in runs),
        "runs_detail": [
            {
                "run": r["run"],
                "wall_seconds": r["wall_seconds"],
                "screening_id": r["screening_id"],
                "dr_grade": r["analysis"]["dr_grade"],
                "error_code": r["analysis"]["error_code"],
                "inference_time_ms": r["analysis"]["inference_time_ms"],
                "adverse_error_code": r["adverse_input"]["error_code"],
                "assertions_passed": sum(1 for s in r["steps"] if "assert" in s),
                "steps": len([s for s in r["steps"] if "step" in s]),
            }
            for r in runs
        ],
        "evidence": [f"rehearsal_run{i + 1}.json" for i in range(len(runs))],
    }
    with open(os.path.join(out_dir, "summary.json"), "w") as fh:
        json.dump(summary, fh, indent=2)
    print(json.dumps(summary, indent=2))
    print(f"-> {os.path.join(out_dir, 'summary.json')}")
    return 0 if summary["all_ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
