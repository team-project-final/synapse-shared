# Kafka 이벤트 흐름 매트릭스

> **최초 작성**: 2026-05-22 (W3 선행 준비)
> **갱신**: 2026-05-29 — cross-repo 실측 반영 + 아키텍처 결정 D-001 적용

---

## ⚖️ 결정 D-001 — cards-generated 경로: HTTP 채택 (2026-05-29)

> **배경**: learning-ai가 note-created 소비 후 카드 등록을 **learning-card REST API**(`learning-ai/app/clients/card_client.py`)로 처리하도록 구현·머지됨(#26). `learning.ai.cards-generated-v1` 토픽은 **아무도 발행하지 않음**.
>
> **결정**: **(A) HTTP 동기 호출 유지.** 이미 동작하는 경로이며 카드 등록은 즉시 일관성이 바람직. `cards-generated-v1` Kafka 토픽/Producer/Consumer는 **현 설계에서 제외(deprecated)**.
>
> **영향**:
> - learning-ai: CardsGenerated **Producer 불요**.
> - learning-card: cards-generated **Consumer 불요** (HTTP로 직접 수신).
> - platform-svc: cards-generated 소비 기반의 **"AI 카드 생성 알림" 트리거 소멸** → **재설계 필요(open)**. 후보: learning-ai가 알림 전용 경량 이벤트 발행 / platform이 카드 등록 후 별도 신호 소비 / 알림 생략. **platform·learning-ai owner 합의 대상.**
> - CardsGenerated.avsc 스키마는 보존(향후 (B) 복원 또는 분석용), 단 Kafka 발행 경로에서는 미사용.
>
> 재논의 트리거: 비동기 카드 등록(대량/재시도) 요구 발생 시 (B) Kafka 복원 재검토.

## 1. 토픽 × 서비스 매핑

### Producer → Topic → Consumer

| # | Producer | Topic | Consumer | 스키마 | 트리거 |
|---|----------|-------|----------|--------|--------|
| 1 | platform-svc | `platform.auth.user-registered-v1` | engagement-svc | UserRegistered | 회원가입 API 성공 |
| 2 | knowledge-svc | `knowledge.note.note-created-v1` | learning-ai | NoteCreated | 노트 생성 API 성공 |
| 3 | knowledge-svc | `knowledge.note.note-updated-v1` | learning-ai, opensearch | NoteUpdated | 노트 수정 API 성공 |
| 4 | learning-card | `learning.card.review-completed-v1` | engagement-svc | ReviewCompleted | 카드 복습 API 성공 |
| 5 | ~~learning-ai~~ | ~~`learning.ai.cards-generated-v1`~~ | ~~learning-card, platform-svc~~ | ~~CardsGenerated~~ | **D-001: HTTP로 대체(deprecated)** |

> 카드 등록은 learning-ai → learning-card **REST API**(동기). cards-generated 토픽 미사용. AI 카드 알림 트리거는 재설계 대상(D-001).

### 서비스별 역할 요약

| 서비스 | Producer 토픽 | Consumer 토픽 | Consumer Group |
|--------|--------------|--------------|----------------|
| platform-svc | user-registered-v1 | ~~cards-generated-v1~~ → (알림 트리거 재설계, D-001) | platform-svc-group |
| engagement-svc | — | user-registered-v1, review-completed-v1 | engagement-svc-group |
| knowledge-svc | note-created-v1, note-updated-v1 | — | — |
| learning-card | review-completed-v1, (review-due-v1) | ~~cards-generated-v1~~ → HTTP 수신 | learning-card-group |
| learning-ai | ~~cards-generated-v1~~ → 없음 (DLQ만) | note-created-v1 | learning-ai-svc-group |

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

### Chain B: 노트 생성 → AI 카드 자동 생성 → 카드 등록 (D-001 반영)

```
knowledge-svc (노트 생성 API)
  → [knowledge.note.note-created-v1]   ← Kafka (knowledge Producer 미구현, P0)
  → learning-ai (LLM 카드 생성)
    → learning-card REST API (카드 등록)   ← HTTP 동기 (card_client.py, D-001)
    → (AI 카드 알림 트리거: 재설계 open)
```

- **검증**: learning-ai 로그 note-created 수신 + learning-card 카드 등록 API 응답
- **의존성**: 사용자 존재(Chain A 선행) + **knowledge note-created Producer 구현(현재 미구현 — 체인 시작점 차단)**
- **특이사항**: Kafka(note-created) → HTTP(카드 등록) 혼합. cards-generated Kafka 단계는 D-001로 제거. 알림 트리거 미정.

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
| ~~learning.ai.cards-generated-v1~~ | — | — | — | — | **deprecated (D-001, 미발행)** |

> 로컬 Docker Compose: replication-factor=1, min.insync.replicas=1
> cards-generated-v1 토픽은 D-001로 발행자 없음 — 로컬 harness 전송 테스트 용도로만 잔존(스모크), 도메인 경로 아님.

---

## 4. 스키마 호환성

| 스키마 | 네임스페이스 | 호환성 | PII 필드 |
|--------|-----------|:------:|----------|
| CloudEventEnvelope | com.synapse.shared | BACKWARD | 없음 |
| UserRegistered | com.synapse.platform | BACKWARD | **email** |
| NoteCreated | com.synapse.knowledge | BACKWARD | 없음 (content는 사용자 입력) |
| NoteUpdated | com.synapse.knowledge | BACKWARD | 없음 |
| ReviewCompleted | com.synapse.learning | BACKWARD | 없음 |
| CardsGenerated | com.synapse.learning | BACKWARD | 없음 (D-001: Kafka 발행 경로 미사용, 스키마 보존) |
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
