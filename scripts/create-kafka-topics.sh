#!/usr/bin/env bash
# scripts/create-kafka-topics.sh
# Create Kafka topics on MSK cluster.
# Usage: KAFKA_BROKERS=<broker-list> bash scripts/create-kafka-topics.sh
set -euo pipefail

BROKER="${KAFKA_BROKERS:?Set KAFKA_BROKERS env var}"
REPLICATION="${REPLICATION_FACTOR:-3}"
TOPICS=(
  "platform.auth.user-registered-v1"
  "knowledge.note.note-created-v1"
  "knowledge.note.note-updated-v1"
  "learning.card.review-completed-v1"
  "learning.ai.cards-generated-v1"
)

for topic in "${TOPICS[@]}"; do
  echo "Creating topic: $topic"
  kafka-topics.sh --bootstrap-server "$BROKER" \
    --create --if-not-exists \
    --topic "$topic" \
    --partitions 3 \
    --replication-factor "$REPLICATION" \
    --config retention.ms=604800000 \
    --config cleanup.policy=delete
done

echo "Topics:"
kafka-topics.sh --bootstrap-server "$BROKER" --list
