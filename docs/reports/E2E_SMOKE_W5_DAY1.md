# W5 Day 1 — 서비스 단위 E2E 환경 + 스모크 결과 (06-08)

> **작성**: 2026-06-08 (W5 Day 1) · **owner**: @team-lead
> **목적**: W4 이월 차단(스텁 compose) 해소 검증 + Day 2 전체 E2E 사전 디리스킹 스모크
> **환경**: `docker-compose.yml` + `docker-compose.e2e.yml` (origin/main 고정 worktree 빌드, 본 문서 §1)

---

## 1. E2E 실행 환경 (Day 1 Track B 산출물)

| 항목 | 내용 |
|---|---|
| 구성 | `docker-compose.e2e.yml` 오버라이드 — 스텁 5개 → origin/main 실빌드 교체 |
| 빌드 소스 | `../.e2e-worktrees/<repo>` (origin/main detached worktree — owner 작업 트리 비침범) |
| DB | 서비스별 분리: `synapse_platform/engagement/knowledge/learning/ai` (flyway history 충돌 방지) |
| postgres | `pgvector/pgvector:pg16` (learning-ai `CREATE EXTENSION vector`) |
| 결과 | **13/13 컨테이너 healthy** · 6 서비스 health 200 · consumer group 4종 파티션 배정 확인 |

기동 중 해결한 환경 이슈(코드 아님): gateway JWT_PUBLIC_KEY 미주입(dev 공개키 주입으로 해소), gateway 이미지에 curl/bash 없음(wget 헬스체크), learning-ai 빈 API 키 부팅 실패(더미 기본값, §2-F4 참조).

## 2. 스모크 + Avro 계약 전수 감사 결과

스모크: 가입(`POST /api/platform/api/v1/auth/signup` → 201) → `user-registered` 발행 → audit 적재 ✅ / **engagement 소비 실패** ❌ → 전 토픽 writer↔reader 매트릭스 전수 감사 실시.

### 깨지는 페어 (라이브 재현/정적 확정)

| ID | 토픽 | writer → reader | 원인 | 영향 | 제안 |
|----|------|----------------|------|------|------|
| **F1** | platform.auth.user-registered-v1 | platform → **engagement** | reader가 default 없는 `registeredAt` 요구, writer에 없음 (**dev도 동일** — 하드닝 머지로 미해소) | 가입→게이미피케이션 체인 전멸. 라이브 재현 완료 | **P0** — engagement reader avsc를 표준형으로 재생성 (@engagement owner) |
| **F2** | platform.notification.notification-send-v1 | **learning-ai** → platform | record full-name 불일치: `com.synapse.event.platform` vs `com.synapse.platform` (alias 없음) | 노트→AI카드→**알림** 체인 전멸 (정적 확정) | **P0** — learning-ai producer 스키마를 platform reader와 동일 namespace로 (@learning owner) |
| **F3** | (F2와 동일 페어) | learning-ai → platform | reader 필수 `eventId`/`occurredAt`이 writer에 없음 | F2 해소돼도 실패 | P0 (F2와 함께 수정) |
| **F4** | — | learning-ai 기동 | API 키 빈 값이면 부팅 자체 실패 (게이트 없음) | 키 없는 환경에서 서비스 불가 | **P2** — KAFKA_ENABLED 패턴처럼 AI 클라이언트 게이트 (@learning owner) |

### 정보성 드리프트 (비파괴, 정합 권고)

- **canonical(shared) 자체가 표준 문서와 불일치**: shared `UserRegistered.avsc`는 구형(`registeredAt` 시대), `NotificationSend.avsc`는 namespace family 미결(D-002) 상태 — engagement(F1)·learning-ai(F2)는 **구형 canonical을 충실히 따른 결과**. 근본 원인은 shared 정본 미갱신 → **@team-lead 액션**: shared 정본을 표준(§1 공통 메타) + platform 실구현 기준으로 갱신 후 PUBLISH_SHARED_LIBRARY 재배포
- engagement `ReviewCompleted` reader: eventId/occurredAt 없음 (소비는 정상 — canonical은 default 보유라 추가 안전)
- platform 공통 메타 필드 default 미선언 (BACKWARD 안전성 권고 위반, 동작은 정상)

### 정상 확인 페어

knowledge→learning-ai(note-created) · knowledge/learning-card/engagement→platform audit(전 토픽) · engagement→platform(notification-send) · learning-card→engagement(review-completed, Avro 규칙상 OK)

## 3. Day 2 트리아지 선반영

| 우선순위 | 항목 | owner | 비고 |
|---|---|---|---|
| P0 | F1 engagement UserRegistered reader 재생성 | @engagement | dev에도 적용 후 dev→main |
| P0 | F2+F3 learning-ai NotificationSend writer 정합 | @learning | dev→main release에 포함 |
| P1 | shared canonical avsc 정본 갱신 (UserRegistered/NotificationSend) + D-002 정리 | @team-lead | F1/F2 수정의 기준점 — **선행 필요** |
| P2 | F4 learning-ai AI 클라이언트 게이트 | @learning | |

> 시사점: W4 계약/전송 E2E(8/8 PASS)는 shared 정본 기준이라 **서비스별 reader 스키마 드리프트를 못 잡았다**. 서비스 단위 E2E가 잡았음 — Day 2 나머지 시나리오도 동일 환경에서 실행.

## 4. dev/staging 인프라 발견 (Track A, EKS 재apply 후)

| ID | 증상 | 근본 원인 | 조치 |
|----|------|----------|------|
| **F5** | platform dev/staging CrashLoop — Flyway checksum mismatch V1~V3 | **5서비스 × dev/staging 10개 overlay가 단일 RDS `synapse` DB 공유** → flyway_schema_history 충돌 (W4 #37의 실제 근본 원인 추정, 로컬 E2E에서 선제 분리한 것과 동일 문제) | [gitops#136](https://github.com/team-project-final/synapse-gitops/pull/136) — DB 분리 + RDS 5DB 생성(완료) · **머지 보류 중** |
| **F6** | gateway dev CrashLoop — `gateway.jwt.public-key 가 설정되지 않았습니다` | gateway-secret에 JWT_PUBLIC_KEY 매핑 부재 (#128은 local-k8s 전용) | gitops#136 포함 — SM `synapse/dev/gateway/jwt-public-key` 등록(완료) |

나머지 dev/staging 상태: ArgoCD 14앱 Synced, engagement/knowledge/learning-card/learning-ai/frontend 전부 Running, ESO 14 ExternalSecret SecretSynced, monitoring(kube-prometheus-stack+Grafana+Loki) 기동 — **gitops#136 머지 시 dev·staging 5/5 예상**.
