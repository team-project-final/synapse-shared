#!/usr/bin/env bash
# scripts/kafka-e2e-test.sh
# Kafka E2E produce/consume smoke test (Docker Compose local environment).
# Usage: bash scripts/kafka-e2e-test.sh [topic] [sample-file]
# Example: bash scripts/kafka-e2e-test.sh platform.auth.user-registered-v1 user-registered.json
set -euo pipefail

BROKER="${KAFKA_BROKERS:-localhost:9092}"
CONTAINER="${KAFKA_CONTAINER:-synapse-kafka}"
SAMPLES_DIR="src/test/resources/e2e-samples"
TIMEOUT="${CONSUME_TIMEOUT:-10}"

topic="${1:-}"
sample="${2:-}"

usage() {
  echo "Usage: bash $0 <topic> <sample-json>"
  echo ""
  echo "Topics:"
  echo "  platform.auth.user-registered-v1"
  echo "  knowledge.note.note-created-v1"
  echo "  knowledge.note.note-updated-v1"
  echo "  learning.card.review-completed-v1"
  echo "  learning.ai.cards-generated-v1"
  echo ""
  echo "Example:"
  echo "  bash $0 platform.auth.user-registered-v1 user-registered.json"
  echo ""
  echo "Run all:"
  echo "  bash $0 --all"
}

produce_and_consume() {
  local t="$1" f="$2"
  local filepath="$SAMPLES_DIR/$f"

  if [ ! -f "$filepath" ]; then
    echo "ERROR: Sample file not found: $filepath"
    return 1
  fi

  echo "=== Testing: $t ==="
  echo "[PRODUCE] Sending message from $f ..."

  # Produce via docker exec
  docker exec -i "$CONTAINER" kafka-console-producer \
    --bootstrap-server kafka:29092 \
    --topic "$t" \
    < "$filepath"

  echo "[PRODUCE] OK"

  echo "[CONSUME] Reading from $t (timeout=${TIMEOUT}s) ..."
  docker exec "$CONTAINER" kafka-console-consumer \
    --bootstrap-server kafka:29092 \
    --topic "$t" \
    --from-beginning \
    --max-messages 1 \
    --timeout-ms "$((TIMEOUT * 1000))"

  echo "[CONSUME] OK"
  echo ""
}

if [ "$topic" = "--all" ]; then
  produce_and_consume "platform.auth.user-registered-v1" "user-registered.json"
  produce_and_consume "knowledge.note.note-created-v1" "note-created.json"
  produce_and_consume "learning.card.review-completed-v1" "review-completed.json"
  produce_and_consume "learning.ai.cards-generated-v1" "cards-generated.json"
  echo "=== All E2E smoke tests passed ==="
elif [ -n "$topic" ] && [ -n "$sample" ]; then
  produce_and_consume "$topic" "$sample"
else
  usage
  exit 1
fi
