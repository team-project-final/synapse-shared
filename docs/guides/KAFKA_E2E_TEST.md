# Kafka E2E 검증 가이드

## 개요

4개 이벤트 흐름을 Docker Compose 로컬 환경에서 검증한다.

## 사전 조건

1. Docker Compose 실행 중: `docker compose up -d`
2. 모든 서비스 healthy: `docker compose ps`
3. Kafka 토픽 생성 완료 (kafka-init 서비스가 자동 생성)

## 검증 시나리오

### 시나리오 1: 회원가입 → 프로필 생성

| 항목 | 값 |
|------|---|
| Producer | platform-svc |
| Topic | `platform.auth.user-registered-v1` |
| Consumer | engagement-svc |
| 검증 | engagement-svc 로그에서 이벤트 수신 확인 + DB에 프로필 레코드 생성 |

**수동 테스트 (서비스 구현 전 — 메시지 흐름만 확인):**
```bash
bash scripts/kafka-e2e-test.sh platform.auth.user-registered-v1 user-registered.json
```

**서비스 구현 후 E2E 테스트:**
```bash
# 1. platform-svc에 회원가입 API 호출
curl -X POST http://localhost:8081/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"e2e@test.com","password":"Test1234!"}'

# 2. engagement-svc 로그에서 이벤트 수신 확인
docker logs synapse-engagement-svc 2>&1 | grep "user-registered"

# 3. engagement-svc DB에서 프로필 확인
docker exec synapse-postgres psql -U synapse -c \
  "SELECT * FROM engagement.user_profiles WHERE email='e2e@test.com'"
```

### 시나리오 2: 노트 생성 → AI 카드 생성

| 항목 | 값 |
|------|---|
| Producer | knowledge-svc |
| Topic | `knowledge.note.note-created-v1` |
| Consumer | learning-ai-svc |
| 검증 | learning-ai-svc 로그에서 카드 생성 트리거 확인 |

**수동 테스트:**
```bash
bash scripts/kafka-e2e-test.sh knowledge.note.note-created-v1 note-created.json
```

### 시나리오 3: 카드 복습 → XP 적립

| 항목 | 값 |
|------|---|
| Producer | learning-card-svc |
| Topic | `learning.card.review-completed-v1` |
| Consumer | engagement-svc |
| 검증 | engagement-svc에서 XP 포인트 증가 확인 |

**수동 테스트:**
```bash
bash scripts/kafka-e2e-test.sh learning.card.review-completed-v1 review-completed.json
```

### 시나리오 4: AI 카드 완료 → 알림

| 항목 | 값 |
|------|---|
| Producer | learning-ai-svc |
| Topic | `learning.ai.cards-generated-v1` |
| Consumer | platform-svc |
| 검증 | platform-svc 알림 로그 확인 |

**수동 테스트:**
```bash
bash scripts/kafka-e2e-test.sh learning.ai.cards-generated-v1 cards-generated.json
```

## 일괄 실행 옵션

### 정상 흐름만 (5개 토픽)

```bash
bash scripts/kafka-e2e-test.sh --all
```

### 에러/멀티테넌트 케이스만

```bash
bash scripts/kafka-e2e-test.sh --error-cases
```

에러 케이스 포함 항목:
- 존재하지 않는 토픽 produce 시도
- `error/missing-required-field.json` — 필수 필드 누락
- `error/invalid-tenant.json` — 유효하지 않은 테넌트
- `error/empty-data.json` — 빈 데이터
- `multi-tenant/*.json` — tenant-e2e-002 전체 이벤트 (4종)

### 전체 (정상 + 에러 + 멀티테넌트)

```bash
bash scripts/kafka-e2e-test.sh --full
```

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `Topic not found` | kafka-init 미완료 | `docker compose restart kafka-init` |
| `Connection refused` | Kafka 미기동 | `docker compose up -d kafka` + health 대기 |
| Consume timeout | 메시지 미도착 | Producer 로그 확인, 토픽 파티션 확인 |
| Serialization error | 스키마 불일치 | Schema Registry에 등록된 스키마 버전 확인 |
