# ArgoCD Dev/Staging 배포 검증 가이드

## 현재 ArgoCD 구성 요약

### ApplicationSet (`argocd/applicationset.yaml`)

- **Generator**: Matrix (5 services x environments)
- **Services**: platform-svc, engagement-svc, knowledge-svc, learning-card, learning-ai
- **Environments**: dev (자동 sync, `applicationset.yaml`), staging (수동 sync, `applicationset-staging.yaml`)
- **Sync Policy**: dev=automated (prune: true, selfHeal: true), staging=manual
- **Source**: `synapse-gitops` repo, `apps/{service}/overlays/{env}` 경로
- **targetRevision**: `main`

### 서비스별 오버레이 구조

```
apps/
├── platform-svc/
│   ├── base/              (deployment, service, configmap, externalsecret)
│   └── overlays/
│       ├── dev/           (replicas=1, DEBUG, automated sync)
│       └── staging/       (replicas=2, INFO, manual sync)
├── engagement-svc/
│   ├── base/
│   └── overlays/{dev,staging}/
├── knowledge-svc/
│   ├── base/
│   └── overlays/{dev,staging}/
├── learning-card/
│   ├── base/
│   └── overlays/{dev,staging}/
└── learning-ai/
    ├── base/
    └── overlays/{dev,staging}/
```

### Staging 환경 현황 (2026-05-21 갱신)

- staging overlay 생성 완료 (5개 서비스)
- ApplicationSet: `synapse-apps-staging` (수동 Sync)
- namespace: `synapse-staging`
- replicas: 2, LOG_LEVEL: INFO, SPRING_PROFILES_ACTIVE: staging

```bash
# Staging 앱 상태 확인
kubectl get applications -n argocd -l environment=staging

# Staging 수동 Sync
argocd app sync synapse-<service>-staging

# Staging Pod 확인
kubectl get pods -n synapse-staging
```

### 이미지 업데이트 전략

- **ArgoCD Image Updater** 사용 (semver 태그 매칭)
- ECR: `963773969059.dkr.ecr.ap-northeast-2.amazonaws.com/synapse/{service}`
- Write-back: Git (kustomization)

> **주의**: synapse-gateway는 ApplicationSet에 미포함. 별도 Application 또는 ApplicationSet 확장 필요.

## Dev 환경 배포 검증

### Step 1: ArgoCD 접속

```bash
# ArgoCD 서버 포트포워드 (EKS 클러스터에서)
kubectl port-forward svc/argocd-server -n argocd 8443:443

# 브라우저: https://localhost:8443
# 또는 CLI:
argocd login localhost:8443 --insecure
```

### Step 2: Application 상태 확인

```bash
# 전체 Application 목록
argocd app list

# 개별 서비스 상태
argocd app get synapse-platform-svc-dev
argocd app get synapse-engagement-svc-dev
argocd app get synapse-knowledge-svc-dev
argocd app get synapse-learning-card-dev
argocd app get synapse-learning-ai-dev
```

Expected: 각 앱이 `Synced` + `Healthy` 상태

### Step 3: Pod 상태 확인

```bash
kubectl get pods -n synapse-dev
kubectl describe pod -n synapse-dev -l app.kubernetes.io/component=platform-svc
```

Expected: 모든 Pod `Running`, readiness/liveness probe 통과

### Step 4: 서비스 간 네트워크 확인

```bash
# Gateway → 각 서비스 통신 (gateway Pod에서)
kubectl exec -n synapse-dev deploy/gateway -- curl -s http://platform-svc:8081/actuator/health
kubectl exec -n synapse-dev deploy/gateway -- curl -s http://engagement-svc:8082/actuator/health
kubectl exec -n synapse-dev deploy/gateway -- curl -s http://knowledge-svc:8083/actuator/health
kubectl exec -n synapse-dev deploy/gateway -- curl -s http://learning-card-svc:8084/actuator/health
```

### Step 5: Kafka 연결 확인

```bash
# 서비스 로그에서 Kafka 연결 확인
kubectl logs -n synapse-dev deploy/platform-svc | grep -i "kafka\|bootstrap"
```

Expected: Kafka bootstrap 연결 성공 로그

## Staging 환경 배포 검증

### 사전 작업: staging 오버레이 생성

각 서비스의 `overlays/staging/kustomization.yaml` 생성 필요:
- replicas: 2 (HA)
- LOG_LEVEL: INFO
- SPRING_PROFILES_ACTIVE: staging
- staging DB/Redis/Kafka endpoints

ApplicationSet generator에 `env: staging` 추가:

```yaml
- list:
    elements:
      - env: dev
      - env: staging  # 추가
```

### Manual Sync 워크플로

Staging은 자동 sync 대신 수동 승인:

```yaml
syncPolicy:
  # automated 제거 → 수동 sync
  syncOptions:
    - CreateNamespace=true
```

```bash
# 수동 sync 실행
argocd app sync synapse-platform-svc-staging
```

### Dev → Staging 프로모션 절차

1. Dev에서 검증 완료된 이미지 태그 확인
2. Staging kustomization에 동일 태그 설정
3. PR → main 머지 → ArgoCD manual sync

```bash
# Dev 이미지 태그 확인
kubectl get deploy -n synapse-dev platform-svc -o jsonpath='{.spec.template.spec.containers[0].image}'

# Staging kustomization 업데이트
cd apps/platform-svc/overlays/staging
kustomize edit set image 963773969059.dkr.ecr.ap-northeast-2.amazonaws.com/synapse/platform-svc:TAG
```

## Rollback 절차

### ArgoCD Rollback (빠른 복구)

```bash
# 이전 배포 이력 확인
argocd app history synapse-platform-svc-dev

# 특정 리비전으로 롤백
argocd app rollback synapse-platform-svc-dev <REVISION>
```

### Git Revert (영구 롤백)

```bash
# 문제 커밋 식별
git log --oneline -5

# Revert 커밋
git revert <COMMIT_SHA>
git push

# ArgoCD가 자동 sync (dev) 또는 수동 sync (staging)
```

### 긴급 롤백 체크리스트

- [ ] 문제 서비스 식별
- [ ] ArgoCD에서 이전 리비전으로 롤백
- [ ] Pod 상태 확인 (Running, Healthy)
- [ ] 헬스체크 통과 확인
- [ ] 로그에서 에러 없음 확인
- [ ] 원인 분석 후 Git revert PR 생성
