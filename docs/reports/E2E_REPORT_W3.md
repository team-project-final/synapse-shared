# W3 E2E 테스트 결과 리포트

> **작성일**: 2026-05-29 (W3 Day 4)
> **WORKFLOW**: Step 7.10
> **작성자**: @team-lead
> **참조**: [E2E_SCENARIOS_W3.md](../guides/E2E_SCENARIOS_W3.md) | [EVENT_FLOW_MATRIX.md](../guides/EVENT_FLOW_MATRIX.md) | [E2E_BASELINE_W3.md](./E2E_BASELINE_W3.md)

> **요약**: 로컬 harness의 **전송 경로(produce→consume + CloudEvent 페이로드 단위 round-trip)는 검증 완료**(`--all` 5/5, `--full` 13/13). 그러나 5개 서비스 Kafka Producer/Consumer **PR 0/5 미착수**로 **서비스 비즈니스 로직 단위 E2E(S1~S4 Consumer 처리)는 미실행**. EKS는 destroy 상태로 EKS E2E도 미실행.

---

## 1. 로컬 E2E (Docker Compose)

> 측정 기준: `scripts/kafka-e2e-test.sh`. **transport** = 토픽 produce→consume + CloudEvent(`specversion`) 검출. **service** = Consumer 비즈니스 로직(DB/로그) 검증 — 서비스 구현 필요.

### 정상 흐름

| 시나리오 | Producer | Topic | Consumer | transport | service | 비고 |
|---------|----------|-------|----------|:---------:|:-------:|------|
| S1: 회원가입→프로필 | platform-svc | user-registered-v1 | engagement-svc | ✅ | ⏳ 미구현 | Consumer PR 0 |
| S2: 복습→XP | learning-card | review-completed-v1 | engagement-svc | ✅ | ⏳ 미구현 | Producer/Consumer PR 0 |
| S3-1: 노트→AI카드 | knowledge-svc | note-created-v1 | learning-ai | ✅ | ⏳ 미구현 | |
| S3-2: AI카드→알림 | learning-ai | cards-generated-v1 | platform-svc | ✅ | ⏳ 미구현 | |
| S3-3: AI카드→카드등록 | learning-ai | cards-generated-v1 | learning-card | ✅ | ⏳ 미구현 | |
| S4: 노트수정→재인덱싱 | knowledge-svc | note-updated-v1 | learning-ai | ✅ | ⏳ 미구현 | |

> transport ✅ = `--all` 5/5 `[CONSUME] OK validated`(WARN 0건, D-2 해결 후). service ⏳ = 서비스 Consumer 코드 미도착으로 미검증.

### 에러 케이스

| 케이스 | 샘플 | 기대 동작 | transport | service | 비고 |
|--------|------|----------|:---------:|:-------:|------|
| E1: 필수 필드 누락 | missing-required-field.json | 로그 에러 + 스킵 | ✅ produce/consume | ⏳ | Consumer 역직렬화 핸들링 미검증 |
| E2: 유효하지 않은 테넌트 | invalid-tenant.json | 로그 에러 + 스킵 | ✅ | ⏳ | |
| E3: 빈 데이터 | empty-data.json | 로그 에러 + 스킵 | ✅ | ⏳ | |

> 에러 샘플은 transport 단계까지만 검증(메시지 발행/수신). 실제 "에러 로그 + 스킵 + 무크래시"는 Consumer 구현 후.

### 멀티테넌트 격리

| 테넌트 | 이벤트 수 | 격리 확인 | transport | service | 비고 |
|--------|:--------:|:---------:|:---------:|:-------:|------|
| tenant-e2e-001 | 5 (정상) + 3 (에러) | — | ✅ | ⏳ | |
| tenant-e2e-002 | 4 (멀티테넌트) | tenant-001 미접근 | ✅ | ⏳ | 격리 로직은 Consumer 구현 후 |

> `--full` 13/13 PASSED (정상 5 + 에러/멀티테넌트 8). 전송 경로 무유실.

---

## 2. EKS E2E (dev 환경)

| 시나리오 | 결과 | 로컬 대비 | 비고 |
|---------|:----:|:---------:|------|
| S1~S4 전체 | — 미실행 | — | **EKS destroy 상태**(비용관리). terraform apply + MSK 토픽 재생성 후 가능 |

---

## 3. 서비스별 Kafka 구현 최종 상태 (W3 종료 시점)

| 서비스 | 역할 | 구현 | PR | 머지 | 로컬 E2E | EKS E2E |
|--------|------|:----:|:--:|:----:|:--------:|:-------:|
| platform-svc | Producer (UserRegistered) + Consumer (CardsGenerated) | 🔴 | 🔴 | 🔴 | transport만 | — |
| engagement-svc | Consumer (UserRegistered, ReviewCompleted) | 🔴 | 🔴 | 🔴 | transport만 | — |
| knowledge-svc | Producer (NoteCreated, NoteUpdated) | 🔴 | 🔴* | 🔴 | transport만 | — |
| learning-card | Producer (ReviewCompleted) | 🔴 | 🔴 | 🔴 | transport만 | — |
| learning-ai | Producer (CardsGenerated) + Consumer (NoteCreated) | 🔴 | 🔴 | 🔴 | transport만 | — |

> 결과: ✅ 완료 / ❌ 실패 / ⏳ 진행중 / 🔴 미착수
> *knowledge-svc PR #23 열림 = 그래프 API + 청킹(in-process `@TransactionalEventListener`), **Kafka Producer 미포함**. platform PR #33 = W2/MSA test env, Kafka 파일 0건. → work-order 산출물 기준 **PR 0/5**.

---

## 4. 이벤트 전달 성능

| 체인 | 측정 | 결과 | SLA (< 5초) |
|------|------|------|:-----------:|
| transport 라운드트립 (5개 토픽, `--all`) | harness 총 소요 | ~29초(베이스라인) / D-2 해결 후 재측정 5/5 OK | — (체인 단위 아님) |
| A/B/C/D 체인 단위 전달 시간 | — | **미측정** | 서비스 Consumer 구현 필요 |

> harness 총 시간은 console 도구 기동 오버헤드 포함 — 이벤트 단위 전파 지연(SLA 판정)이 아님. 체인 단위 측정은 서비스 구현 후 S1~S4 E2E에서.

---

## 5. 미해결 이슈

| # | 이슈 | 서비스 | 우선순위 | 담당 | W4 이월 |
|---|------|--------|:--------:|------|:-------:|
| I-1 | Kafka Producer/Consumer 구현 PR 0/5 | 전체 5개 | **P0** | 각 owner | ✅ |
| I-2 | 서비스 비즈니스 로직 단위 E2E(S1~S4) 미실행 | 전체 | P0 | @team-lead | ✅ (I-1 해소 후) |
| I-3 | EKS E2E 미실행 (클러스터 destroy) | 인프라 | P1 | @team-lead/gitops | ✅ |
| I-4 | Schema Registry BACKWARD 실등록 검증 미실행 | shared | P1 | @team-lead | ✅ (→ SCHEMA_COMPAT_REVIEW_W3) |
| ~~D-1~~ | ~~stale ZK znode → kafka Exited(1)~~ | shared | — | — | 해결(05-26, `down -v`) |
| ~~D-2~~ | ~~샘플 line-split → CloudEvent 검증 불완전~~ | shared | — | — | 해결(05-27, `compact_json`) |

---

## 6. W4 인수인계 사항

### 완료된 것 (W3)
- 로컬 E2E harness 전송 경로 검증 (`--all` 5/5, `--full` 13/13, CloudEvent 단위 round-trip 신뢰 가능)
- harness 발견사항 D-1/D-2 해결
- Avro 8종 형식·컴파일·CloudEvent 필드 검증 (→ SCHEMA_COMPAT_REVIEW_W3)
- E2E 시나리오(S1~S4/E1~E3/M1) + 샘플 데이터 + 실행 순서 정의

### W4에서 해야 할 것
- **(선결) 서비스 Kafka PR 5/5 머지** — work-order I-1 해소
- 서비스 구현 후 S1~S4 **service 단위 E2E** 실행 (Consumer DB/로그 검증, 멱등성, 에러 스킵)
- 체인 단위 전달 지연 측정(SLA < 5초)
- EKS 재기동 후 dev EKS E2E + Schema Registry BACKWARD 실검증
