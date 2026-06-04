# W3 E2E 테스트 시나리오

> **최초 작성**: 2026-05-22 (W3 선행 준비)
> **갱신 예정**: W3 Day 2 (05-27) — 팀원 구현 현황 반영
> **참조**: [EVENT_FLOW_MATRIX.md](./EVENT_FLOW_MATRIX.md) | [KAFKA_E2E_TEST.md](./KAFKA_E2E_TEST.md)

---

## 1. 시나리오 개요

| # | 시나리오 | 체인 | 서비스 | 검증 Day |
|---|---------|:----:|--------|:--------:|
| S1 | 회원가입 → 프로필 자동 생성 | A | platform → engagement | Day 3 |
| S2 | 카드 복습 → XP 적립 | C | learning-card → engagement | Day 3 |
| S3 | 노트 생성 → AI 카드 → 알림 | B | knowledge → learning-ai → platform/learning-card | Day 3~4 |
| S4 | 노트 수정 → 재인덱싱 | D | knowledge → learning-ai/Elasticsearch | Day 4 |
| E1 | 에러: 필수 필드 누락 | — | 전체 Consumer | Day 4 |
| E2 | 에러: 유효하지 않은 테넌트 | — | 전체 Consumer | Day 4 |
| E3 | 에러: 빈 데이터 | — | 전체 Consumer | Day 4 |
| M1 | 멀티테넌트 격리 | A~D | 전체 | Day 4 |

---

## 2. 정상 흐름 시나리오

### S1: 회원가입 → 프로필 자동 생성

**이벤트 체인**:
```
platform-svc (POST /api/v1/auth/register)
  → [platform.auth.user-registered-v1]
  → engagement-svc (프로필 레코드 자동 생성)
```

**사전 조건**: 없음 (기본 흐름)

**수동 테스트 (서비스 구현 전)**:
```bash
bash scripts/kafka-e2e-test.sh platform.auth.user-registered-v1 user-registered.json
```

**서비스 구현 후 E2E**:
```bash
# 1. 회원가입 API 호출
curl -X POST http://localhost:8081/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"e2e-s1@test.synapse.dev","password":"Test1234!"}'

# 2. Kafka 비동기 처리 대기
sleep 3

# 3. engagement-svc 로그 확인
docker logs synapse-engagement-svc 2>&1 | grep "user-registered"

# 4. DB에서 프로필 존재 확인
docker exec synapse-postgres psql -U synapse -c \
  "SELECT * FROM engagement.user_profiles WHERE email='e2e-s1@test.synapse.dev'"
```

**성공 기준**:
- [ ] engagement-svc 로그에 이벤트 수신 로그 존재
- [ ] engagement DB에 프로필 레코드 생성
- [ ] 이벤트 전달 시간 < 5초

**사용 샘플**: `src/test/resources/e2e-samples/user-registered.json`

---

### S2: 카드 복습 → XP 적립

**이벤트 체인**:
```
learning-card (POST /api/v1/reviews)
  → [learning.card.review-completed-v1]
  → engagement-svc (XP 포인트 적립)
```

**사전 조건**: S1 완료 (사용자 존재)

**수동 테스트 (서비스 구현 전)**:
```bash
bash scripts/kafka-e2e-test.sh learning.card.review-completed-v1 review-completed.json
```

**서비스 구현 후 E2E**:
```bash
# 1. 복습 완료 API 호출 (learning-card)
curl -X POST http://localhost:8084/api/v1/reviews \
  -H "Content-Type: application/json" \
  -d '{"cardId":"e2e-card-01","userId":"e2e-user-01","rating":"GOOD"}'

# 2. 비동기 처리 대기
sleep 3

# 3. engagement-svc에서 XP 확인
docker exec synapse-postgres psql -U synapse -c \
  "SELECT user_id, xp_points FROM engagement.user_profiles WHERE user_id='e2e-user-01'"
```

**성공 기준**:
- [ ] engagement-svc 로그에 review-completed 이벤트 수신
- [ ] XP 포인트 증가 확인
- [ ] 동일 reviewId 재전송 시 XP 중복 적립 없음 (멱등성)

**사용 샘플**: `src/test/resources/e2e-samples/review-completed.json`

---

### S3: 노트 생성 → AI 카드 자동 생성 → 알림 + 카드 등록

**이벤트 체인 (D-001 반영 — Kafka+HTTP 혼합)**:
```
knowledge-svc (POST /api/v1/notes)
  → [knowledge.note.note-created-v1]            ← Kafka (knowledge Producer 미구현, P0)
  → learning-ai (LLM 카드 생성)
    → learning-card REST API (카드 등록)          ← HTTP 동기 (card_client.py)
    → (AI 카드 알림 트리거: 재설계 open, D-001)
```

> ⚠️ **D-001**: `cards-generated-v1` Kafka 단계는 HTTP로 대체됨(deprecated). 아래 2단계 수동 테스트는 토픽 스모크용으로만 유효.

**사전 조건**: S1 완료 (사용자 존재) + knowledge note-created Producer 구현

**수동 테스트 — 1단계 (서비스 구현 전)**:
```bash
bash scripts/kafka-e2e-test.sh knowledge.note.note-created-v1 note-created.json
```

**수동 테스트 — 2단계 (cards-generated 토픽 스모크, D-001로 도메인 경로 아님)**:
```bash
bash scripts/kafka-e2e-test.sh learning.ai.cards-generated-v1 cards-generated.json
```

**서비스 구현 후 E2E**:
```bash
# 1. 노트 생성 API 호출
curl -X POST http://localhost:8083/api/v1/notes \
  -H "Content-Type: application/json" \
  -d '{"title":"E2E Test Note","content":"This is a test note for AI card generation.","userId":"e2e-user-01"}'

# 2. learning-ai 카드 생성 대기 (LLM 호출 포함 — 최대 30초)
sleep 30

# 3. learning-ai 로그에서 카드 생성 확인
docker logs synapse-learning-ai 2>&1 | grep "cards-generated"

# 4. learning-card에서 카드 등록 확인
curl http://localhost:8084/api/v1/cards?userId=e2e-user-01

# 5. platform-svc 알림 로그 확인
docker logs synapse-platform-svc 2>&1 | grep "cards-generated"
```

**성공 기준** (D-001 반영):
- [ ] learning-ai가 note-created 이벤트 수신
- [ ] AI 카드 3~5개 생성 (LLM 호출 성공)
- [ ] learning-ai → learning-card **REST API** 카드 등록 호출 성공 (HTTP 2xx)
- [ ] learning-card에서 카드 등록 확인
- [ ] AI 카드 알림 — learning-ai가 `notification-send-v1` 발행 → platform 푸시 ([설계](../designs/NOTIFICATION_TRIGGER_AI_CARDS.md))
- [ ] 전체 체인 완료 시간 < 30초

**사용 샘플**: `src/test/resources/e2e-samples/note-created.json`, `cards-generated.json`

---

### S4: 노트 수정 → 재인덱싱 + 카드 갱신 판단

**이벤트 체인**:
```
knowledge-svc (PUT /api/v1/notes/{id})
  → [knowledge.note.note-updated-v1]
  → learning-ai (카드 갱신 필요 여부 판단)
  → knowledge-svc Elasticsearch indexer (문서 재인덱싱)
```

**사전 조건**: S3 완료 (노트 존재)

**수동 테스트 (서비스 구현 전)**:
```bash
bash scripts/kafka-e2e-test.sh knowledge.note.note-updated-v1 note-updated.json
```

**서비스 구현 후 E2E**:
```bash
# 1. 노트 수정 API 호출
curl -X PUT http://localhost:8083/api/v1/notes/e2e-note-01 \
  -H "Content-Type: application/json" \
  -d '{"title":"E2E Test Note (Updated)","content":"Updated content for reindexing test."}'

# 2. 비동기 처리 대기
sleep 5

# 3. learning-ai 로그 확인
docker logs synapse-learning-ai 2>&1 | grep "note-updated"

# 4. elasticsearch 인덱스 갱신 확인
curl -s http://localhost:9200/notes/_doc/e2e-note-01 | jq '.._source.title'
```

**성공 기준**:
- [ ] learning-ai가 note-updated 이벤트 수신
- [ ] Elasticsearch 인덱스에서 갱신된 title 확인

**사용 샘플**: `src/test/resources/e2e-samples/note-updated.json`

---

## 3. 에러 케이스

### E1: 필수 필드 누락

**샘플**: `src/test/resources/e2e-samples/error/missing-required-field.json`

```bash
bash scripts/kafka-e2e-test.sh --error-cases
```

**기대 동작**: Consumer가 역직렬화 실패 → 에러 로그 + 메시지 스킵. 서비스 크래시 없음.

### E2: 유효하지 않은 테넌트

**샘플**: `src/test/resources/e2e-samples/error/invalid-tenant.json`

**기대 동작**: Consumer가 테넌트 조회 실패 → 에러 로그 + 메시지 스킵. 다른 테넌트 처리에 영향 없음.

### E3: 빈 데이터

**샘플**: `src/test/resources/e2e-samples/error/empty-data.json`

**기대 동작**: Consumer가 빈 데이터 감지 → 에러 로그 + 메시지 스킵.

---

## 4. 멀티테넌트 격리

### M1: tenant-e2e-002 전체 이벤트 흐름

**샘플**: `src/test/resources/e2e-samples/multi-tenant/*.json`

```bash
bash scripts/kafka-e2e-test.sh --full
```

**기대 동작**: tenant-e2e-001과 tenant-e2e-002의 데이터가 격리. 각 테넌트의 이벤트가 해당 테넌트의 Consumer 로직에서만 처리.

---

## 5. 일괄 실행

| 모드 | 명령어 | 범위 | 종류 |
|------|--------|------|------|
| 정상 흐름만 | `bash scripts/kafka-e2e-test.sh --all` | S1~S4 (5개 토픽) | transport 스모크(JSON 바이트) |
| 에러 케이스만 | `bash scripts/kafka-e2e-test.sh --error-cases` | E1~E3 | transport 스모크 |
| 체인 시나리오 | `bash scripts/kafka-e2e-test.sh --scenarios` | S1~S4 의존성 순서 produce + service-check 안내 | transport 스모크 |
| **Avro 라운드트립** | `bash scripts/kafka-e2e-test.sh --avro` | 8개 토픽을 shared `.avsc`로 produce→consume + subject 자동 등록 | **Avro 계약 검증(권장)** |
| 전체 | `bash scripts/kafka-e2e-test.sh --full` | S1~S4 + E1~E3 + M1 | transport 스모크 |

> **transport vs Avro**: `--all/--scenarios/--full`은 JSON 바이트를 `kafka-console-producer`로 흘려 **전송 경로만** 확인(레거시 스모크). 실제 계약(EVENT_CONTRACT_STANDARD = Avro+Registry)은 **`--avro`** 로 검증 — `synapse-schema-registry` 컨테이너의 `kafka-avro-console-producer/consumer` + shared `.avsc` 사용. 사전 조건: `docker compose up -d zookeeper kafka schema-registry kafka-init`.

---

## 6. 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| Topic not found | kafka-init 미완료 | `docker compose restart kafka-init` |
| Connection refused | Kafka 미기동 | `docker compose up -d kafka` + health 대기 |
| Consume timeout | 메시지 미도착 | Producer 로그 확인, 토픽 파티션 확인 |
| Serialization error | 스키마 불일치 | Schema Registry에 등록된 스키마 버전 확인 |
| AI 카드 생성 timeout | LLM API 지연 | 타임아웃 30초 → 60초 조정, LLM API 상태 확인 |
| XP 중복 적립 | 멱등성 미구현 | eventId 기반 중복 체크 로직 확인 |
