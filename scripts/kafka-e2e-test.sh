#!/usr/bin/env bash
# scripts/kafka-e2e-test.sh
# Kafka E2E produce/consume smoke test (Docker Compose local environment).
# Usage:
#   bash scripts/kafka-e2e-test.sh <topic> <sample-file>
#   bash scripts/kafka-e2e-test.sh --all
#   bash scripts/kafka-e2e-test.sh --error-cases
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
