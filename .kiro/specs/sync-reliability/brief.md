# Brief: sync-reliability

## Problem
Records that fail to sync stay failed forever without escalation, permanent rejections are dropped or silently parked, there is no conflict policy of any kind, doctor review verdicts never reach the devices that need them, and the server's retention job is manual and default-off — so fundus images accumulate indefinitely on a deployed server. Verified: no `conflict|merge|etag|version|last-write` resolution exists anywhere in `api/**` or `flutter_app/lib/**` (only schema `consent_version` fields and SQLite `ConflictAlgorithm` upserts); the client has **no auto-retry** — sync is a manual button (`queue_screen.dart:25,249`) and `syncOfflineBatch` (`api_service.dart:741-890`) has no backoff; the designed `DEAD_LETTER` and `RETRY_WAIT` states exist only in dead code (`local_store.dart:133-134,285-290`); `api/retention.py:179-181` requires `--apply` and has no scheduler, so only CLI/tests ever invoke it; and doctor verdicts UPDATE rows server-side (`api/routes/review.py:184-219`) with no back-sync to devices.

## Current State
Verified during discovery:
- **What works and must be preserved**: idempotent `/sync` v1 via `local_screening_id` receipt PK with prefetch, skip-if-live, `pending-` marker and an 8s winner-wait (`api/routes/sync.py:66-237`); `/sync/v2` `INSERT OR IGNORE` replay semantics (`sync_v2.py:138-172`); per-item `failed_items` reporting; batch caps (5 / 3) and image caps (10 MB / 1.5 MB decoded with JPEG magic); role auth on writes and doctor-only reads; PHI lint rejecting whole batches fail-closed (`sync_v2.py:78-103`); value-redacted 422 bodies (`api/main.py:177-210`).
- **What's missing**: client retry/backoff; dead-letter escalation; conflict policy; doctor-verdict back-sync; scheduled retention.
- **Verified hazards**: a retried v1 item **re-runs inference** when its receipt row has been purged by retention (`sync.py:108-110,188-191`) — new server row while the client believes nothing changed; `/sync` busy-waits up to 8 s holding a DB connection (`sync.py:197-209`); server DB is unencrypted SQLite (`api/database.py:50-60`); rate limits are per-IP only and in-memory single-process (`ratelimit.py:47-65`).
- **Verified data-loss paths owned here**: 422-rejected de-id referrals dropped with only a counter (`referral_uplink_service.dart:192-197`); AI-timeout captures never queued (`api_service.dart:654-663`); corrupt entries purged without backup (`api_service.dart:776-780`).
- **Audit trail exists but is append-only plain SQLite**, not tamper-evident (`api/auth.py:119-124`, `api/database.py:259-269`).

## Desired Outcome
A record either reaches the server or the operator is escalated with the record still intact. Permanent rejections enter a visible dead-letter state with an operator action. Doctor verdicts appear on the device that captured the screening. Retention runs on a schedule and images do not accumulate by default. A documented, tested conflict policy exists — even if the answer is "insert-only, conflicts cannot occur, here is why."

## Approach
Build on the existing lifecycle from `offline-record-durability`: (1) automatic retry with exponential backoff and a bounded attempt count that transitions to an explicit dead-letter state surfaced in the queue UI with a manual-retry/abandon action; (2) stop dropping 422-rejected and corrupt payloads — preserve them in the dead-letter store with the rejection reason; (3) define and document the conflict policy (confirm insert-only semantics, close the receipt-purge re-inference loophole with a deterministic idempotency rule, and specify what happens if a server row already exists with different content); (4) back-sync doctor verdicts to devices via a small pull endpoint the app calls on launch/foreground; (5) schedule retention with a default-on policy, a documented retention window, and an audit entry for purges; (6) fix the `/sync` busy-wait so it does not hold a DB connection while sleeping. Only after that, decide whether server-side DB encryption and per-key rate limiting are in scope.

## Scope
- **In**: client auto-retry with backoff; dead-letter state with operator-visible escalation; preservation of rejected payloads with reasons; a documented and tested conflict/idempotency policy including the receipt-purge re-inference loophole; doctor-verdict back-sync to devices; scheduled, default-on server retention with audit entries; the `/sync` connection-holding fix.
- **Out**: offline queue persistence mechanics (owned by `offline-record-durability`); real-time/push sync; multi-master replication or version vectors (unnecessary while insert-only); database migration to Postgres; end-to-end encryption; UI redesign.

## Boundary Candidates
- Client retry/dead-letter policy
- Server conflict and idempotency rules
- Review-verdict distribution (server → device)
- Retention scheduling and purge auditing

## Out of Boundary
- Making records durable in the first place (`offline-record-durability`).
- Interpreting whether device and server *grades* agree (`prediction-consensus`).
- Server authentication, rate-limit redesign and secrets management (security follow-up, informed by the direct items in the roadmap).

## Upstream / Downstream
- **Upstream**: `api/routes/sync.py`, `api/routes/sync_v2.py`, `api/retention.py`, `api/database.py`, `offline-record-durability`'s lifecycle.
- **Downstream**: `prediction-consensus` (needs both sides to hold current results), `test-ci-coverage-gate` (hosts contract tests for the new endpoint and retry policy).

## Existing Spec Touchpoints
- **Extends**: none (first spec set).
- **Adjacent**: `offline-record-durability` is a hard dependency; `test-ci-coverage-gate` hosts `test_deidentified_sync.py` which must keep passing when `/sync/v2` changes.

## Constraints
- The PHI fail-closed contract in `tests/integration/test_deidentified_sync.py` (15 tests) must not weaken — it is the security spine of sync.
- Idempotency guarantees must be preserved: the same local ID must never create two screening records.
- Retention must not delete a record the client still believes is unsynced; ordering between purge and sync is part of the design.
- Any new endpoint requires role auth and audit logging consistent with the existing routes.
- No new heavyweight dependencies (no queues, no Redis).
