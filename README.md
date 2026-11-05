# fitbite

헬스·식단·인바디 기록 앱. 오프라인 우선 운동 기록, 서버 기반 1RM·칼로리 계산, 사용자별 데이터 접근 제어 | Flutter, Spring Boot, PostgreSQL

헬스케어 풀스택 개발자 지원용 포트폴리오로 만들고 있으며, **아직 개발 중입니다.** 지금은 서버 API와 앱의 기반 코드까지 있고, 앱 화면은 없습니다. 1RM·칼로리 계산과 앱의 오프라인 기록도 아직 구현 전입니다.

## 현재 상태

| 단계 | 내용 | 상태 |
|---|---|---|
| 0 | 저장소, 로컬 DB, CI, 가입·로그인 | 서버 완료, 앱 화면 남음 |
| 1 | 운동 기록(세트, 휴식 타이머, 오프라인 동기화) | 서버 API 완료, 앱 남음 |
| 2~3 | 운동 분석, 인바디 | 예정 |
| 4~5 | 식단·칼로리, 마무리 | 예정 |
| 6~7 | 배포·공개, 실사용 | 예정 |

자세한 범위는 [설계 문서](docs/superpowers/specs/2026-11-04-fitbite-design.md), 작업 단위는 [0~1단계 구현 계획](docs/superpowers/plans/2026-11-04-fitbite-phase-0-1.md), 작업 기록은 [진행 기록](docs/superpowers/plans/2026-11-04-fitbite-phase-0-1-progress.md)에 있습니다.

### 지금까지 만든 것

**서버**
- 초대 코드와 건강 정보 동의가 필요한 가입, 로그인, 토큰 재발급(이전 토큰 폐기), 로그아웃
- 기본 운동 59개 제공, 사용자 정의 운동 추가
- 운동 세션 저장·조회·삭제, 운동별 지난 기록 조회
- 공통 오류 응답 형식, Swagger API 문서

**앱**
- 서버 통신 클라이언트: 토큰 자동 재발급, 오류 변환
- 토큰 안전 저장
- 가입·로그인 화면, 건강 정보 동의, 하단 탭 4개(운동·식단·인바디 탭은 아직 준비 중)
- 폰 운동 저장소와 세트 기본값 규칙(화면 연결은 다음 작업)

**테스트** (2026-11-05 기준)
- 서버 테스트 52개 통과. 실제 PostgreSQL을 Testcontainers로 띄워 실행합니다.
- 앱 테스트 46개 통과, `flutter analyze` 문제 없음.
- Android 에뮬레이터에서 가입, 탭 이동, 재시작 후 로그인 유지, 서버가 꺼진 상태의 재시작을 확인했습니다.

## 기술 구성

| 영역 | 사용 기술 |
|---|---|
| 앱 | Flutter 3.47.9, Riverpod, go_router, dio, drift |
| 서버 | Java 21, Spring Boot 4.1, Spring Data JPA, Spring Security + JWT, Flyway, springdoc |
| DB | PostgreSQL 17 |
| 테스트·자동화 | JUnit, Testcontainers, flutter_test, GitHub Actions |

## 설계에서 고민한 점

- **운동 기록은 폰에 먼저 저장합니다(앱 구현 예정).** 헬스장은 인터넷이 약할 수 있어서, 세트를 완료할 때마다 폰에 저장한 뒤 서버로 보냅니다.
- **같은 요청을 다시 보내도 안전합니다.** 앱이 만든 UUID로 세션 전체를 `PUT`하므로, 응답이 유실되어 재전송해도 기록이 중복되지 않습니다.
- **다른 사용자의 데이터는 존재 여부도 알 수 없습니다.** 다른 사용자의 데이터를 요청하면 없는 데이터와 똑같이 404로 답합니다.
- **수치 계산은 서버 한곳에서 합니다(구현 예정).** 기기마다 계산 결과가 달라지지 않고, 경계 사례까지 테스트하기 쉽습니다.

## 개선 사례

### 동시 저장으로 다른 사용자의 기록을 덮어쓰던 문제

**문제:** 작업 검토에서 두 요청이 거의 동시에 들어오면 한 사용자가 다른 사용자의 운동 기록을 덮어쓸 수 있음을 찾았습니다. 소유자 확인은 있었지만, 앱이 ID를 정하는 구조에서 JPA `save`가 내부적으로 `merge`를 쓰는 것이 원인이었습니다. 확인 직후 상대의 행이 커밋되면 INSERT가 아닌 UPDATE가 실행되어, 제약 조건 오류 없이 200으로 끝났습니다.

**해결:**
- 세션과 운동은 `INSERT ... ON CONFLICT DO NOTHING` 후 `SELECT ... FOR UPDATE`로 잠그고 소유자를 확인합니다.
- 세트는 항상 INSERT만 하여, ID가 겹치면 409로 답합니다.
- 소유자 열은 수정할 수 없게 막았습니다.

**검증:** 특정 SQL 시점에 다른 연결에서 커밋하도록 재현 테스트를 작성했습니다. 수정 전 코드에서 5개 모두 실패하고, 수정 후 모두 통과합니다.

## 실행 방법

필요한 것: Docker Desktop, JDK 21, Flutter 3.47.9

```bash
# 1. 환경 변수 준비: 값을 채운다. APP_JWT_SECRET은 32바이트 이상이어야 한다
cp .env.example .env

# 2. DB 실행
docker compose up -d db

# 3. 서버 실행 (Git Bash 기준)
set -a; . ./.env; set +a
cd backend && ./gradlew bootRun
```

서버가 뜨면 API 문서는 http://localhost:8080/swagger-ui/index.html 에서 볼 수 있습니다.

```bash
# 테스트 (Docker 실행 필요)
cd backend && ./gradlew test
cd app && flutter analyze && flutter test
```
