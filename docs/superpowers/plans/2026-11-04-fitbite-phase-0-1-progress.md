# SDD ledger — plan: docs/superpowers/plans/2026-11-04-fitbite-phase-0-1.md

Branch: phase-0-1 (from main @ 13943d2). Spec: docs/superpowers/specs/2026-11-04-fitbite-design.md
User checkpoint (user-facing promise): STOP before Task 7 for design tone + emulator setup. Task 10 Step 1 is a user approval gate.

## Pre-flight scan

| Pair / task | Produces vs consumes | Finding |
|---|---|---|
| T1 | self | Rename impossible: session cwd is the folder. Ruled below |
| T2→T3 | SecurityConfig created in T2, modified in T3 | OK. T3 Files says "수정" |
| T2 | self | 401 test needs no JWT decoder in T2: custom entry point, OK |
| T3→T4,T5 | CurrentUser.id | OK |
| T4→T5 | ExerciseService.requireAccessible | OK. last-performance route under /exercises lives in workout package; no GET /exercises/{id} so no route clash |
| T4 | self | hidden_at has no API: test sets it through JDBC. OK |
| T5 | self | endedAt nullability unstated. Ruled below |
| T5→T9 | workout and exercise API vs WorkoutApi | Names match |
| T6→T7 | buildApiClient, TokenStore | OK |
| T6→T10 | notification deps | OK |
| T7→T9 | auth_controller modified in T9 | OK |
| T7→T10 | /workouts is placeholder until T11 but T10 needs a way in. Ruled below |
| T8 | self | Tests say both memory DB and file DB. Ruled below |
| T8→T9 | WorkoutStore vs SyncService | T9 needs store methods T8 does not list. Ruled below |
| T8→T10 | store, prefillFor | OK. rest length in local_meta needs get/set: T10 adds them |
| T8→T11 | failed-session retry needs store method. Ruled below |
| T9→T10,T11 | push | OK |
| T11, T12 | self | OK |

Ruling: T1 moves children of flutter_application_1 into app/ and docs/, leaves the empty folder ignored for the user to delete — Windows refuses to rename a process cwd — cost if wrong: one empty folder to remove.
Ruling: First commit on main, all later work on branch phase-0-1, no worktree — empty repo had no other base; Flutter SDK path stays simple — cost if wrong: minimal, branch can be moved.
Ruling: endedAt is required in PUT /workouts (null → 400) — app only sends finished workouts per spec §7 — cost if wrong: small validation change.
Ruling: T10 places the start button on the /workouts placeholder; T11 replaces the placeholder and keeps the button — T10 Step 6 needs an entry point — cost if wrong: small.
Ruling: T8 reopen tests use a temp-file database; other tests use memory — a memory DB cannot prove persistence — cost if wrong: none.
Ruling: T9 adds to WorkoutStore what it needs: pendingSessions, markFailed, removeSession, pendingExercises, markExerciseSynced, replaceExercises, replaceLastPerformance — T8 did not list them and T9 owns that use — cost if wrong: small.
Ruling: T11 adds WorkoutStore.retryFailed(id) — needed by list_showsFailed_withRetryAndDiscard — cost if wrong: small.

## Tasks
Task 1: complete (commits 13943d2, review clean)
Task 1: minor (deferred): iOS bundle id/name and app/README.md heading still flutter_application_1; remove flutter_application_1/ from .gitignore after the user deletes it
Task 1: open item for user: Android SDK cmdline-tools missing, emulator not created (needed by Task 7)
Task 2: complete (commits 5ccfdb5..9e58802, review clean). Spring Boot 4.1.2, springdoc 3.2.0. CI not executed (no remote).
Task 2: minor (deferred): Exception handler may swallow AccessDeniedException/AuthenticationException thrown inside controllers; 401 body hand-written in SecurityConfig rather than via handler; codeFor maps 403/405/415 to INTERNAL_ERROR; generic log.error logs exception message (watch for health values); import order in ErrorResponseTest
Task 3: minor (deferred): stale bearer on public auth endpoints gets 401 (needs BearerTokenResolver); 405/415 labelled INTERNAL_ERROR; no committed tests for startup fail-fast, expired refresh, multibyte >72 password, alg:none; missing-token body equality not asserted; refreshToken_storedHashed weak; no throttling on auth; login holds DB connection through BCrypt; refresh_tokens rows never cleaned; JVM CDS warning in test output
Task 3: fix round 1/5 (2 addressed, 0 open; commits ee39a69..c68bd69)
Task 3: complete (commits 9e58802..c68bd69, review clean)
Task 4: complete (commits c68bd69..7d71982, review clean)
Task 4: minor (deferred): @Size applies before trim (name 50 + padding rejected); dead blank check in ExerciseService.upsert; blank equipment stored as-is; concurrent PUT same new id gives 500 instead of 404
Task 5: minor (deferred): no cap on sets (trust-boundary limit); integrity catch message too specific; concurrent DELETE may give 500 not 404; no test that exercise delete stays blocked under deferred FK; 409 test should assert exact row; no root .gitattributes (CRLF warnings); delayed PUT replay after DELETE recreates session and stale retry overwrites newer (T9: sessions leave the phone after sync, which narrows this; check in final review)
Ruling: Task 5 fix round 1 also covers ExerciseService.upsert (Task 4) — same assigned-ID merge path lets a race overwrite another user's custom exercise; fixing only workouts leaves a sibling bug — cost if wrong: small extra diff.
Task 5: fix round 1/5 (3 addressed, 0 open; commits 447d296..77deead)
Task 5: complete (commits 7d71982..77deead, review clean)
Task 5: minor (deferred): race tests with Hook.join=false may hit the sequential path on a slow machine; insertIfAbsent FK violation (valid token, deleted user) gives 500; opposite-order set ID deadlock gives 500 not 409; dead constructors WorkoutSession(UUID,UUID) and Exercise(UUID,UUID,String,String,BodyPart); full suite ~3.5 min due to second context
Task 6: minor (deferred): no dio timeouts; malformed refresh 200 gives non-ApiError; TokenStore.save two writes not atomic; INTERNET permission missing from main AndroidManifest (release build cannot reach network: must fix by phase 6); sqlite3_flutter_libs is +eol stub: re-evaluate in Task 8
Task 6: fix round 1/5 (1 addressed, 0 open; commits 6b5cef3..950ce37)
Task 6: complete (commits 77deead..950ce37, review clean)
Checkpoint: stopped before Task 7 for user: Android emulator setup and design tone.
User: design tone decided: dark background with lime accent. Emulator not ready yet; session paused here by the user.
Ruling: Remote main had an Initial commit with only README.md; merged it with --allow-unrelated-histories instead of force-pushing, keeping its description line in the new README — cost if wrong: one extra merge commit.
Ruling: Work is pushed on phase-0-1 and main is fast-forwarded to it — the user asked to upload the work and expects README on the default branch; phase 1 final whole-branch review has not run yet — cost if wrong: main holds unfinished phase work, later fixes still land normally.
Task 7 Step 0: theme.dart written (uncommitted), temp lib/theme_preview.dart on emulator-5556, waiting for user approval. Ruling: Task 7 stages files by path instead of the plan's 'git add app' — the working tree holds user changes not from this plan (gradle.properties, pubspec.lock, com/yongbin, linux/macos/web/windows) — cost if wrong: none, they stay uncommitted.
Task 7: minor (deferred): no tests for real AuthRepository/SecureMeStore branches (DioException->NETWORK, corrupt JSON, logout swallow, success paths); router test lacks AuthLoading->splash and live state-change redirects; splash can last ~25s on a bad connection; theme global minimumSize Size(double.infinity,56) throws in Row/AlertDialog (Size.fromHeight is safer); providers.dart line over formatter width; implementer wrote code before tests, RED by mutation
Task 7: fix round 1/5 (2 addressed, 0 open; commits ec75773..9d9cb75)
Task 7: complete (commits 39a39d3..9d9cb75, review clean). Step 5 on emulator-5556: signup -> tabs, restart -> stays signed in, restart with server down -> stays signed in.
Task 7: minor (deferred): native launch splash is still white before the dark theme appears; `_tokens.clear()` throwing in _issueSession would replace the original error; auth_repository_test imports helpers from api_client_test.dart
Ruling: Added .env with new random values and verified against a separate compose project (fitbite-verify) — existing volume fitbite_db-data was initialized with an unknown password and was left untouched rather than reset or re-passworded — cost if wrong: user must restore old password or approve resetting that volume.
Ruling: Stopped after Task 7 instead of continuing to Task 8 — the user asked for the next item, which CLAUDE.md names as Task 7 — cost if wrong: one more prompt to continue.
Task 8: complete (commits 12b2385..dedc272, review clean). Controller checked: debug APK contains libsqlite3.so for arm64-v8a, armeabi-v7a, x86_64 via the sqlite3 build hook; regenerating drift code leaves no diff; analyze clean; 46 tests pass. CI on Linux not run; store not yet run on a device (first in Task 10).
Task 8: minor (deferred): drift stores DateTime as whole seconds, so restSeconds can read up to 1s high and restEndsAt loses sub-seconds (storeDateTimeAsText if it matters); startWorkout check-then-insert has no transaction or partial unique index, and two in-progress rows would make getSingleOrNull throw; hasUnsent counts in-progress sessions (document, Task 11 logout logic depends on it); ensureOwner first-call branch, startNextSet clamp and startWorkout idempotency untested; updateSet/deleteSet have no state guard and do not reset a failed session (Task 9-11 decide); sqlite3_flutter_libs +eol stub looks removable since sqlite3 bundles via build hook (needs user approval to change dependencies)
