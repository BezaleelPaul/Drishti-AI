"""Tests for the data-retention purge job (api/retention.py)."""

import os
import sqlite3
import tempfile
import unittest
from datetime import datetime, timedelta, timezone

from api.retention import _parse_created, purge_expired_screenings, retention_days_from_env

os.environ["SEED_DEMO_DATA"] = "0"


def _make_db(path: str, ages_days):
    """Creates a DB with one patient + screenings of given ages."""
    import api.database as db
    orig = db.DB_PATH
    db.DB_PATH = path
    try:
        db.init_db()
        conn = sqlite3.connect(path)
        try:
            conn.execute(
                "INSERT INTO patients (patient_id, name, age, gender, created_at) "
                "VALUES ('PT-T1', 'Test', 50, 'Male', ?)",
                (datetime.now(timezone.utc).isoformat(),))
            for i, age in enumerate(ages_days):
                ts = (datetime.now(timezone.utc) - timedelta(days=age)).isoformat()
                conn.execute(
                    "INSERT INTO screenings (screening_id, patient_id, eye_side, quality_grade, created_at) "
                    "VALUES (?, 'PT-T1', 'Right', 'GOOD', ?)", (f"SCR-T{i}", ts))
            conn.commit()
        finally:
            conn.close()
    finally:
        db.DB_PATH = orig


class TestRetention(unittest.TestCase):
    def test_parse_created(self):
        self.assertIsNotNone(_parse_created(datetime.now(timezone.utc).isoformat()))
        self.assertIsNotNone(_parse_created("2026-01-01T00:00:00Z"))
        self.assertIsNotNone(_parse_created("2026-01-01T00:00:00"))
        self.assertIsNone(_parse_created(None))
        self.assertIsNone(_parse_created("garbage"))
        self.assertIsNone(_parse_created(123))

    def test_env_default(self):
        os.environ.pop("RETENTION_DAYS", None)
        self.assertEqual(retention_days_from_env(), 0)
        os.environ["RETENTION_DAYS"] = "abc"
        self.assertEqual(retention_days_from_env(), 0)
        os.environ["RETENTION_DAYS"] = "365"
        self.assertEqual(retention_days_from_env(), 365)
        del os.environ["RETENTION_DAYS"]

    def test_rejects_nonpositive(self):
        with self.assertRaises(ValueError):
            purge_expired_screenings(0)

    def test_invalid_timestamps_are_reported_and_not_purged(self):
        with tempfile.TemporaryDirectory() as td:
            dbp = os.path.join(td, "t.db")
            _make_db(dbp, [400])
            conn = sqlite3.connect(dbp)
            try:
                conn.execute(
                    "INSERT INTO screenings "
                    "(screening_id, patient_id, eye_side, quality_grade, created_at) "
                    "VALUES ('SCR-BAD', 'PT-T1', 'Right', 'GOOD', 'not-a-timestamp')"
                )
                conn.commit()
            finally:
                conn.close()

            report = purge_expired_screenings(365, db_path=dbp, dry_run=True)

            self.assertEqual(report["screenings"], ["SCR-T0"])
            self.assertEqual(report["invalid_timestamps"], ["SCR-BAD"])

    def test_dry_run_deletes_nothing(self):
        with tempfile.TemporaryDirectory() as td:
            dbp = os.path.join(td, "t.db")
            rdir = os.path.join(td, "res")
            os.makedirs(os.path.join(rdir, "SCR-T0"))
            _make_db(dbp, [400, 10])
            rep = purge_expired_screenings(365, db_path=dbp, results_dir=rdir, dry_run=True)
            self.assertEqual(rep["screenings"], ["SCR-T0"])
            self.assertEqual(rep["dirs"], [os.path.join(rdir, "SCR-T0")])
            self.assertTrue(os.path.isdir(os.path.join(rdir, "SCR-T0")))
            conn = sqlite3.connect(dbp)
            try:
                n = conn.execute("SELECT COUNT(*) FROM screenings").fetchone()[0]
            finally:
                conn.close()
            self.assertEqual(n, 2)

    def test_apply_deletes_old_only(self):
        with tempfile.TemporaryDirectory() as td:
            dbp = os.path.join(td, "t.db")
            rdir = os.path.join(td, "res")
            os.makedirs(os.path.join(rdir, "SCR-T0"))
            _make_db(dbp, [400, 10])
            rep = purge_expired_screenings(365, db_path=dbp, results_dir=rdir, dry_run=False)
            self.assertFalse(rep["dry_run"])
            self.assertEqual(rep["screenings"], ["SCR-T0"])
            self.assertFalse(os.path.exists(os.path.join(rdir, "SCR-T0")))
            conn = sqlite3.connect(dbp)
            try:
                rows = [r[0] for r in conn.execute("SELECT screening_id FROM screenings")]
                pats = conn.execute("SELECT COUNT(*) FROM patients").fetchone()[0]
            finally:
                conn.close()
            self.assertEqual(rows, ["SCR-T1"])
            self.assertEqual(pats, 1)  # patients never purged


if __name__ == "__main__":
    unittest.main()
