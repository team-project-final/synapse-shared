# W3 배포 검증 실행 플레이북 (EKS 재기동 윈도용)

> **작성**: 2026-06-04 — W3 워크플로 §1.7~§1.9 미완료 항목의 **실행 설계**.
> **상태**: ⛔ **실행 차단** — 현재 EKS dev/staging이 destroy 상태(과금 차단). 본 문서는 **재기동 윈도에서 그대로 실행 가능한 turnkey 절차**다.
> **선행**: `terraform apply` + `scripts/bring-up.sh`(gitops)로 dev(+staging) 부트스트랩 완료, SSM 터널 kubeconfig 연결.
> **참조**: gitops `docs/runbooks/w2-dev-deploy-runbook.md`, `docs/reports/DEPLOY_REPORT_W3.md` §A·§B, [EVENT_FLOW_MATRIX](./EVENT_FLOW_MATRIX.md), 결정 [D-003 검색 엔진](../designs/D-003_SEARCH_ENGINE_DECISION.md).

각 항목 = **명령 → 기대 출력 → Pass/Fail 기준**. 항목 번호는 `WORKFLOW_team-lead_W3.md` 체크박스와 1:1 대응.

---

## §1.7 배포 실행

### 1.7-a dev 환경: main push → autoSync 자동 배포 확인
ArgoCD dev Application은 `syncPolicy.automated`(autoSync: true). gitops main에 매니페스트 push 시 자동 반영.
```bash
# gitops main에 dev 매니페스트 변경 push 후
argocd app list -l env=dev
argocd app get synapse-platform-svc-dev --refresh
```
- **Pass**: 대상 App `SYNC STATUS=Synced`, `HEALTH=Healthy`, `REVISION`=방금 push한 커밋 SHA. 자동 동기화 트리거(수동 sync 불요).
- **Fail**: `OutOfSync`가 3분 이상 지속 → §1.9 로그 수집.

### 1.7-b staging 환경: 수동 Sync 버튼 → 배포 실행
staging Application은 `syncPolicy: manual`(자동 배포 금지).
```bash
argocd app sync synapse-platform-svc-staging
argocd app wait synapse-platform-svc-staging --health --timeout 300
```
- **Pass**: 수동 sync 후 `Synced/Healthy`. 자동으로는 배포되지 않았음을 사전 확인(manual 정책 증명).

### 1.7-c ECR 이미지 태그 일치 확인
오버레이 `newTag`(또는 image-updater write-back) = ECR 실제 태그.
```bash
# 오버레이가 가리키는 태그
grep -r 'newTag' apps/*/overlays/dev/kustomization.yaml
# ECR 실제 태그
aws ecr describe-images --repository-name synapse/platform-svc --region ap-northeast-2 \
  --query 'sort_by(imageDetails,&imagePushedAt)[-3:].imageTags' --output table
# 파드가 실제 끌어온 이미지
kubectl -n synapse-dev get pods -l app.kubernetes.io/name=platform-svc \
  -o jsonpath='{.items[*].spec.containers[*].image}'
```
- **Pass**: 오버레이 태그 == ECR 최신 태그 == 파드 image. 5개 서비스 모두 일치.
- **Fail**: 불일치 → image-updater 상태 또는 newTag 갱신 확인.

---

## §1.8 배포 후 검증

### 1.8-a dev 전체 서비스 Health OK
```bash
kubectl -n synapse-dev get pods
argocd app list -l env=dev -o name | xargs -I{} argocd app get {} --refresh -o json | jq -r '.metadata.name + " " + .status.health.status'
```
- **Pass**: platform/engagement/knowledge/learning-card/learning-ai(+gateway) 전부 `Running` 1/1, ArgoCD `Healthy`. (gateway는 배포 경로 확정 시 포함 — gitops PR/플랜 참조.)

### 1.8-b staging 전체 서비스 Health OK
```bash
kubectl -n synapse-staging get pods
```
- **Pass**: 전 서비스 `Running` 1/1. (W3 라이브에서 platform-svc-staging은 `application-staging.yml` 미연결로 CrashLoop했던 이력 → 이슈 #92/#48 선반영 확인.)

### 1.8-c Kafka 연결 상태 (consumer group lag = 0)
> ⚠️ **선행**: W4 Kafka consumer 배포 + MSK TLS(SSL) 앱 배선 필요(메모리 `kafka-tls-msk-app-readiness-gap`). consumer 미배포 시 본 항목은 측정 불가 → W4 이후.
```bash
kubectl -n synapse-dev exec deploy/<consumer-svc> -- \
  kafka-consumer-groups --bootstrap-server $KAFKA_BROKERS --describe --group engagement-svc-group
```
- **Pass**: 각 consumer group `LAG=0`(또는 정상 처리 후 0 수렴), `STATE=Stable`.

### 1.8-d RDS / Redis / Elasticsearch 연결 상태
> 검색 엔진은 **Elasticsearch**(D-003). 인클러스터 ES(`elasticsearch:9200`) 또는 환경별 ES 엔드포인트.
```bash
# RDS
kubectl -n synapse-dev exec deploy/platform-svc -- sh -c 'nc -zv $DATABASE_HOST 5432'
# Redis
kubectl -n synapse-dev exec deploy/platform-svc -- sh -c 'nc -zv $SPRING_DATA_REDIS_HOST 6379'
# Elasticsearch (knowledge-svc)
kubectl -n synapse-dev exec deploy/knowledge-svc -- sh -c 'curl -s $ELASTICSEARCH_URIS/_cluster/health'
```
- **Pass**: RDS/Redis TCP 연결 OK, ES `/_cluster/health` `status: green|yellow`(single-node는 yellow 정상). knowledge-svc 부팅 로그에 ES 연결 에러 없음.

---

## §1.9 배포 이슈 대응

### 1.9-a 배포 실패 시 롤백 절차 실행 및 검증
DEPLOY_REPORT §B 5단계 롤백(목표 <3분) 실행.
```bash
# ArgoCD 이전 정상 리비전으로 롤백
argocd app history synapse-platform-svc-dev
argocd app rollback synapse-platform-svc-dev <PREV_REVISION_ID>
argocd app wait synapse-platform-svc-dev --health --timeout 180
```
- **Pass**: 롤백 후 `Healthy` 복귀까지 < 3분(W3 라이브 engagement 124s 실측 기준). 파드 이전 이미지로 복귀 확인.

### 1.9-b 환경별 로그 수집 및 이슈 분석
```bash
for svc in platform-svc engagement-svc knowledge-svc learning-card learning-ai; do
  echo "=== $svc ==="; kubectl -n synapse-dev logs deploy/$svc --tail=50 | grep -iE 'error|exception|fail'
done
```
- **Pass**: 치명 에러 분류·기록(또는 0건). CrashLoop 시 `kubectl describe pod` + 직전 로그(`--previous`) 수집.

### 1.9-c 배포 성공 기준 충족 여부 최종 확인
- **Pass(전 항목 충족)**: §1.7 a/b/c + §1.8 a/b/d 전부 Pass(§1.8-c는 W4 이후), §1.9-a 롤백 검증 OK. → `W3_EXIT_GATE.md` 갱신.

---

## 실행 체크리스트 (윈도 시작 시 순서)
1. `terraform apply` + `bring-up.sh`로 dev(+staging) 부트스트랩, SSM 터널.
2. §1.7 a→b→c (배포 실행 + 태그 정합).
3. §1.8 a→b→d (Health + 데이터스토어). §1.8-c는 W4 consumer 후.
4. §1.9-a 롤백 1회 검증.
5. §1.9-c 최종 게이트 + `terraform destroy`(과금 차단).
