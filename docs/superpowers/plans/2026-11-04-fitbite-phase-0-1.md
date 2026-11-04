# FitBite 0~1단계 구현 계획: 기반과 운동 기록

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 에뮬레이터 앱에서 가입하고 운동 한 번을 끝까지 기록하며, 인터넷이 끊겨도 기록을 잃지 않고 복구 후 서버에 동기화한다.

**Architecture:** Spring Boot 서버 하나와 PostgreSQL, Flutter 앱으로 구성한다. 운동 기록은 항상 폰(drift)에 먼저 저장하고, 세션 전체를 `PUT /workouts/{id}`로 보낸다. 앱과 서버를 함께 동작시키며 얇게 관통하는 순서로 진행한다.

**Tech Stack:** Java 21, Spring Boot(Initializr 최신 안정판), Spring Data JPA, Spring Security + OAuth2 Resource Server(JWT), Flyway, springdoc, JUnit, Testcontainers, PostgreSQL 17, Flutter 3.47.9, Riverpod, go_router, dio, drift, flutter_secure_storage, flutter_local_notifications

**Spec:** `docs/superpowers/specs/2026-11-04-fitbite-design.md` (Task 1에서 옮긴 뒤의 경로)

## 로드맵

| 계획 | 설계 문서 단계 | 상태 |
|---|---|---|
| 이 문서 | 0 기반, 1 운동 기록 | 작성됨 |
| 다음 계획 | 2 운동 분석, 3 인바디 | 이 계획 완료 후 작성 |
| 그다음 계획 | 4 식단·칼로리, 5 마무리(계정 삭제 포함) | 앞 계획 완료 후 작성 |
| 마지막 계획 | 6 배포·공개(데모 계정 포함), 7 실사용 | 앞 계획 완료 후 작성 |

## Global Constraints

- 저장소 최상위의 `CLAUDE.md` 규칙을 모두 따른다.
- 시각은 UTC로 저장하고 날짜 조회는 Asia/Seoul로 계산한다.
- 단위는 kg이며 이름에 드러낸다(`weight_kg`, `weightKg`).
- 사용자 데이터 테이블의 `user_id`와 하위 테이블 FK에는 `ON DELETE CASCADE`를 쓴다. 5단계 계정 삭제의 전제다.
- 다른 사용자의 데이터를 요청하면 404로 답한다.
- 로그에 건강 수치, 토큰, 비밀번호를 남기지 않는다.
- 데모 계정, 계정 삭제, 유산소, 통계는 이 계획에 포함하지 않는다.
- 앱 패키지명은 `fitbite`, Android applicationId는 `com.fitbite.app`, 서버 패키지는 `com.fitbite.<기능>`이다.
- 이 PC의 Git Bash에서 Flutter는 `/e/projects/fitbite/flutter/bin/flutter`로 실행한다. 아래에서는 `$FLUTTER`로 적는다.
- 커밋 메시지는 Conventional Commits 형식에 한국어 설명을 쓰고, 끝에 다음 줄을 넣는다: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Review Focus

1. **타인의 UUID로 저장:** 다른 사용자의 세션 ID로 `PUT`하거나 다른 사용자의 운동·세트 ID를 넣으면, 덮어쓰지 않고 404 또는 409로 답한다. (Task 5)
2. **수정 재전송:** 세트 하나를 지우고 세션을 다시 보내면 서버에서도 그 세트가 사라지고, 같은 요청을 반복해도 중복되지 않는다. (Task 5)
3. **토큰 만료와 동기화:** 재발급까지 실패해 로그아웃되어도 미전송 운동은 남아 있다. 같은 계정으로 다시 로그인하면 전송되고, 다른 계정으로 로그인해도 그 계정에 섞여 올라가지 않는다. (Task 8, 9)
4. **운동 중 앱 강제 종료:** 다시 열면 진행 중인 운동, 입력한 세트, 남은 휴식 시간이 복구된다. 그사이 타이머가 끝났으면 0초로 표시된다. (Task 8, 10)
5. **알림 권한 거부:** 알림이나 정확한 알람 권한을 거부해도 화면의 타이머와 기록은 정상 동작한다. (Task 10)

---

### Task 1: 저장소 정리와 Android 에뮬레이터 확인

**Files:**
- Move: `flutter_application_1/` → `app/`, `app/docs/` → `docs/`
- Create: `.gitignore`(최상위), `.env.example`
- Modify: `CLAUDE.md`, `app/pubspec.yaml`, `app/android/app/build.gradle.kts`, `app/test/widget_test.dart`
- Delete: `app/linux/`, `app/macos/`, `app/windows/`, `app/web/`

**Interfaces:**
- Produces: 저장소 최상위 `E:\projects\fitbite\`, 앱 패키지 `fitbite`

- [ ] **Step 1: 폴더를 정리한다**

IDE를 닫고 저장소 최상위에서 작업한다. 폴더가 사용 중이라 이름 변경이 실패하면 사용자에게 IDE와 세션 종료를 요청한다. 삭제할 네 플랫폼 폴더는 Flutter가 생성한 내용뿐이며, `flutter create --platforms`로 복구할 수 있다.

- [ ] **Step 2: 이름을 바꾼다**

`pubspec.yaml`의 `name`을 `fitbite`로, `build.gradle.kts`의 `namespace`와 `applicationId`를 `com.fitbite.app`으로 바꾼다. Kotlin `MainActivity`의 패키지와 경로도 맞춘다. `CLAUDE.md`의 설계 문서 경로를 `docs/superpowers/specs/2026-11-04-fitbite-design.md`로 고친다.

- [ ] **Step 3: 최상위 `.gitignore`와 `.env.example`을 만든다**

`.gitignore`에는 `flutter/`, `.env`, `backend/build/`, `backend/.gradle/`를 넣는다. `.env.example`에는 `POSTGRES_PASSWORD=`, `APP_JWT_SECRET=`, `APP_INVITE_CODE=`를 넣는다.

- [ ] **Step 4: 앱을 확인한다**

Run: `cd app && $FLUTTER pub get && $FLUTTER analyze && $FLUTTER test`
Expected: 분석 오류 없음, 테스트 통과

- [ ] **Step 5: 에뮬레이터를 확인한다**

Run: `$FLUTTER doctor -v`, `$FLUTTER emulators`
없으면 `$FLUTTER emulators --create --name fitbite`로 만들고, `$FLUTTER emulators --launch fitbite` 후 `cd app && $FLUTTER run -d emulator-5554`를 실행한다.
Expected: 에뮬레이터에 기본 앱이 뜬다. 라이선스나 SDK 문제로 안 되면 멈추고 사용자에게 필요한 조치를 알린다.

- [ ] **Step 6: Git을 시작하고 커밋한다**

```bash
git init -b main
git add .gitignore .env.example CLAUDE.md docs app
git status --short | grep -E '^A +flutter/' && echo "SDK 포함됨: 중단"
git commit -m "chore: 저장소 구조 정리"
```
Expected: `flutter/`와 `.env`가 커밋에 없다. GitHub 원격 저장소 생성과 push는 사용자 요청이 있을 때만 한다.

---

### Task 2: 서버 뼈대, 로컬 DB, 공통 오류, CI

**Files:**
- Create: `docker-compose.yml`, `.github/workflows/ci.yml`, `backend/`(Initializr 생성물)
- Create: `backend/src/main/resources/application.yml`
- Create: `backend/src/main/java/com/fitbite/common/ApiException.java`, `GlobalExceptionHandler.java`
- Test: `backend/src/test/java/com/fitbite/IntegrationTest.java`, `common/ErrorResponseTest.java`

**Interfaces:**
- Produces: `IntegrationTest`: 모든 통합 테스트의 부모. 실제 PostgreSQL 17 컨테이너와 `MockMvc`를 제공한다.
- Produces: `ApiException(HttpStatus status, String code, String message)`
- Produces: 오류 응답은 RFC 9457 `ProblemDetail`에 `code` 속성을 더한 형식이다. 코드: `VALIDATION_ERROR` 400, `UNAUTHORIZED` 401, `NOT_FOUND` 404, `CONFLICT` 409, `INTERNAL_ERROR` 500

- [ ] **Step 1: 서버를 생성한다**

start.spring.io에서 Gradle(Kotlin DSL), Java 21, 패키지 `com.fitbite`로 만들고 web, data-jpa, postgresql, flyway, security, oauth2-resource-server, validation, testcontainers를 포함한다. `springdoc-openapi-starter-webmvc-ui`는 사용하는 Boot 버전과 호환되는 판을 추가한다. Gradle toolchain을 Java 21로 고정한다.

- [ ] **Step 2: 로컬 DB를 정의한다**

`docker-compose.yml`에 `postgres:17` 서비스 `db`, 포트 5432, 볼륨, `.env`의 `POSTGRES_PASSWORD`를 쓴다. `application.yml`은 `ddl-auto: validate`, `open-in-view: false`, `hibernate.jdbc.time_zone: UTC`, 비밀값은 환경 변수로 받는다.

- [ ] **Step 3: 실패하는 테스트를 쓴다**

`ErrorResponseTest`:
- `apiDocs_isPublic`: `GET /v3/api-docs` → 200
- `unknownRouteWithoutToken_returns401WithCode`: 401, `$.code == "UNAUTHORIZED"`
- `apiException_isConvertedToProblemDetail`: 테스트 전용 컨트롤러가 `ApiException(CONFLICT, "CONFLICT", "x")`를 던지면 409, `$.code == "CONFLICT"`
- `unexpectedException_hidesDetails`: 런타임 예외 메시지 `"secret"`이 응답에 없고 500, `$.code == "INTERNAL_ERROR"`

- [ ] **Step 4: 테스트 실패를 확인한다**

Run: `cd backend && ./gradlew test`
Expected: FAIL. `GlobalExceptionHandler`가 없다.

- [ ] **Step 5: 구현한다**

`GlobalExceptionHandler`(`@RestControllerAdvice`)와 stateless `SecurityConfig`를 만든다. 공개 경로는 `/v3/api-docs/**`, `/swagger-ui/**`, `/api/v1/auth/**`이고, CSRF는 끈다. 401 응답도 같은 형식으로 쓴다. JWT 설정은 Task 3에서 완성한다.

- [ ] **Step 6: 테스트 통과를 확인한다**

Run: `cd backend && ./gradlew test`
Expected: PASS

- [ ] **Step 7: CI를 만든다**

`ci.yml`은 push와 PR에서 서버(`temurin 21`, `./gradlew test`)와 앱(Flutter 3.47.9, `flutter analyze`, `flutter test`)을 실행한다. 원격 저장소 전까지 실행 검증은 불가능하므로, 완료 보고에 그렇게 적는다.

- [ ] **Step 8: 커밋한다**

```bash
git add docker-compose.yml .github backend
git commit -m "feat(backend): 서버 뼈대와 공통 오류 응답 추가"
```

---

### Task 3: 가입, 로그인, 토큰 API

**Files:**
- Create: `backend/src/main/resources/db/migration/V1__users.sql`
- Create: `backend/src/main/java/com/fitbite/auth/` 아래 `AuthController`, `AuthService`, `TokenService`, `User`, `Consent`, `RefreshToken`과 각 Repository, `SecurityConfig` 수정
- Test: `backend/src/test/java/com/fitbite/auth/AuthApiTest.java`

**Interfaces:**
- Consumes: `IntegrationTest`, `ApiException`
- Produces:
  - `POST /api/v1/auth/signup` body `SignupRequest(email, password, nickname, inviteCode, consentHealthData)` → 201 `TokenResponse`
  - `POST /api/v1/auth/login` body `LoginRequest(email, password)` → 200 `TokenResponse`
  - `POST /api/v1/auth/refresh` body `RefreshRequest(refreshToken)` → 200 `TokenResponse`
  - `POST /api/v1/auth/logout` body `RefreshRequest` → 204
  - `GET /api/v1/me` → `MeResponse(UUID id, String email, String nickname)`
  - `TokenResponse(String accessToken, String refreshToken, long expiresInSeconds)`
  - `CurrentUser.id(Jwt jwt): UUID`: JWT `sub`에서 사용자 ID를 얻는 유일한 방법

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`AuthApiTest`:
- `signup_returnsTokens_andStoresConsent`: 201. `consents`에 `type=HEALTH_DATA`, `version="2026-11-v1"` 한 행
- `signup_wrongInviteCode_403`: `$.code == "INVALID_INVITE_CODE"`
- `signup_withoutConsent_400`: `$.code == "CONSENT_REQUIRED"`, 사용자 미생성
- `signup_duplicateEmail_409`: 대소문자만 다른 이메일도 `$.code == "EMAIL_TAKEN"`
- `signup_shortPassword_400`: 7자 → `VALIDATION_ERROR`
- `password_isStoredHashed`: `password_hash`가 평문과 다르고 `$2`로 시작
- `login_wrongPasswordAndUnknownEmail_sameResponse`: 둘 다 401, `INVALID_CREDENTIALS`, 본문 동일
- `me_returnsCurrentUser`: 토큰으로 200, 없으면 401
- `refresh_rotates`: 새 토큰 발급 후 이전 토큰은 401 `INVALID_REFRESH_TOKEN`
- `refreshToken_storedHashed`: DB의 `token_hash`가 원문과 다름
- `logout_revokes`: 로그아웃 후 해당 재발급 토큰은 401
- `expiredAccessToken_401`

- [ ] **Step 2: 테스트 실패를 확인한다**

Run: `cd backend && ./gradlew test --tests '*AuthApiTest'`
Expected: FAIL. 경로와 테이블이 없다.

- [ ] **Step 3: 구현한다**

- `V1__users.sql`: 설계 문서 6장의 `users`, `consents`, `refresh_tokens`. ID는 UUID, 이메일은 소문자로 저장하며 고유.
- JWT는 Resource Server의 Nimbus 인코더·디코더와 HS256을 쓰고, 비밀키는 `APP_JWT_SECRET`에서 읽는다. 액세스 토큰 30분, 재발급 토큰 30일.
- 재발급 토큰은 `SecureRandom` 32바이트, DB에는 SHA-256만 저장한다.
- 초대 코드는 `APP_INVITE_CODE`와 `MessageDigest.isEqual`로 비교한다.
- 비밀번호는 8~72자, BCrypt.

```java
// ponytail: 재사용 탐지 없이 이전 토큰만 거부한다. 응답 유실 재시도로 잠기는 일을 피하려는 선택. 출시 시 토큰 계열 폐기를 검토한다.
```

- [ ] **Step 4: 테스트 통과를 확인한다**

Run: `cd backend && ./gradlew test`
Expected: PASS

- [ ] **Step 5: 커밋한다**

```bash
git add backend
git commit -m "feat(auth): 초대 코드 가입과 JWT 로그인 추가"
```

---

### Task 4: 운동 목록 API

**Files:**
- Create: `backend/src/main/resources/db/migration/V2__exercises.sql`
- Create: `backend/src/main/java/com/fitbite/exercise/` 아래 `Exercise`, `ExerciseRepository`, `ExerciseService`, `ExerciseController`
- Test: `backend/src/test/java/com/fitbite/exercise/ExerciseApiTest.java`

**Interfaces:**
- Consumes: `CurrentUser.id`
- Produces:
  - `GET /api/v1/exercises` → `List<ExerciseResponse(UUID id, String name, String equipment, BodyPart bodyPart, boolean custom)>`
  - `PUT /api/v1/exercises/{id}` body `ExerciseUpsertRequest(name, equipment, bodyPart)` → 200 `ExerciseResponse`
  - `enum BodyPart { CHEST, BACK, SHOULDERS, LEGS, ARMS, CORE, FULL_BODY }`
  - `ExerciseService.requireAccessible(UUID userId, UUID exerciseId): Exercise`: 없거나 접근 불가면 404

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`ExerciseApiTest`:
- `seed_hasAtLeast50_andEveryBodyPart`: 50개 이상, `BodyPart` 값 모두 포함
- `list_returnsSystemAndOwnOnly`: 사용자 A의 운동은 B의 목록에 없음
- `put_createsCustom_thenUpdates_sameId`: 두 번 PUT해도 한 행, 이름 갱신, `custom=true`
- `put_otherUsersExercise_404`: 내용 변경 없음
- `put_systemExercise_404`
- `put_blankName_400`, `put_nameOver50_400`
- `list_excludesHidden`: `hidden_at` 설정 행 제외

- [ ] **Step 2: 테스트 실패를 확인한다**

Run: `cd backend && ./gradlew test --tests '*ExerciseApiTest'`
Expected: FAIL

- [ ] **Step 3: 구현한다**

`V2__exercises.sql`에 설계 문서 6장의 `exercises`를 만들고, 많이 쓰는 근력 운동 50개 이상을 한국어 이름, 기구, 부위와 함께 넣는다. 기본 운동의 ID는 `00000000-0000-0000-0000-0000000000NN` 형식의 고정 값이다.

- [ ] **Step 4: 테스트 통과를 확인한다**

Run: `cd backend && ./gradlew test`
Expected: PASS

- [ ] **Step 5: 커밋한다**

```bash
git add backend
git commit -m "feat(exercise): 운동 목록과 사용자 정의 운동 API 추가"
```

---

### Task 5: 운동 세션 API와 지난 기록 조회

**Files:**
- Create: `backend/src/main/resources/db/migration/V3__workouts.sql`
- Create: `backend/src/main/java/com/fitbite/workout/` 아래 `WorkoutSession`, `WorkoutSet`, `WorkoutRepository`, `WorkoutService`, `WorkoutController`, `LastPerformanceQuery`
- Test: `backend/src/test/java/com/fitbite/workout/WorkoutApiTest.java`, `LastPerformanceApiTest.java`

**Interfaces:**
- Consumes: `ExerciseService.requireAccessible`, `CurrentUser.id`
- Produces:
  - `PUT /api/v1/workouts/{id}` body `WorkoutUpsertRequest(Instant startedAt, Instant endedAt, String memo, List<SetRequest> sets)` → 200 `WorkoutResponse`
  - `SetRequest(UUID id, UUID exerciseId, int orderNo, BigDecimal weightKg, int reps, Instant completedAt, Integer restSeconds)`
  - `GET /api/v1/workouts?from=YYYY-MM-DD&to=YYYY-MM-DD` → `List<WorkoutSummary(UUID id, Instant startedAt, Instant endedAt, int setCount, List<String> exerciseNames)>`, 최신순
  - `GET /api/v1/workouts/{id}` → `WorkoutResponse(UUID id, Instant startedAt, Instant endedAt, String memo, List<SetResponse> sets)`. `SetResponse`는 `SetRequest`에 `String exerciseName`을 더한 값
  - `DELETE /api/v1/workouts/{id}` → 204
  - `GET /api/v1/exercises/last-performance` → `List<LastPerformance(UUID exerciseId, Instant performedAt, List<LastSet(int setNumber, BigDecimal weightKg, int reps)> sets)>`

- [ ] **Step 1: 저장 테스트를 쓴다**

`WorkoutApiTest`:
- `put_savesSessionAndSets_inOrder`
- `put_sameRequestTwice_noDuplicates`: 세션 1행, 세트 수 동일
- `put_withSetRemoved_deletesThatSet`
- `put_otherUsersSessionId_404_andNotOverwritten`
- `put_otherUsersCustomExercise_404`
- `put_setIdBelongingToOtherSession_409`: `$.code == "CONFLICT"`, 상대 세트 불변
- `put_invalidValues_400`: 각각 `weightKg=-1`, `weightKg=1000.01`, `reps=0`, `reps=1001`, `restSeconds=-1`, `endedAt < startedAt`, `sets` 비어 있음, `orderNo` 중복
- `put_fractionalWeight_roundTrips`: `2.5`와 `1.25` 유지
- `put_nullRestSeconds_allowed`

- [ ] **Step 2: 조회·삭제 테스트를 쓴다**

- `get_otherUsersSession_404`, `delete_otherUsersSession_404_andKept`
- `delete_removesSets_secondDelete_404`
- `list_usesSeoulDate`: `2026-11-03T15:30:00Z`(서울 11월 4일 00:30) 세션은 `from=to=2026-11-04` 결과에 있고 `2026-11-03` 결과에 없음
- `list_excludesOtherUsers`

- [ ] **Step 3: 지난 기록 테스트를 쓴다**

`LastPerformanceApiTest`:
- `returnsMostRecentSessionPerExercise`: 스쿼트와 벤치가 서로 다른 세션이어도 각 운동의 최근 세션 값
- `setNumber_isPerExercise`: 세션 `order_no`가 1(스쿼트), 2(벤치), 3(스쿼트)이면 스쿼트 `setNumber`는 1, 2
- `excludesOtherUsers`
- `noHistory_returnsEmptyList`

- [ ] **Step 4: 테스트 실패를 확인한다**

Run: `cd backend && ./gradlew test --tests '*Workout*' --tests '*LastPerformance*'`
Expected: FAIL

- [ ] **Step 5: 구현한다**

- `V3__workouts.sql`: 설계 문서 6장. `weight_kg numeric(6,2)`, `workout_sets.exercise_id`는 삭제를 막는 FK, `(session_id, order_no)` 고유.
- `PUT`은 트랜잭션 안에서 소유자 확인 → 세트 ID 충돌 확인 → 기존 세트 삭제 후 flush → 새 세트 저장 순서다. 마지막 수정이 우선한다.
- 날짜 조회는 `LocalDate`를 Asia/Seoul로 해석해 `[from 00:00, to+1 00:00)` UTC 범위로 바꾼다.
- 지난 기록은 `row_number()` 네이티브 쿼리로 구현한다.

- [ ] **Step 6: 테스트 통과를 확인한다**

Run: `cd backend && ./gradlew test`
Expected: PASS

- [ ] **Step 7: Swagger를 확인한다**

서버를 로컬 DB로 띄우고 `/swagger-ui/index.html`에 Task 3~5 경로가 모두 보이는지 확인한다.

- [ ] **Step 8: 커밋한다**

```bash
git add backend
git commit -m "feat(workout): 세션 저장, 조회, 지난 기록 API 추가"
```

---

### Task 6: 앱 기반과 API 클라이언트

**Files:**
- Modify: `app/pubspec.yaml`, `app/lib/main.dart`, `app/android/app/src/debug/AndroidManifest.xml`
- Create: `app/lib/core/api/api_client.dart`, `api_error.dart`, `app/lib/core/auth/token_store.dart`, `app/lib/core/uuid.dart`
- Test: `app/test/core/api_client_test.dart`, `app/test/core/uuid_test.dart`

**Interfaces:**
- Produces:
  - `abstract class TokenStore { Future<Tokens?> read(); Future<void> save(Tokens); Future<void> clear(); }`와 `SecureTokenStore`, `Tokens(accessToken, refreshToken)`
  - `Dio buildApiClient({required String baseUrl, required TokenStore tokens, required void Function() onSignedOut})`
  - `ApiError(int? status, String code, String message)`: 네트워크 실패는 `status == null`, `code == 'NETWORK'`
  - `String newUuid()`: UUID v4

- [ ] **Step 1: 의존성을 추가한다**

`flutter_riverpod`, `go_router`, `dio`, `drift`, `sqlite3_flutter_libs`, `path_provider`, `path`, `flutter_secure_storage`, `flutter_local_notifications`, `timezone`, dev에 `drift_dev`, `build_runner`.
`API_BASE_URL`은 `--dart-define`으로 받고 기본값은 `http://10.0.2.2:8080/api/v1`이다. HTTP 허용은 debug 매니페스트의 `usesCleartextTraffic`에만 둔다.

- [ ] **Step 2: 실패하는 테스트를 쓴다**

가짜 `HttpClientAdapter`를 쓴다.
- `attachesBearerToken`
- `on401_refreshesOnce_andRetries`: 재시도 요청에 새 토큰, 새 토큰 저장
- `concurrent401s_refreshOnlyOnce`: 동시 요청 3개, 재발급 호출 1회, 모두 성공
- `refreshFails401_clearsTokens_andCallsOnSignedOut`
- `refreshNetworkFailure_keepsTokens`: 토큰 유지, `onSignedOut` 미호출
- `problemDetail_mapsToApiError`
- `noConnection_mapsToNetworkApiError`
- `newUuid_isV4Format_andUnique`: 형식 정규식, 1000개 중복 없음

- [ ] **Step 3: 테스트 실패를 확인한다**

Run: `cd app && $FLUTTER test test/core`
Expected: FAIL

- [ ] **Step 4: 구현한다**

재발급 요청은 인터셉터가 없는 별도 `Dio`로 보내고, 진행 중인 `Future`를 공유해 한 번만 호출한다. `newUuid`는 `Random.secure()`로 만든다.

- [ ] **Step 5: 테스트 통과를 확인한다**

Run: `cd app && $FLUTTER analyze && $FLUTTER test`
Expected: PASS

- [ ] **Step 6: 커밋한다**

```bash
git add app
git commit -m "feat(app): API 클라이언트와 토큰 저장 추가"
```

---

### Task 7: 가입·로그인 화면과 앱 뼈대

**Files:**
- Create: `app/lib/app.dart`, `app/lib/features/auth/data/auth_repository.dart`, `app/lib/features/auth/presentation/auth_controller.dart`, `login_screen.dart`, `signup_screen.dart`, `app/lib/features/home/presentation/shell_screen.dart`
- Test: `app/test/features/auth/signup_screen_test.dart`, `login_screen_test.dart`, `app/test/app_router_test.dart`

**Interfaces:**
- Consumes: `buildApiClient`, `TokenStore`
- Produces:
  - `AuthRepository`: `signup(...)`, `login(email, password)`, `logout()`, `me(): Future<Me>`
  - `authControllerProvider`: 상태 `AuthState.loading | signedOut | signedIn(Me me)`
  - 경로: `/login`, `/signup`, `/home`, `/workouts`, `/meals`, `/body`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

- `signup_submitDisabled_untilConsentChecked`
- `signup_showsConsentText`: 수집 항목(운동 기록, 식단, 체성분)과 목적이 보임
- `signup_invalidInviteCode_showsKoreanError`
- `login_wrongCredentials_showsKoreanError`
- `login_noNetwork_showsConnectionError`
- `router_signedOut_redirectsToLogin`, `router_signedIn_opensHomeWithFourTabs`: 탭은 홈, 운동, 식단, 인바디

- [ ] **Step 2: 테스트 실패를 확인한다**

Run: `cd app && $FLUTTER test test/features/auth test/app_router_test.dart`
Expected: FAIL

- [ ] **Step 3: 구현한다**

식단과 인바디 탭은 후속 단계까지 "준비 중"으로 둔다. 앱 시작 시 토큰이 있으면 `me()`를 부른다. 네트워크 실패면 저장해 둔 사용자로 로그인 상태를 유지해, 오프라인에서도 운동을 시작할 수 있게 한다. `Me`는 `flutter_secure_storage`에 함께 저장한다.

- [ ] **Step 4: 테스트 통과를 확인한다**

Run: `cd app && $FLUTTER analyze && $FLUTTER test`
Expected: PASS

- [ ] **Step 5: 에뮬레이터에서 확인한다**

`docker compose up -d db`, 서버 실행, 앱 실행 후 가입 → 탭 화면, 앱 재시작 → 로그인 유지를 확인한다.

- [ ] **Step 6: 커밋한다**

```bash
git add app
git commit -m "feat(auth): 가입, 로그인 화면과 탭 구조 추가"
```

---

### Task 8: 폰 저장소와 세트 기본값 규칙

**Files:**
- Create: `app/lib/features/workout/data/local_db.dart`, `workout_store.dart`, `app/lib/features/workout/domain/prefill.dart`, `models.dart`
- Test: `app/test/features/workout/workout_store_test.dart`, `prefill_test.dart`

**Interfaces:**
- Consumes: `newUuid`
- Produces:
  - `SessionSyncState { inProgress, pending, failed }`
  - `WorkoutStore`:
    - `Future<void> ensureOwner(String userId)`: 저장된 소유자와 다르면 모든 로컬 데이터 삭제
    - `Future<ActiveWorkout?> activeWorkout()`
    - `Future<ActiveWorkout> startWorkout()`
    - `Future<LocalSet> completeSet({exerciseId, weightKg, reps})`: 다음 `orderNo`, 현재 시각, 휴식 상태 저장
    - `Future<void> startNextSet()`: 직전 세트의 `restSeconds` 저장, 휴식 상태 해제
    - `Future<void> updateSet(id, weightKg, reps, restSeconds)`, `Future<void> deleteSet(id)`
    - `Future<void> setRestEndsAt(DateTime endsAt)`
    - `Future<void> finishWorkout()`: 세트가 없으면 세션 삭제, 있으면 `pending`으로 바꾸고 지난 기록 캐시 갱신
    - `Future<void> discardWorkout(id)`
    - `Future<List<Exercise>> searchExercises(String query)`, `Future<Exercise> addCustomExercise(name, equipment, bodyPart)`
    - `Future<List<LastSet>> lastSets(exerciseId)`
    - `Future<bool> hasUnsent()`, `Future<void> clearAll()`
  - `Prefill? prefillFor(List<LastSet> last, List<LocalSet> todayForExercise)`, `Prefill(double weightKg, int reps)`
  - `WorkoutStore`는 `DateTime Function() now`를 주입받는다.

- [ ] **Step 1: 기본값 규칙 테스트를 쓴다**

`prefill_test.dart`:

| 지난번 | 오늘 | 다음 세트 기본값 |
|---|---|---|
| 없음 | 없음 | `null` |
| 60×10, 70×8 | 없음 | 60×10 |
| 60×10, 70×8 | 60×10 | 70×8 |
| 60×10, 70×8 | 65×10 | 65×10 |
| 60×10, 70×8, 80×6 | 65×10, 70×8 | 70×8 |
| 60×10, 70×8, 80×6 | 65×10, 65×10 | 65×10 (한번 바꾸면 이후 세트는 오늘 값을 따름) |
| 60×10, 70×8, 80×6 | 60×10, 70×8 | 80×6 |
| 60×10 | 60×10 | 60×10 |
| 없음 | 50×12 | 50×12 |

- [ ] **Step 2: 저장소 테스트를 쓴다**

`NativeDatabase.memory()`로 시험한다.
- `completeSet_persistsImmediately`: 저장소를 새로 열어도 세트와 세션 존재(파일 DB 사용)
- `reopen_restoresActiveWorkout_andRestEndsAt`
- `startNextSet_recordsRestSeconds`: 세트 완료 후 75초 뒤 호출하면 `restSeconds == 75`
- `completeSetWithoutStartNext_leavesRestNull`
- `finish_withNoSets_deletesSession`
- `finish_setsPending_andUpdatesLastSets`
- `ensureOwner_differentUser_wipesData`, `ensureOwner_sameUser_keepsPending`
- `search_matchesKoreanSubstring`
- `addCustomExercise_marksPendingSync`

- [ ] **Step 3: 테스트 실패를 확인한다**

Run: `cd app && $FLUTTER test test/features/workout`
Expected: FAIL. 호스트에서 SQLite 로드가 실패하면 테스트 실패가 아닌 환경 문제이므로, drift 문서대로 테스트용 라이브러리를 설정하고 CI 리눅스에는 `libsqlite3-dev`를 추가한다.

- [ ] **Step 4: 구현한다**

`prefillFor`의 계산은 다음과 같다. 오늘 세트를 순서대로 지난번 같은 번호 세트와 비교한다.

```text
오늘 세트가 없으면                  → last(1), 지난번도 없으면 null
오늘 세트가 지난번과 하나라도 다르면 → 오늘 마지막 세트
지난번에 다음 번호 세트가 없으면     → 오늘 마지막 세트
그 외                               → last(다음 번호)
```

테이블은 `local_exercises`(`syncPending` 포함), `local_sessions`(`syncState`, `failureMessage`, `restEndsAt`), `local_sets`, `last_performance_cache`, `local_meta`(소유자)다.

- [ ] **Step 5: 테스트 통과를 확인한다**

Run: `cd app && $FLUTTER analyze && $FLUTTER test`
Expected: PASS

- [ ] **Step 6: 커밋한다**

```bash
git add app
git commit -m "feat(workout): 폰 저장소와 세트 기본값 규칙 추가"
```

---

### Task 9: 동기화

**Files:**
- Create: `app/lib/features/workout/data/workout_api.dart`, `sync_service.dart`
- Modify: `app/lib/features/auth/presentation/auth_controller.dart`
- Test: `app/test/features/workout/sync_service_test.dart`, `app/test/features/auth/logout_test.dart`

**Interfaces:**
- Consumes: `WorkoutStore`, `Dio`, `ApiError`, Task 4·5 API
- Produces:
  - `SyncService.push(): Future<void>`: 동시 호출 시 하나로 합침
  - `SyncService.refreshCatalog(): Future<void>`
  - `SyncService.start()`, `stop()`: 앱 복귀와 30초 주기(미전송이 있을 때만) 트리거
  - `WorkoutApi`: `putExercise`, `putWorkout`, `listWorkouts(from, to)`, `getWorkout(id)`, `deleteWorkout(id)`, `listExercises`, `lastPerformance`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

- `push_sendsCustomExercisesBeforeSessions`: 호출 순서 검증
- `push_success_removesSessionFromLocal`
- `push_networkError_keepsPending_stopsWithoutError`
- `push_400or404_marksFailed_keepsData_otherSessionsContinue`
- `push_failedSessions_notRetriedAutomatically`
- `push_concurrentCalls_sendOnce`
- `push_serverSeesSameIdOnRetry`: 응답 유실 후 재시도에 같은 UUID 사용
- `refreshCatalog_replacesExercises_keepsPendingCustom`
- `refreshCatalog_keepsNewerLocalLastPerformance`: 미전송 세션의 지난 기록이 서버 값으로 덮이지 않음
- `refreshCatalog_networkError_keepsCache`
- `signedOutByExpiry_keepsPending`: 재발급 실패 후 다음 로그인(같은 사용자)에 전송
- `loginAsOtherUser_doesNotUploadPreviousData`
- `logout_withUnsent_requiresConfirm`, `logout_confirmed_clearsLocal`

- [ ] **Step 2: 테스트 실패를 확인한다**

Run: `cd app && $FLUTTER test test/features/workout/sync_service_test.dart test/features/auth/logout_test.dart`
Expected: FAIL

- [ ] **Step 3: 구현한다**

- 전송에 성공한 세션은 폰에서 지운다. 지난 기록은 캐시에 남아 있다.
- 로그인 직후 `ensureOwner(me.id)` → `refreshCatalog()` → `push()` 순서로 호출한다.
- 연결 감지 패키지 없이 앱 복귀와 30초 주기로 재시도한다.
- 임시 로그아웃 버튼은 홈 앱바에 둔다. 5단계 설정 화면으로 옮긴다.

- [ ] **Step 4: 테스트 통과를 확인한다**

Run: `cd app && $FLUTTER analyze && $FLUTTER test`
Expected: PASS

- [ ] **Step 5: 커밋한다**

```bash
git add app
git commit -m "feat(workout): 미전송 운동 자동 동기화 추가"
```

---

### Task 10: 운동 진행 화면과 휴식 타이머

**Files:**
- Create: `app/lib/features/workout/presentation/workout_controller.dart`, `active_workout_screen.dart`, `exercise_picker_sheet.dart`, `rest_timer_panel.dart`, `app/lib/features/workout/domain/rest_timer.dart`, `app/lib/core/notifications.dart`
- Modify: `app/android/app/src/main/AndroidManifest.xml`, `app/lib/app.dart`
- Test: `app/test/features/workout/rest_timer_test.dart`, `active_workout_screen_test.dart`

**Interfaces:**
- Consumes: `WorkoutStore`, `prefillFor`, `SyncService.push`
- Produces:
  - `RestTimer.remaining(DateTime endsAt, DateTime now): Duration`: 0 미만이면 0
  - `abstract class RestNotifier { Future<void> schedule(DateTime endsAt); Future<void> cancel(); }`
  - 기본 90초, ±30초, 최소 30초. 마지막 길이는 `local_meta`에 저장
  - 경로: `/workout/active`

- [ ] **Step 1: 시안을 사용자에게 확인받는다**

설계 문서 9장에 따라 운동 진행 화면 시안을 먼저 보여 주고 승인받는다. 승인 전에는 다음 단계로 넘어가지 않는다. 시안에는 지난 기록, 무게·횟수 입력, 세트 완료, 휴식 타이머, 오늘의 세트 목록을 넣는다.

- [ ] **Step 2: 실패하는 테스트를 쓴다**

- `remaining_clampsAtZero`
- `remaining_correctAfterLongPause`: `endsAt`만으로 계산
- `sameAsLastTime_recordsWithOneTap`: 기본값이 채워진 상태에서 "세트 완료" 한 번으로 저장
- `completeSet_showsTimer_andSchedulesNotification`
- `nextSetStart_savesRest_cancelsNotification_hidesTimer`
- `adjustTimer_plusMinus30_clampsAt30_remembersLength`
- `prefill_appliedAfterExerciseSelect`
- `notifierThrows_stillRecordsSetAndRunsTimer`: 권한 거부를 가정
- `reopen_restoresScreenAndTimer`
- `finishWithNoSets_discardsWithoutPending`
- `finish_triggersPush_andReturnsHome`
- `editAndDeleteSet_duringWorkout`
- `weightInput_acceptsDecimal_rejectsNegative`
- `pickExercise_searchAndAddCustomOffline`

- [ ] **Step 3: 테스트 실패를 확인한다**

Run: `cd app && $FLUTTER test test/features/workout/rest_timer_test.dart test/features/workout/active_workout_screen_test.dart`
Expected: FAIL

- [ ] **Step 4: 구현한다**

- 앱 시작 시 `activeWorkout()`가 있으면 `/workout/active`로 보낸다.
- 표시는 1초 `Timer`가 `RestTimer.remaining`을 다시 계산하는 방식이다.
- 알림은 `zonedSchedule`을 쓴다. `POST_NOTIFICATIONS`는 첫 운동 시작 때 요청한다. `SCHEDULE_EXACT_ALARM`이 허용되면 정확한 알람을, 아니면 `inexactAllowWhileIdle`을 쓴다. 모든 예외는 기록 흐름을 막지 않는다.
- 세트 완료 버튼은 화면 아래쪽 엄지 영역에 두고, 높이 56dp 이상으로 한다.

- [ ] **Step 5: 테스트 통과를 확인한다**

Run: `cd app && $FLUTTER analyze && $FLUTTER test`
Expected: PASS

- [ ] **Step 6: 에뮬레이터에서 확인한다**

운동 시작 → 세트 2개 완료 → 앱을 백그라운드로 보내 타이머 알림 확인 → 강제 종료 후 복구 → 운동 종료 → DB에 저장 확인.

- [ ] **Step 7: 커밋한다**

```bash
git add app
git commit -m "feat(workout): 운동 진행 화면과 휴식 타이머 추가"
```

---

### Task 11: 운동 기록 화면

**Files:**
- Create: `app/lib/features/workout/presentation/workout_history_screen.dart`, `workout_detail_screen.dart`, `history_controller.dart`
- Test: `app/test/features/workout/workout_history_screen_test.dart`, `workout_detail_screen_test.dart`

**Interfaces:**
- Consumes: `WorkoutApi`, `WorkoutStore`, `SyncService.push`
- Produces: 운동 탭 `/workouts`, 상세 `/workouts/:id`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

- `list_showsUnsentFirst_withBadge`: "미전송" 표시
- `list_showsFailed_withRetryAndDiscard`: 재시도 시 `pending`으로 되돌림
- `list_showsServerSessions_newestFirst`
- `list_offline_showsUnsentAndConnectionMessage`: 미전송 기록은 계속 보임
- `detail_editSet_sendsWholeSession`
- `detail_deleteSet_sendsWithoutThatSet`
- `detail_deleteOnlySet_offersDeleteWorkout`: 빈 세션은 보낼 수 없음
- `detail_deleteWorkout_confirmsThenCalls`
- `detail_mutationOffline_showsErrorAndKeepsState`
- `startButton_opensActiveWorkout`, `startButton_resumesWhenInProgress`

- [ ] **Step 2: 테스트 실패를 확인한다**

Run: `cd app && $FLUTTER test test/features/workout/workout_history_screen_test.dart test/features/workout/workout_detail_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: 구현한다**

서버 기록은 최근 30일을 기본으로 불러온다. 전송 완료된 운동의 수정과 삭제는 온라인 전용이며, 재전송 대기열에 넣지 않는다.

- [ ] **Step 4: 테스트 통과를 확인한다**

Run: `cd app && $FLUTTER analyze && $FLUTTER test`
Expected: PASS

- [ ] **Step 5: 커밋한다**

```bash
git add app
git commit -m "feat(workout): 운동 기록 조회, 수정, 삭제 화면 추가"
```

---

### Task 12: 1단계 전체 확인

**Files:**
- Create: `README.md`(실행 방법, 현재 범위, 오프라인 동기화 설계 이유)

- [ ] **Step 1: 자동 테스트를 전부 실행한다**

Run: `cd backend && ./gradlew test`, `cd app && $FLUTTER analyze && $FLUTTER test`
Expected: 모두 통과

- [ ] **Step 2: 에뮬레이터에서 시나리오를 실행한다**

1. 비어 있는 로컬 DB로 서버를 띄우고 앱을 새로 설치한 뒤 가입한다.
2. 비행기 모드를 켠다.
3. 운동을 시작하고, 사용자 정의 운동 하나를 추가해 기록하고, 기본 운동 세트도 기록한다.
4. 앱을 강제 종료하고 다시 열어 복구를 확인한다.
5. 운동을 끝내고 기록 화면에서 "미전송"을 확인한다.
6. 비행기 모드를 끄고 30초 안에 전송되는지 확인한다.
7. DB에서 세션 1개, 세트 수 일치를 조회해 중복이 없는지 확인한다.
8. 같은 운동을 다시 시작해 지난 기록이 기본값으로 채워지고, 한 번의 터치로 세트가 기록되는지 확인한다.

Expected: 모든 항목 통과. 실패하면 해당 Task로 돌아가 재현 테스트부터 추가한다.

- [ ] **Step 3: 커밋한다**

```bash
git add README.md
git commit -m "docs: 실행 방법과 오프라인 설계 이유 추가"
```
