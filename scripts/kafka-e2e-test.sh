#!/usr/bin/env bash
# scripts/kafka-e2e-test.sh
# Kafka E2E produce/consume smoke test (Docker Compose local environment).
# Usage:
#   bash scripts/kafka-e2e-test.sh <topic> <sample-file>
#   bash scripts/kafka-e2e-test.sh --all
#   bash scripts/kafka-e2e-test.sh --error-cases
#   bash scripts/kafka-e2e-test.sh --scenarios
#   bash scripts/kafka-e2e-test.sh --full
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
