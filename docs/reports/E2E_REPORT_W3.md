# W3 E2E 테스트 결과 리포트

> **작성일**: 2026-05-29 (예정)
> **WORKFLOW**: Step 7.10
> **작성자**: @team-lead
> **참조**: [E2E_SCENARIOS_W3.md](../guides/E2E_SCENARIOS_W3.md) | [EVENT_FLOW_MATRIX.md](../guides/EVENT_FLOW_MATRIX.md)

---

## 1. 로컬 E2E (Docker Compose)

### 정상 흐름

| 시나리오 | Producer | Topic | Consumer | 결과 | 비고 |
|---------|----------|-------|----------|:----:|------|
| S1: 회원가입→프로필 | platform-svc | user-registered-v1 | engagement-svc | | |
| S2: 복습→XP | learning-card | review-completed-v1 | engagement-svc | | |
| S3-1: 노트→AI카드 | knowledge-svc | note-created-v1 | learning-ai | | |
| S3-2: AI카드→알림 | learning-ai | cards-generated-v1 | platform-svc | | |
| S3-3: AI카드→카드등록 | learning-ai | cards-generated-v1 | learning-card | | |
| S4: 노트수정→재인덱싱 | knowledge-svc | note-updated-v1 | learning-ai | | |

> 결과: ✅ PASS / ❌ FAIL / ⏳ 미구현 / — 해당없음

### 에러 케이스

| 케이스 | 샘플 | 기대 동작 | 결과 | 비고 |
|--------|------|----------|:----:|------|
| E1: 필수 필드 누락 | missing-required-field.json | 로그 에러 + 스킵 | | |
| E2: 유효하지 않은 테넌트 | invalid-tenant.json | 로그 에러 + 스킵 | | |
| E3: 빈 데이터 | empty-data.json | 로그 에러 + 스킵 | | |

### 멀티테넌트 격리

| 테넌트 | 이벤트 수 | 격리 확인 | 결과 | 비고 |
|--------|:--------:|:---------:|:----:|------|
| tenant-e2e-001 | 5 (정상) + 3 (에러) | — | | |
| tenant-e2e-002 | 5 (멀티테넌트) | tenant-001 데이터 미접근 | | |

---

## 2. EKS E2E (dev 환경)

| 시나리오 | 결과 | 로컬 대비 | 비고 |
|---------|:----:|:---------:|------|
| S1: 회원가입→프로필 | | | |
| S2: 복습→XP | | | |
| S3: 노트→AI카드→알림 | | | |
| S4: 노트수정→재인덱싱 | | | |

---

## 3. 서비스별 Kafka 구현 최종 상태

| 서비스 | 역할 | 구현 | PR | 머지 | 로컬 E2E | EKS E2E |
|--------|------|:----:|:--:|:----:|:--------:|:-------:|
| platform-svc | Producer (UserRegistered) + Consumer (CardsGenerated) | | | | | |
| engagement-svc | Consumer (UserRegistered, ReviewCompleted) | | | | | |
| knowledge-svc | Producer (NoteCreated, NoteUpdated) | | | | | |
| learning-card | Producer (ReviewCompleted) | | | | | |
| learning-ai | Producer (CardsGenerated) + Consumer (NoteCreated) | | | | | |

> 결과: ✅ 완료 / ❌ 실패 / ⏳ 진행중 / 🔴 미착수

---

## 4. 이벤트 전달 성능

| 체인 | 이벤트 수 | 평균 전달 시간 | 최대 전달 시간 | SLA (< 5초) |
|------|:--------:|:------------:|:------------:|:-----------:|
| A (회원가입→프로필) | | | | |
| B (노트→AI카드→알림) | | | | |
| C (복습→XP) | | | | |
| D (노트수정→재인덱싱) | | | | |

---

## 5. 미해결 이슈

| # | 이슈 | 서비스 | 우선순위 | 담당 | W4 이월 |
|---|------|--------|:--------:|------|:-------:|
| | | | | | |

---

## 6. W4 인수인계 사항

### 완료된 것
- (Day 4에 기록)

### W4에서 해야 할 것
- (미완료 항목 + W4 계획 참조)
