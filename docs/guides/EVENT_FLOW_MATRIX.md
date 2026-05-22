# Kafka 이벤트 흐름 매트릭스

> **최초 작성**: 2026-05-22 (W3 선행 준비)
> **갱신 예정**: W3 Day 1 (05-26) — MSK 토픽 확인 후

---

## 1. 토픽 × 서비스 매핑

### Producer → Topic → Consumer

| # | Producer | Topic | Consumer | 스키마 | 트리거 |
|---|----------|-------|----------|--------|--------|
| 1 | platform-svc | `platform.auth.user-registered-v1` | engagement-svc | UserRegistered | 회원가입 API 성공 |
| 2 | knowledge-svc | `knowledge.note.note-created-v1` | learning-ai | NoteCreated | 노트 생성 API 성공 |
| 3 | knowledge-svc | `knowledge.note.note-updated-v1` | learning-ai, opensearch | NoteUpdated | 노트 수정 API 성공 |
| 4 | learning-card | `learning.card.review-completed-v1` | engagement-svc | ReviewCompleted | 카드 복습 API 성공 |
| 5 | learning-ai | `learning.ai.cards-generated-v1` | learning-card, platform-svc | CardsGenerated | AI 카드 생성 완료 |

### 서비스별 역할 요약

| 서비스 | Producer 토픽 | Consumer 토픽 | Consumer Group |
|--------|--------------|--------------|----------------|
| platform-svc | user-registered-v1 | cards-generated-v1 | platform-svc-group |
| engagement-svc | — | user-registered-v1, review-completed-v1 | engagement-svc-group |
| knowledge-svc | note-created-v1, note-updated-v1 | — | — |
| learning-card | review-completed-v1 | cards-generated-v1 | learning-card-group |
| learning-ai | cards-generated-v1 | note-created-v1 | learning-ai-svc-group |

---

## 2. E2E 이벤트 체인

### Chain A: 회원가입 → 프로필 자동 생성

```
platform-svc (회원가입 API)
  → [platform.auth.user-registered-v1]
  → engagement-svc (프로필 레코드 자동 생성)
```

- **검증**: engagement DB에서 `user_profiles` 레코드 존재 확인
- **의존성**: 없음 (기본 흐름)

### Chain B: 노트 생성 → AI 카드 자동 생성 → 알림 + 카드 등록

```
knowledge-svc (노트 생성 API)
  → [knowledge.note.note-created-v1]
  → learning-ai (LLM 카드 생성)
    → [learning.ai.cards-generated-v1]
    → learning-card (카드 등록)
    → platform-svc (알림 트리거)
```

- **검증**: learning-ai 로그에서 카드 생성 트리거 + platform-svc 알림 로그
- **의존성**: 사용자 존재 필요 (Chain A 선행)
- **특이사항**: 2단계 체인 (Producer → Consumer가 다시 Producer)

### Chain C: 카드 복습 → XP 적립

```
learning-card (복습 완료 API)
  → [learning.card.review-completed-v1]
  → engagement-svc (XP 포인트 적립)
```

- **검증**: engagement DB에서 XP 증가 확인
- **의존성**: 사용자 + 카드 존재 필요 (Chain A, B 선행)
- **멱등성**: 동일 reviewId 중복 적립 방지 필수

### Chain D: 노트 수정 → 재인덱싱 + 카드 갱신 판단

```
knowledge-svc (노트 수정 API)
  → [knowledge.note.note-updated-v1]
  → learning-ai (카드 갱신 필요 여부 판단)
  → opensearch (문서 재인덱싱)
```

- **검증**: opensearch 인덱스 갱신 확인 + learning-ai 로그
- **의존성**: 노트 존재 필요

---

## 3. 토픽 설정

| 토픽 | 파티션 | 복제 (dev) | 복제 (staging/prod) | 보존 기간 | cleanup |
|------|:------:|:---------:|:------------------:|:---------:|---------|
| platform.auth.user-registered-v1 | 3 | 2 | 2 | 7일 | delete |
| knowledge.note.note-created-v1 | 3 | 2 | 2 | 7일 | delete |
| knowledge.note.note-updated-v1 | 3 | 2 | 2 | 7일 | delete |
| learning.card.review-completed-v1 | 3 | 2 | 2 | 7일 | delete |
| learning.ai.cards-generated-v1 | 3 | 2 | 2 | 7일 | delete |

> 로컬 Docker Compose: replication-factor=1, min.insync.replicas=1

---

## 4. 스키마 호환성

| 스키마 | 네임스페이스 | 호환성 | PII 필드 |
|--------|-----------|:------:|----------|
| CloudEventEnvelope | com.synapse.shared | BACKWARD | 없음 |
| UserRegistered | com.synapse.platform | BACKWARD | **email** |
| NoteCreated | com.synapse.knowledge | BACKWARD | 없음 (content는 사용자 입력) |
| NoteUpdated | com.synapse.knowledge | BACKWARD | 없음 |
| ReviewCompleted | com.synapse.learning | BACKWARD | 없음 |
| CardsGenerated | com.synapse.learning | BACKWARD | 없음 |
| TenantId | com.synapse.shared | — | 없음 |
| UserId | com.synapse.shared | — | 없음 |

> **PII 참고**: UserRegistered의 `email` 필드가 유일한 PII. Consumer(engagement-svc)에서 프로필 생성에 사용. 로그 출력 시 마스킹 권장.

---

## 5. E2E 검증 실행 순서

| 순서 | 체인 | 시나리오 | 선행 조건 |
|:----:|:----:|---------|----------|
| 1 | A | 회원가입 → 프로필 | 없음 |
| 2 | C | 복습 → XP | 사용자 존재 |
| 3 | B | 노트 → AI 카드 → 알림 | 사용자 존재 |
| 4 | D | 노트 수정 → 재인덱싱 | 노트 존재 |

> 서비스 구현 완료 전: `kafka-e2e-test.sh --all`로 메시지 흐름만 확인
> 서비스 구현 완료 후: API 호출 → 이벤트 발행 → Consumer 처리까지 E2E 확인
