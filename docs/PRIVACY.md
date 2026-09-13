# Drishti-AI / Netra-AI — Privacy & Access-Control Matrix

> Health screening data (fundus photos, demographics, ABHA/phone) is sensitive
> personal data under India's DPDP Act (and HIPAA/GDPR equivalents where
> applicable). This document is the contract for who can see what, where data
> lives, and what guarantees the system gives. Code references are the
> enforcement — not aspirations.

## 1. Roles

| Role | Who | Key | Sees |
|---|---|---|---|
| **Operator** (ASHA/PHC worker) | Field screening on the mobile app | `X-API-Key` with `operator` role | Own centre's patients (register/search/list), capture + quality + AI results for those patients, own offline queue |
| **Doctor** (tele-ophthalmologist) | Review queue + verdicts | `X-API-Key` with `doctor` role | Everything an operator sees, **plus** the review queue (`GET /review/pending`) and verdict submission (`POST /review/{id}`) |
| **Admin** | Deployments, audits | `X-API-Key` with `admin` role | Everything, plus the `audit_log` compliance trail. No admin-only mutating endpoints exist yet (`require_admin` is reserved) |
| **Patient** | The screened individual | — (no login) | Sees only their own result via the operator's device (SMS slip / referral printout). Patients never get API keys |

Role hierarchy is enforced server-side (`api/auth.py`): `admin > doctor > operator`.
The client can claim nothing — every request re-validates the key.

## 2. Endpoint guards (all in `api/routes/`)

| Endpoint | Guard | Notes |
|---|---|---|
| `POST /patients`, `GET /patients`, `GET /patients/{id}` | any authenticated key | Full PHI incl. phone + ABHA. Intended for single-PHC use; every read is audit-logged (`patient_list`, `patient_read`) |
| `POST /retinal/quality`, `POST /retinal/analyze`, `GET /retinal/screenings/{id}` | any authenticated key | Images + grades |
| `GET /results/{id}/{file}` | any authenticated key | Path-traversal hardened; reads **and misses** audited (`result_read`, `result_read_404`) so ID enumeration leaves a trace |
| `POST /diabetes-risk`, `POST /sync`, `GET /status` | any authenticated key | |
| `GET /review/pending`, `POST /review/{id}` | **doctor or admin only** | An operator key gets 401/403. The app surfaces "doctor key required" instead of a fake empty queue |
| `GET /cameras`, `GET /samples` | public | No PHI: camera specs + fictional demo personas only |
| `GET /` | public | Liveness only, no counts (counts would be an unauthenticated oracle) |

**Client-side honesty rule** (`doctor_review_screen.dart`): a sign-off counts
only when the server accepts it. A rejected verdict reverts the UI and says
so — the app can never display a forged clinical approval.

## 3. Where data lives (local-first)

- **Phone/tablet**: captures queue in **memory only** (`ApiService.offlineQueue`,
  lost on restart — stated in code). `SharedPreferences` holds **language
  preference only, never PHI**. Android backup is disabled
  (`allowBackup=false`, `dataExtractionRules`), so `adb backup` and cloud
  backup cannot exfiltrate the sandbox. Network is HTTPS-only with plaintext
  blocked at the OS layer.
- **Server**: SQLite + `results/api_screenings/` on the deployment host.
  This copy exists to run inference and hold the review queue — it is
  **operational, not archival**:
  - `SEED_DEMO_DATA=0` in production (no demo patients seeded),
  - `RETENTION_DAYS` purge job (`api/retention.py`) deletes screenings,
    verdicts, and image dirs older than the window (recommend 90),
  - dev API keys are refused on any non-loopback interface (fail-closed).
- **Never**: no third-party analytics, no cloud backup of device data, no
  bundled patient images in the app package (explicit asset allowlist in
  `pubspec.yaml`).

## 4. Audit trail

`audit_log` table (never purged by retention): authentication failures,
forbidden attempts, patient reads/lists, result reads **and misses**, verdicts.
Review it as the compliance record of who touched whose data.
