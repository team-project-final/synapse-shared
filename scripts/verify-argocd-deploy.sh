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
  # Application CRD 직접 조회 우선 — argocd CLI 세션 불필요 (SSM 터널은 port-forward
  # 업그레이드가 차단돼 argocd login 자체가 불가, W5 Day1 실측). CRD 미접근 시에만 CLI 폴백.
  app_json=$(kubectl -n argocd get application "$app_name" -o json 2>/dev/null) \
    || app_json=$(argocd app get "$app_name" -o json 2>/dev/null) || app_json=""
  sync_status=$(jq -r '.status.sync.status // "UNKNOWN"' <<<"$app_json" 2>/dev/null) || sync_status="UNKNOWN"
  health_status=$(jq -r '.status.health.status // "UNKNOWN"' <<<"$app_json" 2>/dev/null) || health_status="UNKNOWN"

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
