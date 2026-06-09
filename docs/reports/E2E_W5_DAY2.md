# W5 Day 2 — 서비스 단위 풀 E2E 실행 결과 (06-09)

> **작성**: 2026-06-09 (W5 Day 2) · **owner**: @team-lead
> **목적**: Day 1 발견 P0 2건(F1/F2·F3) 수정 후 핵심 10 시나리오 풀 E2E 실행 + 결과 기록
> **환경**: `docker-compose.yml` + `docker-compose.e2e.yml` — origin/main worktree 실빌드, **13/13 컨테이너 healthy**
> **선행**: [E2E_SMOKE_W5_DAY1](./E2E_SMOKE_W5_DAY1.md) · [AVRO_CONTRACT_FIX_W5](../fix-requests/AVRO_CONTRACT_FIX_W5.md) · [E2E_SCENARIOS_W4](../guides/E2E_SCENARIOS_W4.md)

---

## 0. 한 줄 요약

Day 1 P0 2건(가입·알림 체인 전멸)을 **벤더링 정본 교체로 해소 → 라이브 재검증 완료**. 가입→게이미피케이션(W4)·전도메인 audit(W2)·알림 발행·소비(W3 알림 leg) **PASS**. 추가로 **JWT 신원 모델 버그 2건 발견·수정·검증**: F7(engagement#33, W5 신고접수 PASS — HTTP↔Kafka 신원 일치 입증) · F9(knowledge#59, 검색 인증 401 해소). platform admin 발급 부재(F8)는 기록. 잔여: W1(레벨업 시드)·W5 모더레이션(F8)·W3 AI 생성 + P3 검색(F4) — 모두 **시드/외부키/owner합의 갭**.

## 1. P0 수정 검증 (Day 1 차단 해소)

| ID | 수정 | PR | 라이브 검증 결과 |
|----|------|----|-----------------|
| **F1** | engagement `UserRegistered.avsc` 정본 벤더링(registeredAt 제거 + 공통메타) + 테스트 builder 교체 | [engagement#32](https://github.com/team-project-final/synapse-engagement-svc/pull/32) | 가입 **HTTP 201** → engagement `Created gamification profile from UserRegistered` · `AvroTypeException` **0건** ✅ |
| **F2/F3** | learning-ai `notification_producer.py` namespace `event.platform`→`platform` + 공통메타(eventId/occurredAt) | [learning#64](https://github.com/team-project-final/synapse-learning-svc/pull/64) | 정본 스키마(`com.synapse.platform`) 발행 → platform `NotificationService` 소비·라우팅 · `SerializationException` **0건** ✅ |

> 검증 방식: 가입은 게이트웨이 경유 실 API(`POST /api/platform/api/v1/auth/signup`). 알림은 learning-ai 컨테이너에서 수정된 `NotificationProducer`를 직접 구동(F4 더미 AI 키로 자연 트리거 불가 → writer→registry→broker→reader 전 구간만 격리 검증).

## 2. 핵심 시나리오 결과

| # | 시나리오 | 결과 | 증거 / 비고 |
|---|---------|:----:|------------|
| **W4** | 회원가입 → 프로필 자동 생성 | ✅ **PASS** | 가입 201 → engagement user_profiles 생성, 에러 0 (F1 해소) |
| **W2** | 전 도메인 → audit_logs 적재 | ✅ **PASS** | `public.audit_logs` 1행 `USER_REGISTERED/USER`, 가입과 동일 시각(<30초, NFR-403 충족) |
| **W3** | 노트 → AI카드 → 알림 | 🟡 **PARTIAL** | 알림 leg(learning-ai writer → platform consumer) PASS. **AI 카드 생성 leg는 F4(더미 AI 키)로 미실행** — 자연 노트→카드 트리거 불가 |
| **W1** | 복습 → XP → 레벨업 → 알림 | 🔴 **BLOCKED** | learning-card 복습은 SRS 세션 API(`/reviews`, 세션·덱·카드 모델) — 단순 curl 불가 + **레벨업 경계 시드 부재**(E2E_SCENARIOS_W4 §4 갭) |
| **W5** | 신고 → 관리자 모더레이션 | 🟢 **신고접수 PASS** / 🟡 모더레이션 시드대기 | F7 수정([engagement#33](https://github.com/team-project-final/synapse-engagement-svc/pull/33)) 후 `POST /api/v1/community/reports` (USER 타겟) → **201 적재**, `reporter_id=2330987261487821925`(=가입유저 UUID 해시 Long, Kafka 프로필 PK와 동일 → HTTP↔Kafka 신원 일치 입증). 관리자 모더레이션(`/admin/reports`)은 **403 ADMIN role required**(정상 authz) — ADMIN 유저 시드 부재로 미실행 |

## 3. 신규 발견

| ID | 영역 | 증상 | 영향 | 우선순위 |
|----|------|------|------|---------|
| **F7** | engagement 인증 | 인증 필요 API(`/community/reports`, `/admin/reports`)가 platform 발급 JWT(subject=UUID) 거부 — 숫자 user id 요구. Kafka 소비(`resolveUserId` UUID→Long)와 HTTP(`CurrentUser.require` Long.valueOf) 경로가 동일 서비스 내에서 신원을 다르게 처리 | W5 신고/모더레이션 E2E 차단 | **P1 → ✅ 해소** ([engagement#33](https://github.com/team-project-final/synapse-engagement-svc/pull/33)) — `CurrentUser.resolveUserId` 단일화로 HTTP·Kafka 공유, UUID subject→결정적 Long. 라이브: 신고 201 + reporter_id 일치 검증 |
| **F8** | platform 인증 | platform이 **ADMIN role JWT를 발급할 메커니즘 부재** — `login`이 항상 `DEFAULT_USER_ROLES=["ROLE_USER"]` 하드코딩, `users`에 roles 컬럼/테이블 없음. 게다가 engagement는 claim `"ADMIN"` 확인 vs platform 상수 `"ROLE_ADMIN"` — **role 명명 규칙 불일치** | W5 관리자 모더레이션(`/admin/reports`) E2E 불가 — 정당한 admin 토큰 획득 경로 없음 | **P1** — platform admin 발급 + engagement/platform role claim 규칙 합의(@platform+@engagement). engagement `requireAdmin`은 단위테스트 검증됨 |
| **F9** | knowledge 인증 | 검색 `GET /api/v1/notes/search`가 platform JWT(subject=UUID) **401 거부** — `CurrentUserArgumentResolver`가 숫자 userId claim만 허용(F7과 동일 계열, `notes.user_id`=bigint) | P3 검색 SLA·검색 시나리오 차단 | **P2 → ✅ 해소** ([knowledge#59](https://github.com/team-project-final/synapse-knowledge-svc/pull/59)) — subject UUID→결정적 Long 폴백(engagement와 동일 알고리즘). 라이브: 401→500(인증 통과, 검색 로직 도달) |
| **F4-link** | 검색 실행 | F9 해소 후 검색이 **500** — 하이브리드 검색의 시맨틱 leg가 learning-ai `/ai/search/semantic`(SEARCH_AI_BASE_URL) 호출 → **F4(더미 AI 키)** + 빈 코퍼스 | P3 풀 검색 미완 | F4 해소 + 검색 코퍼스 시드(§4 갭)로 추적 — 인증 무관 |
| (운영) | E2E worktree | learning worktree가 06-03(#42)에 detached — origin/main #61 이전 코드로 빌드 중이었음 | Day1 스모크가 구 코드 기준이었을 가능성 | 해소(06-09 origin/main 새로고침, 5 worktree 동기) |
| (운영) | kafka | stale ZooKeeper(`NodeExists` registerBroker) 기동 실패 | 재기동 시 간헐 실패 | 해소(볼륨 클린 후 기동) — `down -v` 절차 표준화 권고 |

## 3.5 SLA 측정 (Day3 선행, 라이브 스택)

> 도구: `curl -w %{time_total}` 루프(P1) + 가입→DB 적재 wall-clock 폴링(P2/P5, 폴 해상도 ~수백ms 상한). [SLA_VERIFICATION_W4 §5](./SLA_VERIFICATION_W4.md) 양식.

| ID | 목표 | 실측 | 판정 |
|----|------|------|:----:|
| P1 | API P95 <200ms | 로그인(gateway) p95 **79.7ms**·p99 131.9ms(bcrypt 포함) / 신고생성 p95 **15.3ms** | ✅ |
| P2 | Kafka 단일홉 <5s | 가입→engagement 프로필 insert **~1.42s**(wall-clock 상한) | ✅ |
| P5 | Audit 적재 <30s | 가입→audit_logs **~0.72s** | ✅ |
| P3 | 검색 <2s | **미측정** — F9(401) 해소 후에도 검색 500(시맨틱 leg=learning-ai F4 + 빈 코퍼스) | 🔴 차단(F4/코퍼스) |
| P4 | E2E 체인 <10s | 미측정 — W1 레벨업 경계 시드 갭 | ⏳ |
| P6 | AI 카드 <30s | 미측정 — F4(더미 AI 키) | ⏳ |
| P7 | FCM >95% | N/A — FCM 미설정(발송 시도 스킵 경로만 검증) | N/A |

> P1·P2·P5 충족(여유). P3는 F9 해소 후, P4/P6는 시드/AI 키 후 재측정.

## 4. 미해결 / 다음 액션

- **owner 머지**: engagement#32(avro)·#33(F7) · learning#64(avro) → dev에도 반영 후 dev→main
- **F7 (P1) ✅ 해소**: engagement#33 머지 + dev 반영 남음
- **F8 (P1)**: platform ADMIN role 발급 메커니즘 + role claim 규칙 합의 → W5 관리자 모더레이션 선결
- **F9 (P2) ✅ 해소**: knowledge#59 머지 + dev 반영 남음
- **F4 (P2)**: learning-ai 실 AI 키 or 카드생성/임베딩 스텁 → W3 풀 체인 + **P3 검색 시맨틱 leg** 선결
- **시드 갭(§4)**: 레벨업 경계 사용자(W1)
- **SLA**: P1·P2·P5 충족 / P3·P4·P6 차단요인(F9·시드·F4) 해소 후 재측정
- **잔여 시나리오**: W1 풀 실행, W5 모더레이션(F8 후), E1~E3(에러 주입)·M1(멀티테넌트)

## 5. 환경 메모

| 서비스 | 호스트 포트 | DB |
|--------|:----------:|-----|
| gateway | 8080 | — |
| platform-svc | 8081 | synapse_platform |
| knowledge-svc | 8082 | synapse_knowledge |
| engagement-svc | 8083 | synapse_engagement |
| learning-card-svc | 8084 | synapse_learning |
| learning-ai-svc | 8090 | synapse_ai |

> 기동: `docker compose -f docker-compose.yml -f docker-compose.e2e.yml up -d --build` · 재기동 전 stale 상태 시 `down -v`.
