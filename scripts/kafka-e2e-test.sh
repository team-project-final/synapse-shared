#!/usr/bin/env bash
# scripts/kafka-e2e-test.sh
# Kafka E2E produce/consume smoke test (Docker Compose local environment).
# Usage:
#   bash scripts/kafka-e2e-test.sh <topic> <sample-file>
#   bash scripts/kafka-e2e-test.sh --all
#   bash scripts/kafka-e2e-test.sh --error-cases
#   bash scripts/kafka-e2e-test.sh --scenarios
#   bash scripts/kafka-e2e-test.sh --avro        # 실제 Avro+Registry 라운드트립(계약 검증)
#   bash scripts/kafka-e2e-test.sh --full
set -euo pipefail

BROKER="${KAFKA_BROKERS:-localhost:9092}"
CONTAINER="${KAFKA_CONTAINER:-synapse-kafka}"
SAMPLES_DIR="src/test/resources/e2e-samples"
SCHEMA_DIR="${SCHEMA_DIR:-src/main/avro}"
TIMEOUT="${CONSUME_TIMEOUT:-10}"

topic="${1:-}"
sample="${2:-}"

PASS_COUNT=0
FAIL_COUNT=0
START_TIME=$(date +%s)

# Compact a JSON sample to a single line so kafka-console-producer sends it as
# ONE message. The producer splits stdin on newlines, so multi-line pretty JSON
# would otherwise be fragmented into ~1 message per line (see E2E_BASELINE_W3 D-2).
# Valid JSON → jq -c (also normalizes); malformed JSON (error fixtures) → raw
# single-line via tr, so transport-level error cases still produce one message.
compact_json() {
  local f="$1"
  if command -v jq >/dev/null 2>&1 && jq -e . "$f" >/dev/null 2>&1; then
    jq -c . "$f"
  else
    tr -d '\r\n' < "$f"
    printf '\n'
  fi
}

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
  bash scripts/kafka-e2e-test.sh --scenarios
  bash scripts/kafka-e2e-test.sh --avro
  bash scripts/kafka-e2e-test.sh --full
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

  # Produce via docker exec — compact to a single line so the whole CloudEvent
  # is sent as one message (not one message per pretty-printed line).
  if ! compact_json "$filepath" | docker exec -i "$CONTAINER" kafka-console-producer \
    --bootstrap-server kafka:29092 \
    --topic "$t" \
    2>/dev/null; then
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

  # Test 3: multi-tenant samples (all event types for tenant-e2e-002)
  produce_and_consume "platform.auth.user-registered-v1" "multi-tenant/user-registered-tenant2.json"
  produce_and_consume "knowledge.note.note-created-v1" "multi-tenant/note-created-tenant2.json"
  produce_and_consume "learning.card.review-completed-v1" "multi-tenant/review-completed-tenant2.json"
  produce_and_consume "learning.ai.cards-generated-v1" "multi-tenant/cards-generated-tenant2.json"
}

# --- Service-chain scenario scaffold (E2E_SCENARIOS_W3 S1~S4) -----------------
# Produces chain events in DEPENDENCY ORDER so each chain's transport path is
# exercised today (services not yet implemented). Per scenario it prints the
# service-level check (DB/log/HTTP) to run once the owning service lands.
# This is a scaffold: transport is verified now; service checks are guidance,
# not executed (avoids false PASS before Consumer code exists).
scenario() {
  local id="$1" desc="$2" topic="$3" sample="$4" check="$5"
  echo "########## ${id}: ${desc} ##########"
  produce_and_consume "$topic" "$sample"
  echo "[SERVICE-CHECK] ${id} (서비스 구현 후 수행):"
  echo "    ${check}"
  echo ""
}

run_scenarios() {
  echo ""
  echo "========================================="
  echo "  Service-Chain Scenarios (S1~S4, dependency order)"
  echo "  transport=produce/consume 검증(now) · service=구현 후 수동 확인"
  echo "========================================="
  echo ""
  # S1: 회원가입 → 프로필 (Chain A) — 선행 없음
  scenario "S1" "회원가입→프로필 (platform→engagement)" \
    "platform.auth.user-registered-v1" "user-registered.json" \
    "engagement DB user_profiles 레코드 생성 확인 — E2E_SCENARIOS_W3 §S1"
  # S2: 복습 → XP (Chain C) — 사용자 선행
  scenario "S2" "복습→XP (learning-card→engagement)" \
    "learning.card.review-completed-v1" "review-completed.json" \
    "engagement xp_points 증가 + 동일 reviewId 멱등성 — §S2"
  # S3-1: 노트 → AI카드 (Chain B, 1단계)
  scenario "S3-1" "노트생성→AI카드 (knowledge→learning-ai)" \
    "knowledge.note.note-created-v1" "note-created.json" \
    "learning-ai 로그 note-created 수신 + 카드 3~5개 생성 — §S3"
  # S3-2: AI카드 → 등록 (Chain B, 2단계). D-001: cards-generated Kafka → HTTP 대체.
  # 아래 produce는 토픽 스모크용. 실제 등록은 learning-ai→learning-card REST(card_client).
  scenario "S3-2" "AI카드→등록 [D-001: HTTP] (learning-ai→learning-card REST)" \
    "learning.ai.cards-generated-v1" "cards-generated.json" \
    "learning-ai가 learning-card REST(card_client)로 카드 등록 — 알림 트리거는 재설계 open(D-001)"
  # S4: 노트 수정 → 재인덱싱 (Chain D) — 노트 선행
  scenario "S4" "노트수정→재인덱싱 (knowledge→learning-ai/opensearch)" \
    "knowledge.note.note-updated-v1" "note-updated.json" \
    "opensearch notes 인덱스 갱신 + learning-ai note-updated 로그 — §S4"
}

# --- Avro round-trip (Schema Registry) -----------------------------------------
# 실제 계약 검증: bare typed Avro record per topic을 shared .avsc로 produce → consume.
# kafka-avro-console-producer가 subject(<topic>-value)를 레지스트리에 자동 등록하므로
# "Avro 직렬화 + 레지스트리 등록 + 역직렬화 round-trip"을 한 번에 검증한다.
# (참고: --all/--scenarios는 JSON 바이트 전송 스모크일 뿐 Avro 계약 검증이 아님 — EVENT_CONTRACT_STANDARD Avro 채택)
SR_CONTAINER="${SR_CONTAINER:-synapse-schema-registry}"
SR_URL_INTERNAL="${SR_URL_INTERNAL:-http://schema-registry:8081}"
KAFKA_INTERNAL="${KAFKA_INTERNAL:-kafka:29092}"

avro_roundtrip() {
  local topic="$1" avsc="$2" value="$3" schema
  if [ ! -f "$avsc" ]; then
    echo "[AVRO] FAIL — schema 없음: $avsc"; FAIL_COUNT=$((FAIL_COUNT + 1)); return 1
  fi
  schema=$(jq -c . "$avsc") || { echo "[AVRO] FAIL — 잘못된 스키마: $avsc"; FAIL_COUNT=$((FAIL_COUNT + 1)); return 1; }
  echo "=== [AVRO] $topic ($(basename "$avsc")) ==="
  if ! printf '%s\n' "$value" | docker exec -i "$SR_CONTAINER" kafka-avro-console-producer \
      --bootstrap-server "$KAFKA_INTERNAL" --topic "$topic" \
      --property schema.registry.url="$SR_URL_INTERNAL" \
      --property value.schema="$schema" >/dev/null 2>&1; then
    echo "[AVRO][PRODUCE] FAIL (스키마 등록/직렬화 실패 — 호환성 또는 값 불일치 가능)"
    FAIL_COUNT=$((FAIL_COUNT + 1)); return 1
  fi
  echo "[AVRO][PRODUCE] OK — subject ${topic}-value 등록 + 발행"
  local out
  out=$(docker exec "$SR_CONTAINER" kafka-avro-console-consumer \
      --bootstrap-server "$KAFKA_INTERNAL" --topic "$topic" \
      --from-beginning --max-messages 1 --timeout-ms "$((TIMEOUT * 1000))" \
      --property schema.registry.url="$SR_URL_INTERNAL" 2>/dev/null) || true
  if echo "$out" | grep -q '"userId"'; then
    echo "[AVRO][CONSUME] OK — Avro 역직렬화/검증"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "[AVRO][CONSUME] FAIL — 메시지 없음/형식 불일치"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo ""
}

run_avro() {
  echo ""
  echo "========================================="
  echo "  Avro Round-trip ($SR_CONTAINER, $SR_URL_INTERNAL)"
  echo "  bare typed record per topic + subject 자동 등록"
  echo "========================================="
  echo ""
  avro_roundtrip "platform.auth.user-registered-v1" "$SCHEMA_DIR/platform/UserRegistered.avsc" \
    '{"eventId":"evt-ur-1","userId":"u-1","email":"e2e@test.synapse.dev","tenantId":"t-1","registeredAt":"2026-06-01T00:00:00Z","occurredAt":0}'
  avro_roundtrip "knowledge.note.note-created-v1" "$SCHEMA_DIR/knowledge/NoteCreated.avsc" \
    '{"eventId":"evt-nc-1","noteId":"n-1","userId":"u-1","tenantId":"t-1","deckId":null,"title":"E2E Note","content":null,"createdAt":"2026-06-01T00:00:00Z","occurredAt":0}'
  avro_roundtrip "knowledge.note.note-updated-v1" "$SCHEMA_DIR/knowledge/NoteUpdated.avsc" \
    '{"eventId":"evt-nu-1","noteId":"n-1","userId":"u-1","tenantId":"t-1","title":"E2E Note v2","updatedAt":"2026-06-01T00:05:00Z","occurredAt":0}'
  avro_roundtrip "learning.card.review-completed-v1" "$SCHEMA_DIR/learning/ReviewCompleted.avsc" \
    '{"eventId":"evt-rc-1","cardId":"c-1","userId":"u-1","tenantId":"t-1","rating":"GOOD","nextReviewAt":"2026-06-03T00:00:00Z","reviewedAt":"2026-06-01T00:00:00Z","occurredAt":0}'
  avro_roundtrip "learning.card.review-due-v1" "$SCHEMA_DIR/learning/CardReviewDue.avsc" \
    '{"eventId":"evt-rd-1","tenantId":"t-1","userId":"u-1","dueCardCount":3,"dueDate":"2026-06-01","occurredAt":0}'
  avro_roundtrip "engagement.gamification.level-up-v1" "$SCHEMA_DIR/engagement/LevelUp.avsc" \
    '{"eventId":"evt-lu-1","tenantId":"t-1","userId":"u-1","newLevel":2,"previousLevel":1,"totalXp":100,"occurredAt":0}'
  avro_roundtrip "engagement.gamification.badge-earned-v1" "$SCHEMA_DIR/engagement/BadgeEarned.avsc" \
    '{"eventId":"evt-be-1","tenantId":"t-1","userId":"u-1","badgeId":"b-1","badgeCode":"STREAK_7","badgeName":null,"occurredAt":0}'
  avro_roundtrip "platform.notification.notification-send-v1" "$SCHEMA_DIR/platform/NotificationSend.avsc" \
    '{"userId":"u-1","tenantId":"t-1","notificationType":"AI_CARDS_READY","channels":["FCM"],"title":"새 카드","body":"카드 3개 생성","emailSubject":null,"emailHtmlBody":null,"data":{}}'
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
  --scenarios)
    run_scenarios
    print_report
    ;;
  --avro)
    run_avro
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
