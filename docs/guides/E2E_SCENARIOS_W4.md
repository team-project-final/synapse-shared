# W4 통합 E2E 테스트 시나리오 (Step 9.1)

> **작성**: 2026-06-02 (W4 Day 2 — prep) · **owner**: @team-lead
> **상태**: 시나리오 **정의 완료 / 실행 대기**(서비스 Kafka consumer 머지 후 착수, Day 2~4)
> **근거**: [PRD_W4](../project-management/prd/PRD_W4.md) §2·§3·§5 · [W4_PLAN](../project-management/W4_PLAN.md) · [EVENT_FLOW_MATRIX](./EVENT_FLOW_MATRIX.md) · [NOTIFICATION_TRIGGER_AI_CARDS](../designs/NOTIFICATION_TRIGGER_AI_CARDS.md)
> **선행**: W3 단위 시나리오 [E2E_SCENARIOS_W3](./E2E_SCENARIOS_W3.md) (S1~S4·E1~E3·M1) — W4는 그 위에 **크로스서비스 소비 체인**을 검증한다.

---

## 0. W3 대비 W4 초점

W3 시나리오(S1~S4)는 **produce 경로 + 단위 소비**를 정의했다. W4는 **소비자 구현 완료 후의 end-to-end 비즈니스 동작**과 **운영 기능(알림/audit/모더레이션)**을 검증한다.

| 구분 | W3 (S1~S4) | W4 (W1~W5) |
|------|-----------|-----------|
| 검증 대상 | 토픽 발행 + 단위 consumer 수신 | **전체 체인 비즈니스 결과** + 운영 기능 |
| 핵심 신규 | — | 레벨업→FCM 알림, audit 적재, AI카드 알림, 신고 모더레이션 |
| SLA | (해당 없음) | NFR-401 <10초 / NFR-403 audit <30초 / NFR-405 AI <30초 → 상세 [SLA_VERIFICATION_W4](../reports/SLA_VERIFICATION_W4.md) |

> ⚠️ **실행 전제**: 아래 W1~W5는 해당 서비스의 **Kafka consumer가 main 머지**되어야 동작한다. 06-02 기준 미충족 항목 — engagement Consumer(W1·W4), knowledge Producer(W3). 충족 전까지는 **`scripts/kafka-e2e-test.sh --avro`(8/8, 계약 검증)** + 단위 produce 스모크로 대체 검증.

---

## 1. 시나리오 개요

| # | 시나리오 | 체인 | 서비스 | SLA | FR/NFR | 선행 |
|---|---------|:----:|--------|:---:|--------|------|
| **W1** | 복습→XP→레벨업→FCM 알림 (W4 핵심) | C+G | learning-card → engagement → platform | <10초 | FR-TL-401 / NFR-401 | engagement Consumer + level-up Producer, platform notification Consumer |
| **W2** | 전 도메인 이벤트 → audit_logs 적재 | 전체 | (all producers) → platform | <30초 | FR-PL-404 / NFR-403 | platform audit Consumer |
| **W3** | 노트 생성 → AI 카드 → AI_CARDS_READY 알림 | B | knowledge → learning-ai → platform | <30초 | FR-LA-401 / NFR-405 | knowledge Producer, learning-ai 알림 발행, platform notification Consumer |
| **W4** | 회원가입 → 프로필 자동 생성 (S1 승격) | A | platform → engagement | <5초 | FR-EG(프로필) | engagement Consumer |
| **W5** | 신고 접수 → 관리자 모더레이션 | — | engagement(+platform admin) | — | FR-EG-401/402 | engagement 신고 API + admin |
| E1~E3 | 에러: 필드누락/무효테넌트/빈데이터 | — | 전체 Consumer | — | — | (W3 재사용) |
| M1 | 멀티테넌트 격리 (tenant-e2e-002) | A~D | 전체 | — | — | (W3 재사용) |

---

## 2. 핵심 체인 시나리오

### W1: 복습 → XP 적립 → 레벨업 → FCM 알림 ★ FR-TL-401 / NFR-401 (<10초)

**이벤트 체인**:
```
learning-card (POST /api/v1/reviews)
  → [learning.card.review-completed-v1]                       (Avro)
  → engagement-svc Consumer: XP 적립 → 레벨 임계 초과 시
      → [engagement.gamification.level-up-v1]                 (Avro, shared LevelUp)
      → platform-svc notification Consumer
          → FCM 푸시 발송 (FR-PL-401)
```

**사전 조건**:
- 사용자가 **다음 레벨 임계 직전 XP**를 보유 (1회 복습으로 레벨업 트리거되도록). → 테스트 데이터 §4 (`레벨업 경계 사용자` — engagement 레벨 임계 확정 필요).
- engagement Consumer(review-completed) + level-up Producer + platform notification Consumer **main 머지**.
- (FCM) platform FCM 자격증명 설정 — 미설정 시 NFR-402 대신 **발송 시도 로그**로 대체 검증.

**실행 (서비스 구현 후)**:
```bash
# 1. 복습 완료 API (learning-card, :8084)
curl -X POST http://localhost:8084/api/v1/reviews \
  -H "Content-Type: application/json" \
  -d '{"cardId":"e2e-card-01","userId":"e2e-user-levelup","rating":"GOOD"}'

# 2. 체인 대기 (<10초 측정 — 측정 방법은 SLA_VERIFICATION_W4 §2)
# 3. engagement: XP 적립 + 레벨 상승 확인
docker exec synapse-postgres psql -U synapse -d synapse -c \
  "SELECT user_id, xp_total, level FROM engagement.user_profiles WHERE user_id='e2e-user-levelup';"
# 4. level-up 발행 확인
docker logs synapse-engagement-svc 2>&1 | grep "level-up"
# 5. platform notification 소비 + FCM 발송(시도) 확인
docker logs synapse-platform-svc 2>&1 | grep -E "level-up|FCM|push"
```

**성공 기준**:
- [ ] engagement XP 증가 + `level` 1 상승
- [ ] `engagement.gamification.level-up-v1` 발행 (shared `LevelUp` 스키마 — eventId 포함, occurredAt 평문 long)
- [ ] platform notification Consumer 수신 + FCM 발송(또는 시도 로그)
- [ ] **전체 체인 < 10초** (NFR-401)
- [ ] 동일 reviewId 재전송 → XP 중복 적립 없음 + level-up 중복 발행 없음 (멱등성)

> ✅ **스키마 리스크 해소(06-02)**: engagement가 shared `LevelUp`/`BadgeEarned`를 벤더링(구 `GamificationLevelUp` 제거, Producer Avro 전환 — #13 CLOSED)하여 platform Consumer 역직렬화 위험 제거. **이 시나리오 통과의 잔여 선결 = engagement Consumer 신규 + dev→main** ([engagement#15](https://github.com/team-project-final/synapse-engagement-svc/issues/15)).

---

### W2: 전 도메인 이벤트 → audit_logs 적재 ★ FR-PL-404 / NFR-403 (<30초)

**이벤트 체인**:
```
(user-registered / review-completed / level-up / note-created / ...)
  → platform-svc audit Consumer (전 토픽 구독)
  → platform.audit_logs 적재 (90일 보존 정책)
```

**사전 조건**: platform audit Consumer main 머지.

**실행**:
```bash
# 대표 이벤트 1건 produce (또는 W1/W4 실행으로 자연 발생)
bash scripts/kafka-e2e-test.sh platform.auth.user-registered-v1 user-registered.json
# audit 적재 확인 (<30초 이내)
docker exec synapse-postgres psql -U synapse -d synapse -c \
  "SELECT event_type, aggregate_id, created_at FROM platform.audit_logs ORDER BY created_at DESC LIMIT 5;"
```

**성공 기준**:
- [ ] 소비된 이벤트가 `audit_logs`에 1행 적재 (event_type/aggregate_id/payload/timestamp)
- [ ] **적재 지연 < 30초** (NFR-403)
- [ ] 보존 정책 90일 — 스키마/정책 설정 확인(설정 검증으로 대체, 실제 만료는 장기)

---

### W3: 노트 생성 → AI 카드 자동 생성 → AI_CARDS_READY 알림 ★ FR-LA-401 / NFR-405 (<30초)

**이벤트 체인 (D-001 + NOTIFICATION_TRIGGER_AI_CARDS)**:
```
knowledge-svc (POST /api/v1/notes)
  → [knowledge.note.note-created-v1]                          (Avro, Producer 신규 P0)
  → learning-ai Consumer: LLM 카드 생성
      → learning-card REST API 카드 등록                       (HTTP 동기, card_client.py)
      → [platform.notification.notification-send-v1]           (NotificationSend, type=AI_CARDS_READY)
      → platform-svc notification Consumer: eventId dedupe → FCM 푸시
```

**사전 조건**: knowledge Producer 구현(P0) · learning-ai 알림 발행(#22) · platform notification Consumer.

**실행**:
```bash
curl -X POST http://localhost:8083/api/v1/notes \
  -H "Content-Type: application/json" \
  -d '{"title":"E2E W3 Note","content":"Content for AI card generation.","userId":"e2e-user-01"}'
# LLM 호출 포함 — 최대 30초
docker logs synapse-learning-ai 2>&1 | grep -E "note-created|cards|notification-send"
docker logs synapse-platform-svc 2>&1 | grep "AI_CARDS_READY"
```

**성공 기준**:
- [ ] learning-ai note-created 수신 + AI 카드 3~5개 생성
- [ ] learning-card HTTP 카드 등록 2xx
- [ ] `notification-send-v1`(AI_CARDS_READY) 발행 → platform 수신 + dedupe(eventId=uuidv5(noteId+userId))
- [ ] **전체 체인 < 30초** (NFR-405)

---

### W4: 회원가입 → 프로필 자동 생성 (S1 승격, <5초)

W3 [S1](./E2E_SCENARIOS_W3.md#s1)과 동일 체인. W4에서는 engagement Consumer 머지 후 **자동 프로필 생성 + audit 적재(W2 연동)**까지 확인.
- [ ] engagement `user_profiles` 신규 행 생성, 이벤트 전달 < 5초
- [ ] 동일 userId 재전송 시 프로필 중복 생성 없음 (멱등성)

---

### W5: 신고 접수 → 관리자 모더레이션 (FR-EG-401/402)

```
사용자: POST /api/v1/reports (engagement)  → 신고 접수 + 관리자 알림
관리자: GET /api/v1/admin/reports          → 신고 목록
관리자: PUT /api/v1/admin/reports/{id}     → 승인/거부/숨김
```

**성공 기준**:
- [ ] 신고 접수 → 저장 + (관리자 알림 트리거)
- [ ] 관리자 목록 조회 + 상태 전이(승인/거부/숨김) 동작

> ℹ️ 신고/모더레이션은 Kafka 체인이 아닌 **API 흐름**. 테스트 데이터(신고 대상 콘텐츠·reports 행)는 engagement 스키마 확정 후 준비 — §4 갭.

---

## 3. 에러 / 멀티테넌트 (W3 재사용)

[E2E_SCENARIOS_W3 §3·§4](./E2E_SCENARIOS_W3.md) 그대로 적용 — E1~E3(역직렬화 실패 시 로그+스킵, 크래시 없음), M1(tenant-e2e-002 격리). W4 consumer 구현 후 **service 단위**로 재실행하여 "비호환 메시지 수신 시에도 정상 메시지 처리 지속"을 확인.

---

## 4. 테스트 데이터 준비 현황 (Step 9.1 "테스트 데이터")

| 시드 | 파일 | W4 커버 | 갭 |
|------|------|---------|-----|
| 사용자 | `seed/V001__test_users.sql` | ✅ W4(가입)·M1 | — |
| 노트 | `seed/V002__test_notes.sql` | ✅ W3 | — |
| 카드 | `seed/V003__test_cards.sql` | ✅ W1·W2 | — |
| engagement 프로필 + XP | `seed/V004__test_engagement_profiles.sql` | 🟡 W1 | **레벨업 경계 사용자 부재** — 1회 복습으로 레벨업되는 XP의 사용자 필요 |
| AI 생성 이력 | `seed/V005__test_learning_ai.sql` | ✅ W3 | — |
| 신고/모더레이션 | — | 🔴 W5 | **reports 시드 없음** — engagement reports 스키마 확정 후 추가 |

**준비 액션 (실행 전, 갭 2건)**:
1. **레벨업 경계 사용자** (`e2e-user-levelup`): engagement **레벨 임계 XP 확정 후**(engagement owner) `xp_total = 다음레벨임계 - GOOD복습XP`로 시드 1행 추가 → `V006__test_levelup_boundary.sql`. ⚠️ 임계 미확정 상태로 SQL 작성 금지(잘못된 값 위험).
2. **신고 대상 콘텐츠/reports 행**: engagement reports 테이블 스키마 확정 후 시드 추가.

> 시드 적용: `bash scripts/seed-test-data.sh` (V*.sql 순차 적용 + 검증 출력).

---

## 5. 일괄 실행 / 추적

| 단계 | 명령 | 시점 |
|------|------|------|
| 계약(Avro) 사전 검증 | `bash scripts/kafka-e2e-test.sh --avro` (8/8) | ✅ 06-02 통과 (consumer 무관) |
| produce 스모크 | `bash scripts/kafka-e2e-test.sh --scenarios` | consumer 머지 전 |
| **W1~W5 service E2E** | 본 문서 각 §2 절차 | consumer 머지 후 (Day 2~4) |
| SLA 측정 | [SLA_VERIFICATION_W4](../reports/SLA_VERIFICATION_W4.md) | E2E 통과 후 (Day 4) |

**결과 기록**: [E2E_REPORT_W3](../reports/E2E_REPORT_W3.md) 양식 재사용 또는 W4 리포트 신설. 각 시나리오 PASS/FAIL + 체인 소요시간 기록.
