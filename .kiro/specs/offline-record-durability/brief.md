# Brief: offline-record-durability

## Problem
Offline-first is the product's core promise, but the durable record layer is largely unimplemented or unreachable, and there are five verified paths where a captured screening can vanish without the operator being told. Most seriously, the SQLCipher state machine in `LocalStore` — the thing that would make records survive a process kill — has **zero callers**: `recordScreening`, `recordReceipt`, `markQueueState`, `pendingSyncBatch`, `deleteImageAfterAck`, `screeningsForPatient`, `getMeta/setMeta` are never invoked outside `local_store.dart`. Its docstring (`local_store.dart:10`) claims kill/restart invariants are "tested by integration_test/offline_restart_test" — **that file does not exist** (`flutter_app/integration_test/` is absent). Meanwhile boot persistence is fire-and-forget (`main.dart:19`), degrades to an in-memory store on failure behind a silent `catch (_)` (`main.dart:32-35`), and the `isPersisted` flag that would tell the UI about that degradation is set (`offline_queue_service.dart:216-228`) but never read anywhere.

## Current State
Verified during discovery:
- **Real storage**: two SQLCipher DBs via `sqflite_sqlcipher` — `netra_ai.db` (`local_store.dart:18-30`) and `netra_queue.db` (`offline_queue_service.dart:76-94`), WAL + `synchronous=NORMAL`, key in `flutter_secure_storage`/Keystore (`offline_queue_service.dart:188-204`).
- **Dead code**: the entire `LocalStore` write/read/state API (`local_store.dart:219-437`) plus `audit_log_local` (`:161-168`) and the designed states `syncing`/`sync_failed`/`review_received`/`IN_FLIGHT`/`DEAD_LETTER`/`RECEIPT_PENDING` are never set anywhere.
- **Actual lifecycle** is ad-hoc: in-memory mirrors `ApiService.offlineQueue`/`offlinePatients` (`api_service.dart:51-52`) + a JSON payload table; entries removed only on server-confirmed ID (`api_service.dart:845-850`).
- **Silent data-loss paths (5)**: corrupt queue entries deleted with no backup (`api_service.dart:776-780`); 422-rejected de-id referrals dropped, only a counter returned (`referral_uplink_service.dart:192-197`); AI-timeout captures never queued at all (`api_service.dart:654-663`); pre-init captures memory-only with silent catch (`main.dart:19,32-35`); client purge deletes the DB row before the file and swallows `FileSystemException` (`local_store.dart:411-434`).
- **Plaintext surfaces**: consent records in unencrypted SharedPreferences (`consent_service.dart:3,15,83-89`); ephemeral de-id salt fallback breaks pseudonym linkage across restarts silently (`deidentify.dart:39-44`).
- **Client retention is a no-op**: `purgeExpiredData` only deletes `sync_state='acked'` rows, and nothing ever becomes `acked` (`local_store.dart:389-437`, `main.dart:39-46`).

## Desired Outcome
A screening captured on a device survives app restart, phone reboot and a killed process, or the operator is explicitly told it did not. No record is ever deleted, dropped or downgraded to memory-only without an explicit, visible outcome. Persistence state is surfaced in the UI. The repository contains exactly one record lifecycle implementation with a test that actually exists.

## Approach
Choose and execute one of two coherent options during implementation: (A) **activate** `LocalStore` as the single source of truth (transactional insert + enqueue, receipt-before-delete, real state transitions) and delete the competing ad-hoc path, or (B) **delete the dead `LocalStore` API** and promote the simpler `netra_queue.db` queue to a proper documented state machine with the same guarantees. Either way: await boot persistence before accepting captures (or block capture until persistence is confirmed), replace every silent `catch (_)` on a durability path with a surfaced degraded state, stop deleting records without a visible outcome, and move consent records into the encrypted store. Then add the missing integration test that the code already claims exists.

## Scope
- **In**: one authoritative record store with a documented lifecycle; awaited/confirmed boot persistence; elimination of all five silent data-loss paths; UI surfacing of persistence and degraded states; encrypted consent storage; working client retention; a real kill/restart integration test.
- **Out**: sync protocol changes (owned by `sync-reliability`); server-side retention (owned by `sync-reliability`); conflict resolution; the API contract; the SQLite-to-Postgres question; image content handling.

## Boundary Candidates
- Store activation vs deletion decision (which implementation survives)
- Boot/persistence confirmation and degraded-state surfacing
- Deletion policy (what may be removed, under what visible outcome)
- Client-side retention and consent persistence

## Out of Boundary
- Retry/backoff, dead-letter escalation and server retention scheduling (all `sync-reliability`).
- Device-vs-server result comparison (`prediction-consensus`).
- Server database encryption (a decision for `sync-reliability`/security follow-up, not this spec).

## Upstream / Downstream
- **Upstream**: `sqflite_sqlcipher`, `flutter_secure_storage`, `main.dart` bootstrap, `ApiService.restoreQueues()` (`api_service.dart:55-67`).
- **Downstream**: `sync-reliability` (builds retries and dead-letter on top of this lifecycle), `test-ci-coverage-gate` (hosts the new tests).

## Existing Spec Touchpoints
- **Extends**: none (first spec set).
- **Adjacent**: `sync-reliability` depends on this spec's state machine; `test-ci-coverage-gate` provides the harness.

## Constraints
- Do not break `flutter test` (57) or `offline_queue_service_test.dart` — extend rather than replace where possible.
- Encryption posture must not regress: SQLCipher + Keystore is correct today and must stay.
- Any decision to delete `LocalStore` code must be justified and reviewed, per the execution boundary against broad refactoring.
- Never silently discard a record; if something must fail, it fails visibly.
