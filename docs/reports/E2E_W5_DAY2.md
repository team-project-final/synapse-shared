# W5 Day 2 — 서비스 단위 풀 E2E 실행 결과 (06-09)

> **작성**: 2026-06-09 (W5 Day 2) · **owner**: @team-lead
> **목적**: Day 1 발견 P0 2건(F1/F2·F3) 수정 후 핵심 10 시나리오 풀 E2E 실행 + 결과 기록
> **환경**: `docker-compose.yml` + `docker-compose.e2e.yml` — origin/main worktree 실빌드, **13/13 컨테이너 healthy**
> **선행**: [E2E_SMOKE_W5_DAY1](./E2E_SMOKE_W5_DAY1.md) · [AVRO_CONTRACT_FIX_W5](../fix-requests/AVRO_CONTRACT_FIX_W5.md) · [E2E_SCENARIOS_W4](../guides/E2E_SCENARIOS_W4.md)

---

## 0. 한 줄 요약

Day 1 P0 2건(가입·알림 체인 전멸)을 **벤더링 정본 교체로 해소 → 라이브 재검증 완료**. 가입→게이미피케이션(W4)·전도메인 audit(W2)·알림 발행·소비(W3 알림 leg) **PASS**. 복습→레벨업(W1)·신고→모더레이션(W5)은 **사전 차단**(테스트 시드 갭 + 크로스서비스 JWT 신원 모델 불일치) — **P0 수정과 무관한 기존 갭**.

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
| **W5** | 신고 → 관리자 모더레이션 | 🔴 **BLOCKED** | `POST /api/v1/community/reports` → **401 "JWT subject must be a numeric user id"**. platform JWT subject=UUID vs engagement 숫자 기대 — 크로스서비스 신원 모델 불일치(신규 발견 F7). + admin 유저·reports 시드 부재(§4 갭) |

## 3. 신규 발견

| ID | 영역 | 증상 | 영향 | 우선순위 |
|----|------|------|------|---------|
| **F7** | engagement 인증 | 인증 필요 API(`/community/reports`, `/admin/reports`)가 platform 발급 JWT(subject=UUID) 거부 — 숫자 user id 요구 | W5 신고/모더레이션 E2E 전면 차단. Kafka 소비(`resolveUserId`는 UUID→Long 변환)는 정상이나 **동기 API 경로는 미정합** | **P1** — 인증 신원 모델 합의 필요(@engagement + @platform) |
| (운영) | E2E worktree | learning worktree가 06-03(#42)에 detached — origin/main #61 이전 코드로 빌드 중이었음 | Day1 스모크가 구 코드 기준이었을 가능성 | 해소(06-09 origin/main 새로고침, 5 worktree 동기) |
| (운영) | kafka | stale ZooKeeper(`NodeExists` registerBroker) 기동 실패 | 재기동 시 간헐 실패 | 해소(볼륨 클린 후 기동) — `down -v` 절차 표준화 권고 |

## 4. 미해결 / 다음 액션

- **owner 머지**: engagement#32 · learning#64 (정본 벤더링) → dev에도 반영 후 dev→main
- **F7 (P1)**: 크로스서비스 JWT 신원 모델 합의 — W5 신고/모더레이션 E2E 선결
- **F4 (P2)**: learning-ai 실 AI 키 or 카드생성 스텁 → W3 풀 체인(노트→카드) 실행
- **시드 갭(§4)**: 레벨업 경계 사용자(W1) + reports/admin 시드(W5)
- **잔여 시나리오**: W1·W5 풀 실행, E1~E3(에러 주입)·M1(멀티테넌트), SLA 측정(Day3)

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
