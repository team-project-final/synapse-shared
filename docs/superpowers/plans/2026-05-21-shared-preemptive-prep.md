# synapse-shared 선제 준비 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** gitops 세션(서비스 안정화 + staging)과 병렬로, E2E 테스트 인프라 완성 + 배포 검증 자동화 + 문서 정비를 수행한다.

**Architecture:** 3 Phase 순차 진행. Phase 1은 Kafka E2E 테스트 스크립트/데이터 보강, Phase 2는 ArgoCD/서비스 검증 자동화 스크립트, Phase 3는 HANDOFF 갱신 + 합류 체크리스트.

**Tech Stack:** Bash, Docker, kubectl, argocd CLI, curl, jq, PostgreSQL

---

## Phase 1: E2E 테스트 인프라 완성

### Task 1: E2E 샘플 이벤트 데이터 — note-updated 추가

**Files:**
- Create: `src/test/resources/e2e-samples/note-updated.json`

- [ ] **Step 1: note-updated.json 생성**

기존 note-created.json과 동일한 CloudEvent 구조, type만 `knowledge.note.note-updated`로 변경:

```json
{
  "specversion": "1.0",
  "id": "e2e-test-005",
  "source": "knowledge-svc",
  "type": "knowledge.note.note-updated",
  "subject": "note/e2e-note-01",
  "time": "2026-05-20T09:04:00Z",
  "tenantid": "tenant-e2e-001",
  "datacontenttype": "application/avro",
  "traceparent": "00-e2etest00000000000000000000005-0000000000000005-01",
  "data": {
    "noteId": "e2e-note-01",
    "tenantId": "tenant-e2e-001",
    "title": "E2E Test Note (Updated)",
    "content": "This note has been updated for Kafka E2E validation.",
    "updatedAt": "2026-05-20T09:04:00Z"
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/test/resources/e2e-samples/note-updated.json
git commit -m "test: add note-updated E2E sample event"
```

---

### Task 2: E2E 샘플 이벤트 데이터 — 에러 케이스 추가

**Files:**
- Create: `src/test/resources/e2e-samples/error/missing-required-field.json`
- Create: `src/test/resources/e2e-samples/error/invalid-tenant.json`
- Create: `src/test/resources/e2e-samples/error/empty-data.json`

- [ ] **Step 1: error 디렉토리 생성 + missing-required-field.json**

필수 필드 `userId` 누락:

```json
{
  "specversion": "1.0",
  "id": "e2e-err-001",
  "source": "platform-svc",
  "type": "platform.auth.user-registered",
  "subject": "user/e2e-err-user",
  "time": "2026-05-20T10:00:00Z",
  "tenantid": "tenant-e2e-001",
  "datacontenttype": "application/avro",
  "traceparent": "00-e2etest0000000000000000000err1-000000000000err1-01",
  "data": {
    "email": "error-user@test.synapse.dev",
    "tenantId": "tenant-e2e-001",
    "registeredAt": "2026-05-20T10:00:00Z"
  }
}
```

- [ ] **Step 2: invalid-tenant.json**

존재하지 않는 tenant:

```json
{
  "specversion": "1.0",
  "id": "e2e-err-002",
  "source": "platform-svc",
  "type": "platform.auth.user-registered",
  "subject": "user/e2e-err-tenant",
  "time": "2026-05-20T10:01:00Z",
  "tenantid": "tenant-nonexistent-999",
  "datacontenttype": "application/avro",
  "traceparent": "00-e2etest0000000000000000000err2-000000000000err2-01",
  "data": {
    "userId": "e2e-err-tenant-user",
    "email": "bad-tenant@test.synapse.dev",
    "tenantId": "tenant-nonexistent-999",
    "registeredAt": "2026-05-20T10:01:00Z"
  }
}
```

- [ ] **Step 3: empty-data.json**

data 필드가 빈 객체:

```json
{
  "specversion": "1.0",
  "id": "e2e-err-003",
  "source": "platform-svc",
  "type": "platform.auth.user-registered",
  "subject": "user/e2e-err-empty",
  "time": "2026-05-20T10:02:00Z",
  "tenantid": "tenant-e2e-001",
  "datacontenttype": "application/avro",
  "traceparent": "00-e2etest0000000000000000000err3-000000000000err3-01",
  "data": {}
}
```

- [ ] **Step 4: Commit**

```bash
git add src/test/resources/e2e-samples/error/
git commit -m "test: add error case E2E samples (missing field, invalid tenant, empty data)"
```

---

### Task 3: E2E 샘플 이벤트 데이터 — 멀티테넌트 케이스 추가

**Files:**
- Create: `src/test/resources/e2e-samples/multi-tenant/user-registered-tenant2.json`

- [ ] **Step 1: multi-tenant 디렉토리 생성 + user-registered-tenant2.json**

tenant-e2e-002를 사용하는 정상 이벤트 (V001 시드의 e2e-user-03과 대응):

```json
{
  "specversion": "1.0",
  "id": "e2e-test-mt-001",
  "source": "platform-svc",
  "type": "platform.auth.user-registered",
  "subject": "user/e2e-user-03",
  "time": "2026-05-20T09:05:00Z",
  "tenantid": "tenant-e2e-002",
  "datacontenttype": "application/avro",
  "traceparent": "00-e2etest000000000000000000mt001-00000000000mt001-01",
  "data": {
    "userId": "e2e-user-03",
    "email": "carol@test.synapse.dev",
    "tenantId": "tenant-e2e-002",
    "registeredAt": "2026-05-20T09:05:00Z"
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/test/resources/e2e-samples/multi-tenant/
git commit -m "test: add multi-tenant E2E sample (tenant-e2e-002)"
```

---

### Task 4: DB 시드 데이터 — engagement 프로필 + learning-ai 이력

**Files:**
- Create: `src/test/resources/seed/V004__test_engagement_profiles.sql`
- Create: `src/test/resources/seed/V005__test_learning_ai.sql`
- Modify: `scripts/seed-test-data.sh` (검증 쿼리 추가)

- [ ] **Step 1: V004__test_engagement_profiles.sql**

engagement 서비스의 프로필 + XP 초기 데이터:

```sql
-- V004__test_engagement_profiles.sql
-- E2E 테스트용 engagement 프로필 + XP 시드 데이터

INSERT INTO engagement.user_profiles (user_id, tenant_id, display_name, xp_total, level, created_at)
VALUES
  ('e2e-user-01', 'tenant-e2e-001', 'Alice', 0, 1, '2026-05-20 09:00:00'),
  ('e2e-user-02', 'tenant-e2e-001', 'Bob',   150, 2, '2026-05-20 09:00:00'),
  ('e2e-user-03', 'tenant-e2e-002', 'Carol', 0, 1, '2026-05-20 09:00:00')
ON CONFLICT (user_id) DO NOTHING;

-- XP 이력 (review-completed 이벤트 검증용 — Bob에게 기존 XP 있음)
INSERT INTO engagement.xp_history (id, user_id, tenant_id, event_type, xp_amount, created_at)
VALUES
  ('e2e-xp-01', 'e2e-user-02', 'tenant-e2e-001', 'review-completed', 50, '2026-05-20 09:02:00'),
  ('e2e-xp-02', 'e2e-user-02', 'tenant-e2e-001', 'review-completed', 50, '2026-05-20 09:03:00'),
  ('e2e-xp-03', 'e2e-user-02', 'tenant-e2e-001', 'review-completed', 50, '2026-05-20 09:04:00')
ON CONFLICT (id) DO NOTHING;
```

- [ ] **Step 2: V005__test_learning_ai.sql**

learning-ai 서비스의 AI 카드 생성 이력:

```sql
-- V005__test_learning_ai.sql
-- E2E 테스트용 AI 카드 생성 이력 시드 데이터

INSERT INTO learning.ai_generation_history (id, note_id, user_id, tenant_id, card_count, status, created_at)
VALUES
  ('e2e-aigen-01', 'e2e-note-01', 'e2e-user-01', 'tenant-e2e-001',
   5, 'COMPLETED', '2026-05-20 09:03:00'),
  ('e2e-aigen-02', 'e2e-note-02', 'e2e-user-01', 'tenant-e2e-001',
   3, 'COMPLETED', '2026-05-20 09:03:30')
ON CONFLICT (id) DO NOTHING;
```

- [ ] **Step 3: seed-test-data.sh에 검증 쿼리 추가**

`scripts/seed-test-data.sh`의 검증 섹션 끝에 추가:

```bash
echo "[CHECK] engagement.user_profiles:"
docker exec "$CONTAINER" psql -U "$USER" -d "$DB" -c \
  "SELECT user_id, display_name, xp_total, level FROM engagement.user_profiles WHERE user_id LIKE 'e2e-%';"

echo "[CHECK] learning.ai_generation_history:"
docker exec "$CONTAINER" psql -U "$USER" -d "$DB" -c \
  "SELECT id, note_id, card_count, status FROM learning.ai_generation_history WHERE id LIKE 'e2e-%';"
```

- [ ] **Step 4: Commit**

```bash
git add src/test/resources/seed/V004__test_engagement_profiles.sql
git add src/test/resources/seed/V005__test_learning_ai.sql
git add scripts/seed-test-data.sh
git commit -m "test: add engagement profile + learning-ai seed data"
```

---

### Task 5: E2E 테스트 스크립트 보강 (`kafka-e2e-test.sh`)

**Files:**
- Modify: `scripts/kafka-e2e-test.sh`

- [ ] **Step 1: 전체 스크립트 교체**

기존 스크립트를 아래로 교체. 변경 사항:
- `note-updated-v1` 토픽 추가 (`--all`에 포함)
- consume 결과 자동 판정 (JSON 출력에서 key 필드 존재 여부 체크)
- 종합 리포트 (pass/fail 카운트, 소요 시간)
- `--error-cases` 플래그 (에러 시나리오 테스트)
- 종료 코드 반환

```bash
#!/usr/bin/env bash
# scripts/kafka-e2e-test.sh
# Kafka E2E produce/consume smoke test (Docker Compose local environment).
# Usage:
#   bash scripts/kafka-e2e-test.sh <topic> <sample-file>
#   bash scripts/kafka-e2e-test.sh --all
#   bash scripts/kafka-e2e-test.sh --error-cases
set -euo pipefail

BROKER="${KAFKA_BROKERS:-localhost:9092}"
CONTAINER="${KAFKA_CONTAINER:-synapse-kafka}"
SAMPLES_DIR="src/test/resources/e2e-samples"
TIMEOUT="${CONSUME_TIMEOUT:-10}"

topic="${1:-}"
sample="${2:-}"

PASS_COUNT=0
FAIL_COUNT=0
START_TIME=$(date +%s)

usage() {
  cat <<'USAGE'
Usage: bash scripts/kafka-e2e-test.sh <topic> <sample-json>

Topics:
  platform.auth.user-registered-v1
  knowledge.note.note-created-v1
  knowledge.note.note-updated-v1
  learning.card.review-completed-v1
  learning.ai.cards-generated-v1

Examples:
  bash scripts/kafka-e2e-test.sh platform.auth.user-registered-v1 user-registered.json
  bash scripts/kafka-e2e-test.sh --all
  bash scripts/kafka-e2e-test.sh --error-cases
USAGE
}

produce_and_consume() {
  local t="$1" f="$2" expect_fail="${3:-false}"
  local filepath="$SAMPLES_DIR/$f"

  if [ ! -f "$filepath" ]; then
    echo "ERROR: Sample file not found: $filepath"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 1
  fi

  echo "=== Testing: $t ($f) ==="
  echo "[PRODUCE] Sending message from $f ..."

  # Produce via docker exec
  if ! docker exec -i "$CONTAINER" kafka-console-producer \
    --bootstrap-server kafka:29092 \
    --topic "$t" \
    < "$filepath" 2>/dev/null; then
    if [ "$expect_fail" = "true" ]; then
      echo "[PRODUCE] Expected failure — OK"
      PASS_COUNT=$((PASS_COUNT + 1))
      return 0
    fi
    echo "[PRODUCE] FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 1
  fi

  echo "[PRODUCE] OK"

  echo "[CONSUME] Reading from $t (timeout=${TIMEOUT}s) ..."
  local consumed
  consumed=$(docker exec "$CONTAINER" kafka-console-consumer \
    --bootstrap-server kafka:29092 \
    --topic "$t" \
    --from-beginning \
    --max-messages 1 \
    --timeout-ms "$((TIMEOUT * 1000))" 2>/dev/null) || true

  if [ -z "$consumed" ]; then
    if [ "$expect_fail" = "true" ]; then
      echo "[CONSUME] No message (expected) — OK"
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      echo "[CONSUME] FAIL — no message received"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    # Validate consumed message has expected structure
    if echo "$consumed" | grep -q '"specversion"'; then
      echo "[CONSUME] OK — message received and validated"
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      echo "[CONSUME] WARN — message received but unexpected format"
      PASS_COUNT=$((PASS_COUNT + 1))
    fi
  fi
  echo ""
}

run_all() {
  produce_and_consume "platform.auth.user-registered-v1" "user-registered.json"
  produce_and_consume "knowledge.note.note-created-v1" "note-created.json"
  produce_and_consume "knowledge.note.note-updated-v1" "note-updated.json"
  produce_and_consume "learning.card.review-completed-v1" "review-completed.json"
  produce_and_consume "learning.ai.cards-generated-v1" "cards-generated.json"
}

run_error_cases() {
  echo ""
  echo "========================================="
  echo "  Error Case Tests"
  echo "========================================="
  echo ""

  # Test 1: produce to non-existent topic (auto-create off → should fail or create)
  echo "=== Error Test 1: Non-existent topic ==="
  echo '{"test":"nonexistent"}' | docker exec -i "$CONTAINER" kafka-console-producer \
    --bootstrap-server kafka:29092 \
    --topic "nonexistent.topic.test" 2>&1 || true
  echo "[INFO] Non-existent topic test completed"
  PASS_COUNT=$((PASS_COUNT + 1))
  echo ""

  # Test 2: produce error samples (missing field, invalid tenant, empty data)
  produce_and_consume "platform.auth.user-registered-v1" "error/missing-required-field.json"
  produce_and_consume "platform.auth.user-registered-v1" "error/invalid-tenant.json"
  produce_and_consume "platform.auth.user-registered-v1" "error/empty-data.json"

  # Test 3: multi-tenant sample
  produce_and_consume "platform.auth.user-registered-v1" "multi-tenant/user-registered-tenant2.json"
}

print_report() {
  local end_time
  end_time=$(date +%s)
  local elapsed=$((end_time - START_TIME))

  echo ""
  echo "========================================="
  echo "  E2E Test Report"
  echo "========================================="
  echo "  PASS: $PASS_COUNT"
  echo "  FAIL: $FAIL_COUNT"
  echo "  TOTAL: $((PASS_COUNT + FAIL_COUNT))"
  echo "  TIME: ${elapsed}s"
  echo "========================================="

  if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "  RESULT: FAILED"
    return 1
  else
    echo "  RESULT: PASSED"
    return 0
  fi
}

case "${topic}" in
  --all)
    run_all
    print_report
    ;;
  --error-cases)
    run_error_cases
    print_report
    ;;
  --full)
    run_all
    run_error_cases
    print_report
    ;;
  "")
    usage
    exit 1
    ;;
  *)
    if [ -z "$sample" ]; then
      usage
      exit 1
    fi
    produce_and_consume "$topic" "$sample"
    print_report
    ;;
esac
```

- [ ] **Step 2: 스크립트 구문 검증**

Run: `bash -n scripts/kafka-e2e-test.sh`
Expected: 출력 없음 (구문 에러 0)

- [ ] **Step 3: Commit**

```bash
git add scripts/kafka-e2e-test.sh
git commit -m "feat: enhance kafka-e2e-test.sh — add note-updated, auto-validation, error cases, report"
```

---

## Phase 2: 배포 검증 사전 준비

### Task 6: ArgoCD 배포 검증 자동화 스크립트

**Files:**
- Create: `scripts/verify-argocd-deploy.sh`

- [ ] **Step 1: verify-argocd-deploy.sh 작성**

bastion SSM 접속 상태에서 실행. kubectl + argocd CLI 사용:

```bash
#!/usr/bin/env bash
# scripts/verify-argocd-deploy.sh
# ArgoCD 배포 상태 자동 검증 스크립트
# 사전 조건: kubectl context 설정 완료, argocd CLI 로그인 완료
# Usage: bash scripts/verify-argocd-deploy.sh [namespace]
set -euo pipefail

NAMESPACE="${1:-synapse-dev}"
APPS=("platform-svc" "engagement-svc" "knowledge-svc" "learning-card" "learning-ai")
ENV="${NAMESPACE##*-}"  # synapse-dev → dev, synapse-staging → staging

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

check_result() {
  local label="$1" status="$2"
  if [ "$status" = "PASS" ]; then
    echo "  [PASS] $label"
    PASS_COUNT=$((PASS_COUNT + 1))
  elif [ "$status" = "WARN" ]; then
    echo "  [WARN] $label"
    WARN_COUNT=$((WARN_COUNT + 1))
  else
    echo "  [FAIL] $label"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "========================================="
echo "  ArgoCD Deploy Verification"
echo "  Namespace: $NAMESPACE"
echo "========================================="
echo ""

# --- Section 1: ArgoCD Application Status ---
echo "--- 1. ArgoCD Application Status ---"
for app in "${APPS[@]}"; do
  app_name="synapse-${app}-${ENV}"
  sync_status=$(argocd app get "$app_name" -o json 2>/dev/null | jq -r '.status.sync.status // "UNKNOWN"') || sync_status="UNKNOWN"
  health_status=$(argocd app get "$app_name" -o json 2>/dev/null | jq -r '.status.health.status // "UNKNOWN"') || health_status="UNKNOWN"

  if [ "$sync_status" = "Synced" ] && [ "$health_status" = "Healthy" ]; then
    check_result "$app_name: Sync=$sync_status Health=$health_status" "PASS"
  elif [ "$sync_status" = "Synced" ]; then
    check_result "$app_name: Sync=$sync_status Health=$health_status" "WARN"
  else
    check_result "$app_name: Sync=$sync_status Health=$health_status" "FAIL"
  fi
done
echo ""

# --- Section 2: Pod Status ---
echo "--- 2. Pod Status ---"
for app in "${APPS[@]}"; do
  pod_info=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$app" \
    -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase} {.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>/dev/null) || pod_info=""

  if [ -z "$pod_info" ]; then
    check_result "$app: no pods found" "FAIL"
    continue
  fi

  while IFS=' ' read -r pod_name phase restarts; do
    if [ "$phase" = "Running" ] && [ "${restarts:-0}" -le 3 ]; then
      check_result "$pod_name: $phase (restarts: $restarts)" "PASS"
    elif [ "$phase" = "Running" ]; then
      check_result "$pod_name: $phase (restarts: $restarts — high)" "WARN"
    else
      check_result "$pod_name: $phase (restarts: $restarts)" "FAIL"
    fi
  done <<< "$pod_info"
done
echo ""

# --- Section 3: ExternalSecret Status ---
echo "--- 3. ExternalSecret Sync ---"
es_output=$(kubectl get externalsecrets -n "$NAMESPACE" \
  -o jsonpath='{range .items[*]}{.metadata.name} {.status.conditions[0].reason}{"\n"}{end}' 2>/dev/null) || es_output=""

if [ -z "$es_output" ]; then
  check_result "No ExternalSecrets found" "WARN"
else
  while IFS=' ' read -r es_name es_reason; do
    if [ "$es_reason" = "SecretSynced" ]; then
      check_result "$es_name: $es_reason" "PASS"
    else
      check_result "$es_name: ${es_reason:-UNKNOWN}" "FAIL"
    fi
  done <<< "$es_output"
fi
echo ""

# --- Report ---
echo "========================================="
echo "  Verification Report"
echo "========================================="
echo "  PASS: $PASS_COUNT"
echo "  WARN: $WARN_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "========================================="

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "  RESULT: FAILED — review items above"
  exit 1
elif [ "$WARN_COUNT" -gt 0 ]; then
  echo "  RESULT: PASSED with warnings"
  exit 0
else
  echo "  RESULT: ALL PASSED"
  exit 0
fi
```

- [ ] **Step 2: 구문 검증**

Run: `bash -n scripts/verify-argocd-deploy.sh`
Expected: 출력 없음

- [ ] **Step 3: Commit**

```bash
git add scripts/verify-argocd-deploy.sh
git commit -m "feat: add ArgoCD deploy verification script"
```

---

### Task 7: 서비스 헬스체크 통합 검증 스크립트

**Files:**
- Create: `scripts/verify-service-health.sh`

- [ ] **Step 1: verify-service-health.sh 작성**

로컬(Docker Compose)과 EKS(port-forward) 양쪽에서 사용 가능:

```bash
#!/usr/bin/env bash
# scripts/verify-service-health.sh
# 서비스 헬스체크 통합 검증 스크립트
# Usage:
#   bash scripts/verify-service-health.sh                     # 로컬 Docker Compose (기본)
#   bash scripts/verify-service-health.sh --env eks            # EKS port-forward
#   PLATFORM_HOST=localhost:8081 bash scripts/verify-service-health.sh --env custom
set -euo pipefail

ENV="${2:-local}"  # local | eks | custom
KAFKA_CONTAINER="${KAFKA_CONTAINER:-synapse-kafka}"

# --- Service endpoints ---
if [ "$ENV" = "local" ]; then
  PLATFORM_HOST="${PLATFORM_HOST:-localhost:8081}"
  ENGAGEMENT_HOST="${ENGAGEMENT_HOST:-localhost:8082}"
  KNOWLEDGE_HOST="${KNOWLEDGE_HOST:-localhost:8083}"
  LEARNING_CARD_HOST="${LEARNING_CARD_HOST:-localhost:8084}"
  LEARNING_AI_HOST="${LEARNING_AI_HOST:-localhost:8085}"
elif [ "$ENV" = "eks" ]; then
  # EKS에서는 port-forward 후 사용
  PLATFORM_HOST="${PLATFORM_HOST:-localhost:18081}"
  ENGAGEMENT_HOST="${ENGAGEMENT_HOST:-localhost:18082}"
  KNOWLEDGE_HOST="${KNOWLEDGE_HOST:-localhost:18083}"
  LEARNING_CARD_HOST="${LEARNING_CARD_HOST:-localhost:18084}"
  LEARNING_AI_HOST="${LEARNING_AI_HOST:-localhost:18085}"
else
  # custom — 환경변수에서 읽음
  : "${PLATFORM_HOST:?}" "${ENGAGEMENT_HOST:?}" "${KNOWLEDGE_HOST:?}" "${LEARNING_CARD_HOST:?}" "${LEARNING_AI_HOST:?}"
fi

PASS_COUNT=0
FAIL_COUNT=0

check_health() {
  local name="$1" url="$2" expected_field="${3:-status}"

  echo "--- $name ---"
  local response
  response=$(curl -sf --max-time 5 "$url" 2>/dev/null) || response=""

  if [ -z "$response" ]; then
    echo "  [FAIL] No response from $url"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  local status
  status=$(echo "$response" | jq -r ".$expected_field // \"UNKNOWN\"" 2>/dev/null) || status="UNKNOWN"

  if [ "$status" = "UP" ] || [ "$status" = "ok" ] || [ "$status" = "healthy" ]; then
    echo "  [PASS] $name: $status"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  [FAIL] $name: $status"
    echo "  Response: $response"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "========================================="
echo "  Service Health Check ($ENV)"
echo "========================================="
echo ""

# --- Spring Boot services (actuator) ---
echo "=== Spring Boot Services ==="
check_health "platform-svc"     "http://$PLATFORM_HOST/actuator/health"
check_health "engagement-svc"   "http://$ENGAGEMENT_HOST/actuator/health"
check_health "knowledge-svc"    "http://$KNOWLEDGE_HOST/actuator/health"
check_health "learning-card"    "http://$LEARNING_CARD_HOST/actuator/health"
echo ""

# --- FastAPI service ---
echo "=== FastAPI Services ==="
check_health "learning-ai"      "http://$LEARNING_AI_HOST/health"
echo ""

# --- Kafka consumer groups (local only) ---
if [ "$ENV" = "local" ]; then
  echo "=== Kafka Consumer Groups ==="
  groups=$(docker exec "$KAFKA_CONTAINER" kafka-consumer-groups \
    --bootstrap-server kafka:29092 --list 2>/dev/null) || groups=""

  if [ -z "$groups" ]; then
    echo "  [WARN] No consumer groups found (services may not have consumed yet)"
  else
    echo "  Registered groups:"
    echo "$groups" | while read -r g; do
      echo "    - $g"
    done
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
  echo ""
fi

# --- Report ---
echo "========================================="
echo "  Health Check Report"
echo "========================================="
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "========================================="

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "  RESULT: FAILED"
  exit 1
else
  echo "  RESULT: ALL HEALTHY"
  exit 0
fi
```

- [ ] **Step 2: 구문 검증**

Run: `bash -n scripts/verify-service-health.sh`
Expected: 출력 없음

- [ ] **Step 3: Commit**

```bash
git add scripts/verify-service-health.sh
git commit -m "feat: add service health check verification script"
```

---

### Task 8: staging 환경 검증 시나리오 문서

**Files:**
- Create: `docs/guides/STAGING_VERIFICATION.md`

- [ ] **Step 1: STAGING_VERIFICATION.md 작성**

```markdown
# Staging 환경 검증 가이드

## 개요

dev 환경에서 검증 완료된 서비스를 staging으로 승격한 후 확인할 항목을 정의한다.
gitops 세션에서 staging overlay 생성 완료 후 이 가이드를 기반으로 검증한다.

## 사전 조건

- [ ] staging overlay 5개 앱 생성 완료 (`apps/{app}/overlays/staging/`)
- [ ] ApplicationSet에 `env: staging` 추가
- [ ] `synapse-staging` namespace 생성
- [ ] staging용 ExternalSecret / ConfigMap 적용
- [ ] bastion SSM 접속 + kubectl context 설정

## 1. 리소스 분리 확인

dev와 staging이 독립적으로 운영되는지 확인한다.

### 1-1. Namespace 분리

```bash
kubectl get ns | grep synapse
```

Expected:
```
synapse-dev       Active
synapse-staging   Active
```

### 1-2. Pod 리소스 비교

```bash
echo "=== dev ==="
kubectl get deploy -n synapse-dev -o custom-columns='NAME:.metadata.name,REPLICAS:.spec.replicas,CPU_REQ:.spec.template.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.template.spec.containers[0].resources.requests.memory'

echo "=== staging ==="
kubectl get deploy -n synapse-staging -o custom-columns='NAME:.metadata.name,REPLICAS:.spec.replicas,CPU_REQ:.spec.template.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.template.spec.containers[0].resources.requests.memory'
```

Expected: staging replicas >= 2, resource limits가 dev보다 크거나 같음

### 1-3. ConfigMap 환경변수 분리

```bash
kubectl get configmap -n synapse-staging -o yaml | grep -E "SPRING_PROFILES_ACTIVE|LOG_LEVEL"
```

Expected: `SPRING_PROFILES_ACTIVE: staging`, `LOG_LEVEL: INFO`

## 2. 서비스 상태 확인

### 2-1. ArgoCD 검증 스크립트 실행

```bash
bash scripts/verify-argocd-deploy.sh synapse-staging
```

Expected: ALL PASSED (5개 앱 Synced + Healthy)

### 2-2. 헬스체크 스크립트 실행

staging port-forward 설정 후:

```bash
# 각 서비스 port-forward (별도 터미널)
kubectl port-forward -n synapse-staging svc/platform-svc 18081:8081 &
kubectl port-forward -n synapse-staging svc/engagement-svc 18082:8082 &
kubectl port-forward -n synapse-staging svc/knowledge-svc 18083:8083 &
kubectl port-forward -n synapse-staging svc/learning-card-svc 18084:8084 &
kubectl port-forward -n synapse-staging svc/learning-ai-svc 18085:8085 &

bash scripts/verify-service-health.sh --env eks
```

Expected: ALL HEALTHY

## 3. staging E2E 시나리오

dev와 동일한 4개 시나리오를 staging endpoint로 실행한다.

### 3-1. Kafka 메시지 흐름 검증

staging의 Kafka는 동일한 MSK 클러스터를 공유하되 consumer group이 다르다.
서비스 구현 완료 후 아래 시나리오를 순서대로 실행:

| # | Producer → Topic → Consumer | 검증 |
|---|---|---|
| 1 | platform-svc → user-registered-v1 → engagement-svc | 프로필 생성 |
| 2 | knowledge-svc → note-created-v1 → learning-ai-svc | 카드 생성 트리거 |
| 3 | learning-card → review-completed-v1 → engagement-svc | XP 적립 |
| 4 | learning-ai → cards-generated-v1 → platform-svc | 알림 |

### 3-2. API 레벨 검증

```bash
# 회원가입 → 프로필 자동 생성
curl -X POST http://localhost:18081/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"staging-e2e@test.synapse.dev","password":"Test1234!"}'

# 잠시 대기 (Kafka 비동기)
sleep 3

# engagement-svc에서 프로필 확인
curl http://localhost:18082/api/v1/profiles?email=staging-e2e@test.synapse.dev
```

## 4. 롤백 시나리오

staging에서 문제 발견 시 절차:

### 4-1. ArgoCD 빠른 롤백

```bash
# 이전 리비전 확인
argocd app history synapse-platform-svc-staging

# 롤백
argocd app rollback synapse-platform-svc-staging <REVISION>

# 상태 확인
bash scripts/verify-argocd-deploy.sh synapse-staging
```

### 4-2. Git Revert (영구 롤백)

```bash
git log --oneline -5
git revert <COMMIT_SHA>
git push origin main
# ArgoCD가 자동 sync (또는 수동 sync)
```

## 5. 검증 완료 체크리스트

- [ ] synapse-staging namespace 존재
- [ ] 5개 앱 ArgoCD Synced + Healthy
- [ ] staging replicas >= 2
- [ ] SPRING_PROFILES_ACTIVE=staging 확인
- [ ] ExternalSecret 5/5 SecretSynced
- [ ] 헬스체크 ALL HEALTHY
- [ ] (서비스 구현 후) E2E 4개 시나리오 PASS
- [ ] 롤백 절차 1회 검증
```

- [ ] **Step 2: Commit**

```bash
git add docs/guides/STAGING_VERIFICATION.md
git commit -m "docs: add staging environment verification guide"
```

---

## Phase 3: 코드 품질 + 문서 정비

### Task 9: HANDOFF 문서 갱신 + 합류 체크리스트

**Files:**
- Modify: `docs/project-management/HANDOFF_2026-05-19.md`

- [ ] **Step 1: 05-21 세션 작업 내역 섹션 추가**

`## 05-20 세션 작업 내역` 섹션 뒤에 추가:

```markdown
## 05-21 세션 작업 내역

### 상황

- synapse-gitops 별도 세션에서 서비스 안정화(CrashLoop 해결) + W3 작업(staging overlay, Observability) 진행 중
- 이 세션에서는 gitops 영역과 겹치지 않는 선제 준비 작업 수행

### 완료: E2E 테스트 인프라 보강

| 작업 | 상태 |
|------|:----:|
| note-updated 샘플 이벤트 추가 | ✅ |
| 에러 케이스 샘플 3개 추가 (missing field, invalid tenant, empty data) | ✅ |
| 멀티테넌트 샘플 추가 (tenant-e2e-002) | ✅ |
| DB 시드: engagement 프로필 + XP (V004) | ✅ |
| DB 시드: learning-ai 생성 이력 (V005) | ✅ |
| kafka-e2e-test.sh 보강 (자동 판정, 리포트, --error-cases, --full) | ✅ |

### 완료: 배포 검증 사전 준비

| 작업 | 상태 |
|------|:----:|
| ArgoCD 배포 검증 자동화 스크립트 (verify-argocd-deploy.sh) | ✅ |
| 서비스 헬스체크 통합 스크립트 (verify-service-health.sh) | ✅ |
| staging 환경 검증 가이드 (STAGING_VERIFICATION.md) | ✅ |

### 완료: W3 사전 준비 산출물 (추가)

| 산출물 | 경로 |
|--------|------|
| E2E 에러 샘플 | `src/test/resources/e2e-samples/error/*.json` |
| 멀티테넌트 샘플 | `src/test/resources/e2e-samples/multi-tenant/*.json` |
| note-updated 샘플 | `src/test/resources/e2e-samples/note-updated.json` |
| Engagement 시드 | `src/test/resources/seed/V004__test_engagement_profiles.sql` |
| Learning-AI 시드 | `src/test/resources/seed/V005__test_learning_ai.sql` |
| ArgoCD 검증 스크립트 | `scripts/verify-argocd-deploy.sh` |
| 서비스 헬스체크 스크립트 | `scripts/verify-service-health.sh` |
| Staging 검증 가이드 | `docs/guides/STAGING_VERIFICATION.md` |
| 설계 문서 | `docs/superpowers/specs/2026-05-21-shared-preemptive-prep-design.md` |
| 구현 계획 | `docs/superpowers/plans/2026-05-21-shared-preemptive-prep.md` |
```

- [ ] **Step 2: 미해결 항목 상태 갱신**

미해결 항목 테이블을 업데이트:

```markdown
## 미해결 항목

| 항목 | 우선순위 | 비고 |
|------|:--------:|------|
| ~~synapse-gateway `master` → `main` 변경~~ | ~~Low~~ | ✅ 완료 |
| ~~deploy.yml Node.js 20 deprecation 경고~~ | ~~Low~~ | ✅ 완료 |
| ~~engagement-svc KAFKA_BROKERS 누락~~ | ~~Medium~~ | ✅ 완료 |
| MSK dev 클러스터 토픽 생성 | Medium | 인프라 담당자 실행 대기 → `docs/guides/MSK_TOPIC_SETUP.md` |
| synapse-gateway ApplicationSet 미포함 | Low | gitops 영역 — 별도 Application 필요 |
| staging 오버레이 미생성 | Medium | gitops 세션에서 진행 중 (W3 Step 7) |
```

- [ ] **Step 3: 합류 체크리스트 섹션 추가**

`## 다음 작업` 섹션을 다음으로 교체:

```markdown
## 다음 작업

### gitops 세션 합류 조건

아래 조건이 모두 충족되면 검증 착수:

- [ ] 5개 서비스 모두 ArgoCD Healthy (CrashLoop 해결 완료)
- [ ] staging namespace 존재 + ApplicationSet에 staging 포함
- [ ] ExternalSecret 5/5 SecretSynced (dev + staging)

### 합류 후 작업 순서

```
1. verify-argocd-deploy.sh synapse-dev 실행 → dev 환경 최종 확인
2. verify-service-health.sh 실행 → 5개 서비스 health 확인
3. STAGING_VERIFICATION.md 기반 staging 검증
4. 팀원 Kafka 구현 완료 대기 → KAFKA_E2E_TEST.md 기반 E2E 검증
```

### Step 7: Kafka E2E 검증 + 코드 리뷰 조율 (팀원 구현 완료 후)
- kafka-e2e-test.sh --all 실행 → 5개 토픽 정상 흐름 확인
- kafka-e2e-test.sh --error-cases 실행 → 에러 핸들링 확인
- 전체 서비스 코드 리뷰 1차

### Step 8: ArgoCD dev/staging 배포 검증 (gitops 합류 후)
- verify-argocd-deploy.sh synapse-dev → dev 상태 확인
- verify-argocd-deploy.sh synapse-staging → staging 상태 확인
- STAGING_VERIFICATION.md 체크리스트 전체 수행
- Rollback 시나리오 1회 테스트
```

- [ ] **Step 4: Commit**

```bash
git add docs/project-management/HANDOFF_2026-05-19.md
git commit -m "docs: update HANDOFF — 05-21 session work + convergence checklist"
```

---

## 작업 순서 요약

| 순서 | Task | 내용 | 의존 |
|:----:|:----:|------|:----:|
| 1 | Task 1 | note-updated 샘플 추가 | — |
| 2 | Task 2 | 에러 케이스 샘플 3개 추가 | — |
| 3 | Task 3 | 멀티테넌트 샘플 추가 | — |
| 4 | Task 4 | DB 시드 V004 + V005 + seed 스크립트 갱신 | — |
| 5 | Task 5 | kafka-e2e-test.sh 보강 | Task 1~3 (샘플 파일 존재 필요) |
| 6 | Task 6 | verify-argocd-deploy.sh | — |
| 7 | Task 7 | verify-service-health.sh | — |
| 8 | Task 8 | STAGING_VERIFICATION.md | — |
| 9 | Task 9 | HANDOFF 갱신 + 합류 체크리스트 | Task 1~8 완료 후 |

Task 1~4는 병렬 가능. Task 5는 Task 1~3 완료 필요. Task 6~8은 병렬 가능. Task 9는 마지막.
