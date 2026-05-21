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
