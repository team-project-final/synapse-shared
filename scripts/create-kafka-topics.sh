#!/usr/bin/env bash
# scripts/create-kafka-topics.sh
# Create Kafka topics on MSK cluster (idempotent).
# Usage:
#   KAFKA_BROKERS=<broker-list> bash scripts/create-kafka-topics.sh
#   KAFKA_BROKERS=<broker-list> REPLICATION_FACTOR=1 bash scripts/create-kafka-topics.sh  # local
set -euo pipefail

BROKER="${KAFKA_BROKERS:?Set KAFKA_BROKERS env var (e.g. b-1.msk:9094,b-2.msk:9094)}"
REPLICATION="${REPLICATION_FACTOR:-3}"
MIN_ISR="${MIN_INSYNC_REPLICAS:-2}"
LOG_FILE="kafka-topics-$(date +%Y%m%d-%H%M%S).log"

TOPICS=(
  "platform.auth.user-registered-v1"
  "knowledge.note.note-created-v1"
  "knowledge.note.note-updated-v1"
  "learning.card.review-completed-v1"
  # W4 신규 (이벤트 계약 표준 §2)
  "learning.card.review-due-v1"
  "engagement.gamification.level-up-v1"
  "engagement.gamification.badge-earned-v1"
  "platform.notification.notification-send-v1"
  # deprecated (D-001: 카드 등록은 HTTP) — 발행자 없음, 호환 위해 잔존
  "learning.ai.cards-generated-v1"
)

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }

# --- 1. Connection check ---
log "Checking connection to $BROKER ..."
if ! kafka-broker-api-versions.sh --bootstrap-server "$BROKER" --timeout 10000 > /dev/null 2>&1; then
  log "ERROR: Cannot connect to Kafka broker at $BROKER"
  log "Check: VPN/Bastion connection, security group, bootstrap server address"
  exit 1
fi
log "Connection OK"

# --- 2. Create topics ---
created=0
skipped=0
for topic in "${TOPICS[@]}"; do
  existing=$(kafka-topics.sh --bootstrap-server "$BROKER" --list 2>/dev/null | grep -cx "$topic" || true)
  if [ "$existing" -ge 1 ]; then
    log "SKIP (exists): $topic"
    ((skipped++))
  else
    log "CREATE: $topic (partitions=3, rf=$REPLICATION, min.isr=$MIN_ISR)"
    kafka-topics.sh --bootstrap-server "$BROKER" \
      --create \
      --topic "$topic" \
      --partitions 3 \
      --replication-factor "$REPLICATION" \
      --config retention.ms=604800000 \
      --config cleanup.policy=delete \
      --config min.insync.replicas="$MIN_ISR" \
      2>&1 | tee -a "$LOG_FILE"
    ((created++))
  fi
done

# --- 3. Verify ---
log ""
log "=== Result: created=$created, skipped=$skipped ==="
log "Current topics on cluster:"
kafka-topics.sh --bootstrap-server "$BROKER" --list 2>&1 | tee -a "$LOG_FILE"
log ""
log "Log saved to $LOG_FILE"
