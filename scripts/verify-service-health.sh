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
