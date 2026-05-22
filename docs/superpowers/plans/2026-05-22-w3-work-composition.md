# W3 작업 구성 구현 계획 — shared + gitops 통합

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** W3 4영업일 동안 gitops+shared 두 레포에서 인프라 기동, Staging 배포, Observability 설치, Kafka E2E 검증, 코드 리뷰 조율, terraform state 정리를 완료한다.

**Architecture:** 매일 gitops 세션(선행) → shared 세션(후행) 순차 진행. gitops 세션에서 인프라/배포/모니터링을 처리하고, shared 세션에서 문서/E2E/리뷰를 처리한다. 4개 트랙(인프라+Staging, Observability, Kafka E2E+리뷰, terraform state)을 Day 1~4에 분산 배치.

**Tech Stack:** Terraform, EKS, MSK(Kafka), ArgoCD, kube-prometheus-stack (Helm), Grafana, Docker Compose, Avro/Schema Registry, bash scripts

**Spec:** `docs/superpowers/specs/2026-05-22-w3-work-composition-design.md`

**드롭 우선순위 (시간 부족 시):**
- 절대 보호: Task 1~2 (인프라) + Task 5~6 (E2E/리뷰) + Task 7~8 (전체 E2E/핸드오프)
- 1차 드롭: Task 4 내 3-3 terraform state 정리 → W4 이월
- 2차 드롭: Task 3~4 Observability → Grafana 대시보드만 W4 이월, 설치는 유지

---

## Task 1: Day 1 gitops — 인프라 기동 + MSK + 보안 1차

> **레포**: synapse-gitops
> **전제조건**: terraform state가 S3에 존재, AWS credentials 설정 완료
> **참조**: `docs/guides/MSK_TOPIC_SETUP.md` "다음 세션 실행 절차" 섹션

**Files:**
- Modify: `synapse-gitops` — terraform 및 k8s 매니페스트 (필요 시)
- Reference: `docs/guides/MSK_TOPIC_SETUP.md`
- Reference: `scripts/verify-argocd-deploy.sh`
- Reference: `scripts/verify-service-health.sh`

- [ ] **Step 1: terraform apply로 인프라 재기동**

```bash
cd synapse-gitops/infra/aws/dev
terraform init
terraform apply -auto-approve
```

Expected: `Apply complete! Resources: N added, N changed, 0 destroyed.`
EKS, RDS, MSK, Redis, OpenSearch 모두 생성 완료.

- [ ] **Step 2: EKS kubeconfig 갱신 + 노드 확인**

```bash
aws eks update-kubeconfig --name synapse-dev --region ap-northeast-2
kubectl get nodes
```

Expected: 3개 노드 `STATUS: Ready`

- [ ] **Step 3: EKS Security Group 수동 추가 확인**

> D-026 재현 방지: terraform apply 후 managed node group SG에 인프라 SG(RDS, MSK, Redis, OpenSearch) 접근이 누락될 수 있음.

```bash
# node SG 확인
aws eks describe-nodegroup --cluster-name synapse-dev --nodegroup-name <ng-name> \
  --query 'nodegroup.resources.remoteAccessSecurityGroup' --region ap-northeast-2

# SG inbound 룰 확인 — RDS(5432), MSK(9094), Redis(6379), OpenSearch(443) 포트가 허용되는지
aws ec2 describe-security-groups --group-ids <sg-id> --region ap-northeast-2 \
  --query 'SecurityGroups[0].IpPermissions[*].{FromPort:FromPort,ToPort:ToPort}'
```

Expected: 4개 인프라 포트(5432, 9094, 6379, 443) inbound 허용.
누락 시 `aws ec2 authorize-security-group-ingress`로 수동 추가.

- [ ] **Step 4: MSK 브로커 주소 확인**

```bash
aws kafka get-bootstrap-brokers --cluster-arn <cluster-arn> --region ap-northeast-2
```

Expected: `BootstrapBrokerStringTls` 값 반환.
**이전과 주소가 다르면** gitops ConfigMap 갱신 필요 (PR #42 패턴):
```bash
# apps/{service}/base/configmap.yaml의 KAFKA_BROKERS 값을 새 주소로 갱신
# 5개 서비스 모두 동일하게 변경
```

- [ ] **Step 5: Bastion SSM 접속 + MSK 토픽 생성**

```bash
aws ssm start-session --target <bastion-instance-id> --region ap-northeast-2

# bastion 내에서:
KAFKA_BROKERS="<broker-address-from-step-4>" bash scripts/create-kafka-topics.sh
```

Expected: 5개 토픽 생성 (이미 존재하면 스킵).

- [ ] **Step 6: MSK 토픽 생성 확인**

```bash
kafka-topics.sh --bootstrap-server "$KAFKA_BROKERS" --list
```

Expected:
```
learning.ai.cards-generated-v1
learning.card.review-completed-v1
knowledge.note.note-created-v1
knowledge.note.note-updated-v1
platform.auth.user-registered-v1
```

- [ ] **Step 7: TLS 통신 확인**

```bash
openssl s_client -connect <broker-host>:9094 -brief 2>&1 | head -5
```

Expected: `CONNECTION ESTABLISHED`, `Protocol: TLSv1.2` 또는 `TLSv1.3`

- [ ] **Step 8: Kafka 송수신 테스트**

```bash
echo '{"test":"ping"}' | kafka-console-producer.sh \
  --bootstrap-server "$KAFKA_BROKERS" --topic platform.auth.user-registered-v1

kafka-console-consumer.sh --bootstrap-server "$KAFKA_BROKERS" \
  --topic platform.auth.user-registered-v1 --from-beginning --max-messages 1 --timeout-ms 10000
```

Expected: `{"test":"ping"}` 메시지 수신.

- [ ] **Step 9: ArgoCD 서비스 상태 확인**

```bash
bash scripts/verify-argocd-deploy.sh synapse-dev
```

Expected: `ALL PASSED` (5개 앱 Synced + Healthy)

- [ ] **Step 10: 서비스 헬스체크**

```bash
bash scripts/verify-service-health.sh --env eks
```

Expected: `ALL HEALTHY` (5개 서비스)

- [ ] **Step 11: Security 1차 — Kafka ACL + 페이로드 점검**

Kafka ACL 현황 확인:
```bash
kafka-acls.sh --bootstrap-server "$KAFKA_BROKERS" --list
```

이벤트 페이로드 민감정보 점검 (synapse-shared에서):
```bash
# 각 Avro 스키마의 필드 목록 확인 — PII(email, password 등)가 이벤트에 포함되는지
grep -r '"name"' src/main/avro/*.avsc | grep -iE "email|password|token|secret|phone"
```

점검 결과를 기록 (다음 Task에서 TASK 문서에 반영):
- ACL 설정 여부 (IAM 인증 사용 시 불필요)
- 페이로드 내 PII 필드 목록 + 마스킹/제거 필요 여부
- 서비스 간 인증 토큰 전파 방식 (CloudEvent의 traceparent 활용)

- [ ] **Step 12: Day 1 gitops 종료 게이트 확인**

체크리스트:
```
□ Dev 5/5 Healthy
□ MSK 5개 토픽 확인
□ TLS 통신 정상
□ Security 1차 점검 완료
```

모든 항목 ✅이면 shared 세션으로 전환.

---

## Task 2: Day 1 shared — 이벤트 흐름 매트릭스 + 체크리스트 배포

> **레포**: synapse-shared
> **전제조건**: Task 1 완료 (Dev 5/5 Healthy + MSK 토픽 확인)
> **WORKFLOW**: Step 7.2

**Files:**
- Create: `docs/guides/EVENT_FLOW_MATRIX.md`
- Modify: `docs/project-management/task/TASK_team-lead.md` — Step 7 Instructions/Constraints 갱신
- Reference: `docs/guides/TEAM_CHECKLIST_W3.md`

- [ ] **Step 1: 이벤트 흐름 매트릭스 문서 작성**

`docs/guides/EVENT_FLOW_MATRIX.md` 생성:

```markdown
# Kafka 이벤트 흐름 매트릭스

> **갱신일**: 2026-05-26

## 이벤트 흐름

| # | Producer | Topic | Consumer | 이벤트 | 트리거 |
|---|----------|-------|----------|--------|--------|
| 1 | platform-svc | platform.auth.user-registered-v1 | engagement-svc, learning-card | UserRegistered | 회원가입 API 성공 |
| 2 | knowledge-svc | knowledge.note.note-created-v1 | learning-ai | NoteCreated | 노트 생성 API 성공 |
| 3 | knowledge-svc | knowledge.note.note-updated-v1 | learning-ai, opensearch | NoteUpdated | 노트 수정 API 성공 |
| 4 | learning-card | learning.card.review-completed-v1 | engagement-svc | ReviewCompleted | 카드 복습 API 성공 |
| 5 | learning-ai | learning.ai.cards-generated-v1 | learning-card, platform-svc | CardsGenerated | AI 카드 생성 완료 |

## E2E 체인 (시나리오)

### Chain A: 회원가입 → 프로필 생성
```
platform-svc → [user-registered-v1] → engagement-svc (프로필 자동 생성)
```

### Chain B: 노트 → AI 카드 → 알림
```
knowledge-svc → [note-created-v1] → learning-ai → [cards-generated-v1] → platform-svc (알림)
                                                                        → learning-card (카드 등록)
```

### Chain C: 복습 → XP 적립
```
learning-card → [review-completed-v1] → engagement-svc (XP 포인트 적립)
```

### Chain D: 노트 수정 → 재인덱싱
```
knowledge-svc → [note-updated-v1] → learning-ai (카드 갱신 판단)
                                   → opensearch (재인덱싱)
```

## Consumer Group 매핑

| 서비스 | Consumer Group | 구독 토픽 |
|--------|---------------|----------|
| engagement-svc | engagement-svc-group | user-registered-v1, review-completed-v1 |
| learning-ai | learning-ai-svc-group | note-created-v1 |
| learning-card | learning-card-group | cards-generated-v1 |
| platform-svc | platform-svc-group | cards-generated-v1 |
```

- [ ] **Step 2: 코드 리뷰 승인 기준 정의**

`docs/project-management/task/TASK_team-lead.md`의 Step 7 Instructions에 추가:

```markdown
### 코드 리뷰 승인 기준
- [ ] Avro 스키마 호환성: Schema Registry에 등록 가능 (BACKWARD)
- [ ] CloudEvent 래핑: CloudEventEnvelope.avsc 필드 전부 포함
- [ ] Consumer Group: 서비스명-group 패턴 준수
- [ ] 멱등성: eventId 기반 중복 처리 로직 존재
- [ ] 단위 테스트: Producer mock/Consumer mock 테스트 존재
- [ ] application.yml: Kafka bootstrap + Schema Registry URL 설정
```

Step 7 Constraints에 Security 1차 결과 반영 (Task 1 Step 11 결과 기반):

```markdown
### Security Constraints (W3)
- 이벤트 페이로드 PII: [점검 결과 기록]
- Kafka ACL/IAM: [현재 인증 방식 기록]
- 서비스 간 인증: CloudEvent traceparent 기반 추적
```

- [ ] **Step 3: 팀원 체크리스트 최종 확인 + 팀 전달**

```bash
# TEAM_CHECKLIST_W3.md의 현재 인프라 상태 갱신
# "MSK 토픽" 상태를 "✅ 5개 생성 완료"로 업데이트
# dev 환경 브로커 주소를 Task 1 Step 4에서 확인한 최신 값으로 갱신
```

`docs/guides/TEAM_CHECKLIST_W3.md` 갱신:

```markdown
## 현재 인프라 상태 (2026-05-26 갱신)

| 항목 | 상태 |
|------|------|
| dev 환경 | **5/5 서비스 ArgoCD Synced + Healthy** ✅ |
| staging 환경 | overlay 생성 완료, Day 2 수동 Sync 예정 |
| ArgoCD 접속 | SSM 포트 포워딩 → http://localhost:9090 |
| ECR 이미지 | 6개 서비스 push 완료 (1.0.0 + dev-latest) |
| MSK 토픽 | **✅ 5개 생성 완료** |
| MSK 브로커 | `<최신 브로커 주소>` |
```

팀원에게 전달 (카톡/디스코드):
```
W3 Kafka 구현 체크리스트 배포합니다.
- 참조: docs/guides/TEAM_CHECKLIST_W3.md
- MSK 토픽 5개 생성 완료, dev 5/5 Healthy 확인
- PR 생성 기한: 05-27 (내일)
- 질문은 바로 공유해주세요
```

- [ ] **Step 4: WORKFLOW 체크박스 갱신**

`docs/project-management/workflow/WORKFLOW_team-lead_W3.md`에서:
- Step 7.1 "TASK 시작" → 전체 체크 `[x]`
- Step 7.2 "요구사항 분석" → 매트릭스/리뷰 기준 완료 항목 체크
- Step 7.3 "Security 1차" → 완료 항목 체크

- [ ] **Step 5: 커밋**

```bash
git add docs/guides/EVENT_FLOW_MATRIX.md docs/guides/TEAM_CHECKLIST_W3.md \
  docs/project-management/task/TASK_team-lead.md \
  docs/project-management/workflow/WORKFLOW_team-lead_W3.md
git commit -m "docs: Day 1 — event flow matrix + review criteria + team checklist update"
```

- [ ] **Step 6: Day 1 종료 게이트 최종 확인**

```
□ Dev 5/5 Healthy                     ← Task 1
□ MSK 5토픽 확인                       ← Task 1
□ 이벤트 흐름 매트릭스 완성              ← Step 1
□ 코드 리뷰 승인 기준 정의              ← Step 2
□ 팀원 체크리스트 배포                   ← Step 3
□ WORKFLOW 체크박스 갱신                ← Step 4
```

---

## Task 3: Day 2 gitops — Staging 배포 + Observability 설치

> **레포**: synapse-gitops
> **전제조건**: Day 1 완료 (Dev 5/5 Healthy)
> **참조**: `docs/guides/STAGING_VERIFICATION.md`, `docs/guides/ARGOCD_DEPLOY_VERIFICATION.md`
> **WORKFLOW**: Step 8.6~8.8

**Files:**
- Modify: `synapse-gitops` — staging overlay, Helm values (필요 시)
- Reference: `docs/guides/STAGING_VERIFICATION.md`

- [ ] **Step 1: platform-svc application-staging.yml 해결**

> HANDOFF_HUB 블로커: staging 프로필 미존재

확인:
```bash
# synapse-platform-svc 레포에서 staging 프로필 존재 여부 확인
ls apps/platform-svc/overlays/staging/
# configmap에 SPRING_PROFILES_ACTIVE: staging 설정 확인
cat apps/platform-svc/overlays/staging/kustomization.yaml
```

없으면 platform-svc 앱 레포에 `src/main/resources/application-staging.yml` 추가 PR 필요.
gitops 레포의 staging ConfigMap에 `SPRING_PROFILES_ACTIVE: staging` 확인.

- [ ] **Step 2: Staging 수동 Sync 실행**

```bash
# 5개 서비스 staging sync
argocd app sync synapse-platform-svc-staging
argocd app sync synapse-engagement-svc-staging
argocd app sync synapse-knowledge-svc-staging
argocd app sync synapse-learning-card-staging
argocd app sync synapse-learning-ai-staging
```

Expected: 각 앱 `Synced` 상태.

- [ ] **Step 3: Staging 상태 확인**

```bash
bash scripts/verify-argocd-deploy.sh synapse-staging
```

Expected: `ALL PASSED` (5개 앱 Synced + Healthy)

- [ ] **Step 4: ExternalSecret staging 확인**

```bash
kubectl get externalsecrets -n synapse-staging
```

Expected: 5/5 `SecretSynced`

- [ ] **Step 5: Staging 헬스체크**

```bash
# port-forward 설정
kubectl port-forward -n synapse-staging svc/platform-svc 18081:8081 &
kubectl port-forward -n synapse-staging svc/engagement-svc 18082:8082 &
kubectl port-forward -n synapse-staging svc/knowledge-svc 18083:8083 &
kubectl port-forward -n synapse-staging svc/learning-card-svc 18084:8084 &
kubectl port-forward -n synapse-staging svc/learning-ai-svc 18085:8085 &

bash scripts/verify-service-health.sh --env eks
```

Expected: `ALL HEALTHY`

- [ ] **Step 6: STAGING_VERIFICATION.md 체크리스트 수행**

`docs/guides/STAGING_VERIFICATION.md` 섹션 1~2 전체 수행:
- 1-1: Namespace 분리 확인 (synapse-dev, synapse-staging)
- 1-2: Pod 리소스 비교 (staging replicas >= 2)
- 1-3: ConfigMap 환경변수 분리 (SPRING_PROFILES_ACTIVE: staging)
- 2-1: ArgoCD 검증 스크립트
- 2-2: 헬스체크 스크립트

- [ ] **Step 7: kube-prometheus-stack 설치**

```bash
# Helm repo 추가
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# monitoring namespace 생성
kubectl create namespace monitoring

# kube-prometheus-stack 설치 (기본 values로 시작)
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=<secure-password> \
  --set prometheus.prometheusSpec.retention=30d \
  --set alertmanager.enabled=true
```

Expected: Prometheus, Grafana, Alertmanager Pod `Running`.

- [ ] **Step 8: Observability 스택 확인**

```bash
kubectl get pods -n monitoring
```

Expected:
```
kube-prometheus-stack-grafana-xxx           Running
kube-prometheus-stack-prometheus-xxx        Running
kube-prometheus-stack-alertmanager-xxx      Running
kube-prometheus-stack-operator-xxx          Running
```

- [ ] **Step 9: Security 2차 — 테스트 환경 시크릿/네트워크**

확인 항목:
```bash
# dev/staging 시크릿이 분리되어 있는지
kubectl get secrets -n synapse-dev
kubectl get secrets -n synapse-staging
# 동일 시크릿 이름이지만 값이 다른지 확인 (같은 DB를 공유하면 안 됨 — 단, dev 환경에서는 공유 허용)

# 네트워크 격리: dev Pod에서 staging 서비스 접근 불가 확인
kubectl exec -n synapse-dev deploy/platform-svc -- curl -s --max-time 3 http://platform-svc.synapse-staging:8081/actuator/health || echo "접근 차단 확인"
```

점검 결과를 TASK_team-lead.md Step 7 Constraints에 반영.

- [ ] **Step 10: Day 2 gitops 종료 게이트 확인**

```
□ Staging 5/5 Healthy
□ ExternalSecret 5/5 SecretSynced
□ Prometheus + Grafana + Alertmanager Running
□ Security 2차 완료
```

---

## Task 4: Day 2 shared — E2E 시나리오 설계 + PR 리뷰 시작

> **레포**: synapse-shared
> **전제조건**: Task 3 완료 (Staging 5/5 Healthy)
> **WORKFLOW**: Step 7.4~7.6, 7.9 시작

**Files:**
- Create: `docs/guides/E2E_SCENARIOS_W3.md`
- Modify: `docs/project-management/HANDOFF_SHARED.md` — staging 검증 결과 반영
- Reference: `docs/guides/KAFKA_E2E_TEST.md`
- Reference: `src/test/resources/e2e-samples/*.json`

- [ ] **Step 1: E2E 시나리오 문서 작성**

`docs/guides/E2E_SCENARIOS_W3.md` 생성:

```markdown
# W3 E2E 테스트 시나리오

> **갱신일**: 2026-05-27

## 시나리오 목록

### Scenario 1: Gamification 이벤트 체인
```
카드 복습 (learning-card)
  → [review-completed-v1] → engagement-svc
  → XP 적립 → 레벨업 판정
  → (W4) gamification.level_up 발행 → 알림
```
**검증 방법**: `kafka-e2e-test.sh learning.card.review-completed-v1 review-completed.json`
→ engagement-svc DB에서 XP 증가 확인

### Scenario 2: AI 카드 자동 생성 체인
```
노트 생성 (knowledge-svc)
  → [note-created-v1] → learning-ai
  → LLM 카드 생성 → [cards-generated-v1]
  → learning-card (카드 등록) + platform-svc (알림)
```
**검증 방법**: `kafka-e2e-test.sh knowledge.note.note-created-v1 note-created.json`
→ learning-ai 로그에서 카드 생성 트리거 확인

### Scenario 3: 복습 리마인더 체인 (W3 신규)
```
스케줄러 (learning-card)
  → 복습 대상 사용자 조회
  → [card.review.due] 발행 (W4 notification 소비 게이트)
```
**검증 방법**: 스케줄러 수동 트리거 → 토픽 메시지 존재 확인

### Scenario 4: 회원가입 → 프로필 자동 생성
```
회원가입 (platform-svc)
  → [user-registered-v1] → engagement-svc
  → 프로필 레코드 생성
```
**검증 방법**: `kafka-e2e-test.sh platform.auth.user-registered-v1 user-registered.json`
→ engagement-svc DB에서 프로필 존재 확인

## 실행 순서

| 순서 | 시나리오 | 의존성 | Day |
|------|---------|--------|-----|
| 1 | Scenario 4 (회원가입) | 없음 (기본 흐름) | Day 3 |
| 2 | Scenario 1 (Gamification) | 사용자 존재 필요 | Day 3 |
| 3 | Scenario 2 (AI 카드) | 노트 존재 필요 | Day 3~4 |
| 4 | Scenario 3 (리마인더) | 카드 존재 필요 | Day 4 |

## 에러/엣지 케이스

| 케이스 | 샘플 | 기대 동작 |
|--------|------|----------|
| 필수 필드 누락 | error/missing-required-field.json | Consumer 로그 에러 + 스킵 |
| 유효하지 않은 테넌트 | error/invalid-tenant.json | Consumer 로그 에러 + 스킵 |
| 빈 데이터 | error/empty-data.json | Consumer 로그 에러 + 스킵 |
| 멀티테넌트 | multi-tenant/*.json | tenant-e2e-002 정상 처리 |
```

- [ ] **Step 2: 테스트 데이터 보강 여부 확인**

```bash
# 기존 샘플 데이터 확인
ls src/test/resources/e2e-samples/
ls src/test/resources/e2e-samples/error/
ls src/test/resources/e2e-samples/multi-tenant/
ls src/test/resources/seed/
```

Scenario 3 (card.review.due)용 샘플이 없으면 추가:
```bash
# src/test/resources/e2e-samples/card-review-due.json 생성 (필요 시)
```

기존 시드 데이터(V001~V005)가 E2E 시나리오를 커버하는지 확인.

- [ ] **Step 3: HANDOFF_SHARED 갱신 — staging 검증 결과**

`docs/project-management/HANDOFF_SHARED.md`에 staging 상태 추가:

```markdown
## 6. Staging 환경 현황 (2026-05-27 갱신)

| 항목 | 상태 |
|------|------|
| Namespace | synapse-staging Active |
| ArgoCD 5/5 | Synced + Healthy |
| ExternalSecret | 5/5 SecretSynced |
| Replicas | 2 (HA) |
| SPRING_PROFILES_ACTIVE | staging |
| 헬스체크 | ALL HEALTHY |
```

- [ ] **Step 4: 팀원 PR 코드 리뷰 1차 착수**

> 팀원 기한: 05-27 PR 생성

```bash
# 각 서비스 레포에서 열린 PR 확인
gh pr list --repo team-project-final/synapse-platform-svc
gh pr list --repo team-project-final/synapse-engagement-svc
gh pr list --repo team-project-final/synapse-knowledge-svc
gh pr list --repo team-project-final/synapse-learning-svc
```

리뷰 체크리스트 (Task 2 Step 2에서 정의한 기준):
```
□ Avro 스키마 호환성 (BACKWARD)
□ CloudEvent 래핑 필드 전부 포함
□ Consumer Group 네이밍 ({service}-group)
□ 멱등성 (eventId 중복 체크)
□ 단위 테스트 존재
□ application.yml Kafka 설정
```

PR이 아직 없는 서비스는 팀원에게 상태 확인 메시지.

- [ ] **Step 5: WORKFLOW 체크박스 갱신**

`WORKFLOW_team-lead_W3.md`에서:
- Step 7.4 "E2E 테스트 시나리오 설계" → 완료 항목 체크
- Step 7.5 "Security 2차" → 완료 항목 체크
- Step 7.6 "테스트 데이터 준비" → 완료 항목 체크
- Step 8.6~8.8 — staging 관련 항목 체크

- [ ] **Step 6: 커밋**

```bash
git add docs/guides/E2E_SCENARIOS_W3.md docs/project-management/HANDOFF_SHARED.md \
  docs/project-management/workflow/WORKFLOW_team-lead_W3.md
git commit -m "docs: Day 2 — E2E scenarios + staging verification + PR review start"
```

- [ ] **Step 7: Day 2 종료 게이트 확인**

```
□ Staging 5/5 Healthy               ← Task 3
□ Prometheus/Grafana/Alertmanager    ← Task 3
□ E2E 시나리오 4개 확정              ← Step 1
□ 팀원 PR 리뷰 착수                  ← Step 4
□ HANDOFF_SHARED 갱신               ← Step 3
```

---

## Task 5: Day 3 gitops — Observability 마무리 + terraform state + 롤백

> **레포**: synapse-gitops
> **전제조건**: Task 3 완료 (kube-prometheus-stack Running)
> **WORKFLOW**: Step 8.9, HANDOFF_HUB #6

**Files:**
- Create: `synapse-gitops/k8s/monitoring/` — ServiceMonitor 매니페스트 5개
- Modify: `synapse-gitops` — terraform state 정리

- [ ] **Step 1: ServiceMonitor 5개 생성**

각 서비스의 ServiceMonitor 매니페스트 생성. 예시 (`k8s/monitoring/servicemonitor-platform-svc.yaml`):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: platform-svc
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
      - synapse-dev
      - synapse-staging
  selector:
    matchLabels:
      app.kubernetes.io/component: platform-svc
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 30s
```

5개 서비스 모두 동일 패턴으로 생성 (`platform-svc`, `engagement-svc`, `knowledge-svc`, `learning-card`, `learning-ai`).

```bash
kubectl apply -f k8s/monitoring/
```

- [ ] **Step 2: Prometheus Targets 확인**

```bash
# Prometheus UI port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# 브라우저: http://localhost:9090/targets
# 또는 CLI:
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | startswith("synapse")) | {job: .labels.job, health: .health}'
```

Expected: 5개 서비스 target `health: "up"`

- [ ] **Step 3: Grafana 대시보드 구성**

```bash
# Grafana port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# 브라우저: http://localhost:3000 (admin / <설정한 password>)
```

대시보드 구성:
1. **서비스 Overview**: CPU/메모리/응답시간/에러율 (5개 서비스)
2. **Kafka 메트릭**: consumer lag, throughput (Spring Kafka 메트릭 기반)
3. **JVM 메트릭**: heap usage, GC pause, thread count

Grafana → Dashboards → Import → JSON 파일 또는 수동 패널 구성.

대시보드 JSON export → `k8s/monitoring/dashboards/` 에 저장.

- [ ] **Step 4: terraform state 정리 (SG/OIDC 코드 반영)**

```bash
cd synapse-gitops/infra/aws/dev

# 현재 drift 확인
terraform plan
```

Expected: SG 수동 추가분과 OIDC 설정이 drift로 표시.

```bash
# drift를 코드로 반영 (SG rule을 terraform 리소스로 추가)
# OIDC provider 설정을 terraform 코드에 반영
# 변경 후:
terraform plan
```

Expected: `No changes. Your infrastructure matches the configuration.` (또는 의도된 변경만)

- [ ] **Step 5: 롤백 시나리오 1회 테스트**

```bash
# dev 환경에서 platform-svc 롤백 테스트
argocd app history synapse-platform-svc-dev

# 이전 리비전으로 롤백
argocd app rollback synapse-platform-svc-dev <PREVIOUS_REVISION>

# 상태 확인
bash scripts/verify-argocd-deploy.sh synapse-dev
# Expected: platform-svc가 이전 이미지로 Healthy

# 원복 (최신 리비전으로 sync)
argocd app sync synapse-platform-svc-dev
bash scripts/verify-argocd-deploy.sh synapse-dev
# Expected: ALL PASSED
```

- [ ] **Step 6: Day 3 gitops 종료 게이트 확인**

```
□ Prometheus Targets 5개 up
□ Grafana 대시보드에서 5개 앱 메트릭 조회
□ terraform plan → no unexpected drift
□ 롤백 테스트 성공 + 원복 완료
```

---

## Task 6: Day 3 shared — 로컬 E2E + 코드 리뷰 + 머지

> **레포**: synapse-shared + 서비스 레포 (리뷰)
> **전제조건**: 팀원 PR 존재 (05-27 기한)
> **WORKFLOW**: Step 7.7~7.9

**Files:**
- Reference: `scripts/kafka-e2e-test.sh`
- Reference: `docs/guides/KAFKA_E2E_TEST.md`
- Reference: `docs/guides/E2E_SCENARIOS_W3.md`

- [ ] **Step 1: 로컬 Docker Compose 기동**

```bash
docker compose up -d
docker compose ps
```

Expected: 13개 서비스 healthy.

- [ ] **Step 2: 로컬 E2E 검증 — 정상 흐름**

```bash
bash scripts/kafka-e2e-test.sh --all
```

Expected: 5개 토픽 produce/consume PASS.

> 서비스 Kafka 구현이 아직 미완료인 경우, 수동 produce → topic 메시지 존재 확인 수준으로 검증.
> 구현 완료된 서비스는 API 호출 → 이벤트 발행 → Consumer 처리까지 E2E 확인.

- [ ] **Step 3: 서비스별 E2E 확인 (구현 완료분)**

`docs/guides/KAFKA_E2E_TEST.md`의 시나리오별 서비스 구현 후 E2E 테스트:

```bash
# Scenario 4: 회원가입 → 프로필 생성 (platform-svc + engagement-svc 구현 완료 시)
curl -X POST http://localhost:8081/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"e2e-day3@test.com","password":"Test1234!"}'
sleep 3
docker exec synapse-postgres psql -U synapse -c \
  "SELECT * FROM engagement.user_profiles WHERE email='e2e-day3@test.com'"

# Scenario 1: 복습 → XP (learning-card + engagement-svc 구현 완료 시)
# learning-card API로 복습 완료 → engagement-svc DB에서 XP 확인
```

결과 기록: 어떤 서비스가 PASS/FAIL/미구현인지 정리.

- [ ] **Step 4: 코드 리뷰 피드백 반영 확인**

```bash
# 각 서비스 PR에서 리뷰 코멘트 상태 확인
gh pr view <PR_NUMBER> --repo team-project-final/synapse-platform-svc --comments
gh pr view <PR_NUMBER> --repo team-project-final/synapse-engagement-svc --comments
# ... (각 서비스)
```

크로스 서비스 리뷰 포인트:
- 스키마 호환성: Producer가 발행하는 스키마 버전 ↔ Consumer가 기대하는 스키마 버전
- Consumer Group 충돌 없는지 확인
- CloudEvent envelope 필드 일관성

- [ ] **Step 5: PR 승인 + main 머지 조율**

리뷰 완료 + 테스트 통과한 서비스부터 순차 머지:

```bash
# 리뷰 approve
gh pr review <PR_NUMBER> --repo team-project-final/<repo> --approve

# 머지 (squash)
gh pr merge <PR_NUMBER> --repo team-project-final/<repo> --squash
```

머지 순서 권장: platform-svc → knowledge-svc → learning-card → learning-ai → engagement-svc
(Producer 먼저 → Consumer 나중)

- [ ] **Step 6: WORKFLOW 체크박스 갱신**

`WORKFLOW_team-lead_W3.md`에서:
- Step 7.7 "E2E 테스트 구현 및 조율" → 완료 항목 체크
- Step 7.8 "통합 테스트 실행 및 검증" → 로컬 E2E 결과 체크
- Step 7.9 "코드 리뷰 조율" → 리뷰/머지 현황 체크
- Step 8.9 "배포 이슈 대응" → 롤백 테스트 체크

- [ ] **Step 7: 커밋**

```bash
git add docs/project-management/workflow/WORKFLOW_team-lead_W3.md
git commit -m "docs: Day 3 — local E2E results + code review progress"
```

---

## Task 7: Day 4 gitops — Grafana 알림 + 배포 리포트

> **레포**: synapse-gitops
> **전제조건**: Task 5 완료 (Grafana 대시보드 가동)
> **WORKFLOW**: Step 8.10, TASK Step 11 선행

**Files:**
- Modify: `synapse-gitops/k8s/monitoring/` — alert rules (필요 시)
- Create: `synapse-shared/docs/reports/DEPLOY_REPORT_W3.md`

- [ ] **Step 1: Grafana 알림 규칙 설정**

Grafana UI → Alerting → Alert Rules:

| 규칙 | 조건 | 채널 |
|------|------|------|
| 에러율 > 1% | `rate(http_server_requests_seconds_count{status=~"5.."}[5m]) / rate(http_server_requests_seconds_count[5m]) > 0.01` | Slack/Email |
| P95 > 500ms | `histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m])) > 0.5` | Slack/Email |
| Kafka consumer lag > 1000 | `kafka_consumer_lag > 1000` | Slack/Email |

- [ ] **Step 2: 알림 테스트 발동**

테스트 알림 1회 발동 확인:
```bash
# Grafana UI → Alerting → Test Rule → Fire
# 또는 메트릭 임계값 임시 낮춰서 자연 발동 확인
```

Expected: 알림 채널(Slack/Email)에 알림 도착.

- [ ] **Step 3: 배포 검증 리포트 작성**

`docs/reports/DEPLOY_REPORT_W3.md` 생성:

```markdown
# W3 배포 검증 리포트

> **작성일**: 2026-05-29
> **WORKFLOW**: Step 8.10

## Dev 환경

| 항목 | 결과 |
|------|------|
| ArgoCD 5/5 Synced + Healthy | ✅ / ❌ |
| 헬스체크 ALL HEALTHY | ✅ / ❌ |
| Kafka 연결 | ✅ / ❌ |
| RDS/Redis/OpenSearch 연결 | ✅ / ❌ |

## Staging 환경

| 항목 | 결과 |
|------|------|
| ArgoCD 5/5 Synced + Healthy | ✅ / ❌ |
| ExternalSecret 5/5 SecretSynced | ✅ / ❌ |
| 헬스체크 ALL HEALTHY | ✅ / ❌ |
| Namespace 분리 확인 | ✅ / ❌ |
| SPRING_PROFILES_ACTIVE=staging | ✅ / ❌ |

## Observability

| 항목 | 결과 |
|------|------|
| Prometheus Running | ✅ / ❌ |
| Grafana Running | ✅ / ❌ |
| Alertmanager Running | ✅ / ❌ |
| ServiceMonitor 5개 등록 | ✅ / ❌ |
| Grafana 대시보드 조회 | ✅ / ❌ |
| 알림 규칙 3개 설정 | ✅ / ❌ |

## 롤백 테스트

| 항목 | 결과 |
|------|------|
| 이전 리비전 롤백 | ✅ / ❌ |
| 롤백 후 Healthy | ✅ / ❌ |
| 원복 후 Healthy | ✅ / ❌ |

## terraform state

| 항목 | 결과 |
|------|------|
| terraform plan → no unexpected drift | ✅ / ❌ |

## 미해결 항목

| 항목 | 우선순위 | 이월 대상 |
|------|----------|----------|
| (있으면 기록) | | W4 |
```

실제 결과를 ✅/❌로 채우기.

- [ ] **Step 4: 커밋**

```bash
mkdir -p docs/reports
git add docs/reports/DEPLOY_REPORT_W3.md
git commit -m "docs: Day 4 — W3 deploy verification report"
```

---

## Task 8: Day 4 shared — 전체 E2E + 결과 리포트 + W4 핸드오프

> **레포**: synapse-shared
> **전제조건**: Task 6 완료 (로컬 E2E PASS), 팀원 PR 머지 완료 (가능한 범위)
> **WORKFLOW**: Step 7.7~7.10, SESSION_CLOSE_CHECKLIST

**Files:**
- Create: `docs/reports/E2E_REPORT_W3.md`
- Modify: `docs/project-management/HANDOFF_HUB.md`
- Modify: `docs/project-management/HANDOFF_SHARED.md`
- Modify: `docs/project-management/workflow/WORKFLOW_team-lead_W3.md`

- [ ] **Step 1: 전체 E2E 실행 — 로컬**

```bash
docker compose up -d
docker compose ps  # 13개 healthy 확인

# 전체 모드 (정상 + 에러 + 멀티테넌트)
bash scripts/kafka-e2e-test.sh --full
```

Expected: 전 시나리오 PASS. 실패 시 원인 기록.

- [ ] **Step 2: dev 환경 EKS E2E 검증**

EKS 환경에서 이벤트 흐름 확인:

```bash
# port-forward로 서비스 접근
kubectl port-forward -n synapse-dev svc/platform-svc 8081:8081 &

# Scenario 4: 회원가입 → 프로필 생성
curl -X POST http://localhost:8081/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"eks-e2e@test.com","password":"Test1234!"}'
sleep 5

# engagement-svc 로그에서 이벤트 수신 확인
kubectl logs -n synapse-dev deploy/engagement-svc --tail=20 | grep "user-registered"
```

각 시나리오별로 EKS에서 검증. 로컬과 결과 비교.

- [ ] **Step 3: E2E 결과 리포트 작성**

`docs/reports/E2E_REPORT_W3.md` 생성:

```markdown
# W3 E2E 테스트 결과 리포트

> **작성일**: 2026-05-29
> **WORKFLOW**: Step 7.10

## 로컬 E2E (Docker Compose)

### 정상 흐름

| 시나리오 | Producer | Consumer | 결과 | 비고 |
|---------|----------|----------|:----:|------|
| 회원가입→프로필 | platform-svc | engagement-svc | ✅/❌/미구현 | |
| 복습→XP | learning-card | engagement-svc | ✅/❌/미구현 | |
| 노트→AI카드 | knowledge-svc | learning-ai | ✅/❌/미구현 | |
| AI카드→알림 | learning-ai | platform-svc | ✅/❌/미구현 | |
| 노트수정→재인덱싱 | knowledge-svc | learning-ai | ✅/❌/미구현 | |

### 에러 케이스

| 케이스 | 결과 | 비고 |
|--------|:----:|------|
| 필수 필드 누락 | ✅/❌ | |
| 유효하지 않은 테넌트 | ✅/❌ | |
| 빈 데이터 | ✅/❌ | |

### 멀티테넌트

| 테넌트 | 결과 | 비고 |
|--------|:----:|------|
| tenant-e2e-002 | ✅/❌ | |

## EKS E2E (dev 환경)

| 시나리오 | 결과 | 로컬 대비 | 비고 |
|---------|:----:|:---------:|------|
| 회원가입→프로필 | ✅/❌ | 동일/차이 | |
| 복습→XP | ✅/❌ | 동일/차이 | |
| 노트→AI카드 | ✅/❌ | 동일/차이 | |
| AI카드→알림 | ✅/❌ | 동일/차이 | |

## 미해결 이슈

| # | 이슈 | 서비스 | 우선순위 | 담당 | 이월 |
|---|------|--------|----------|------|------|
| 1 | (있으면 기록) | | P0/P1/P2 | | W4 |

## 서비스별 Kafka 구현 최종 상태

| 서비스 | 역할 | 구현 | PR 머지 | E2E |
|--------|------|:----:|:-------:|:---:|
| platform-svc | Producer+Consumer | ✅/❌ | ✅/❌ | ✅/❌ |
| engagement-svc | Consumer | ✅/❌ | ✅/❌ | ✅/❌ |
| knowledge-svc | Producer | ✅/❌ | ✅/❌ | ✅/❌ |
| learning-card | Producer | ✅/❌ | ✅/❌ | ✅/❌ |
| learning-ai | Producer+Consumer | ✅/❌ | ✅/❌ | ✅/❌ |
```

실제 결과를 채우기.

- [ ] **Step 4: HANDOFF_HUB 갱신 (W3→W4 전환)**

`docs/project-management/HANDOFF_HUB.md` 갱신:

```markdown
> **최종 갱신**: 2026-05-29 (W3 → W4 전환)
> **현재 주차**: W4
```

갱신 항목 (SESSION_CLOSE_CHECKLIST 기반):
- 헤더: 최종 갱신 날짜 + 갱신자
- 서비스 상태 테이블: staging 상태 갱신 (Healthy / Degraded)
- 인프라 상태: Observability 스택 추가
- Kafka/스키마 상태: Producer/Consumer 구현 현황 갱신
- 교차 의존관계 맵: 해소된 블로커 제거, W4 블로커 추가
- 스포크 참조: 최종 갱신일 업데이트
- 다음 세션 작업 순서: W4 작업으로 교체
- 마일스톤: W3 상태 → ✅ 완료 (또는 부분 완료 + 이월 항목)

- [ ] **Step 5: HANDOFF_SHARED 갱신**

`docs/project-management/HANDOFF_SHARED.md` 갱신:
- Kafka 토픽/MSK 상태: Producer/Consumer 구현 현황 갱신 (🔴→✅ 또는 잔여 🔴)
- CI/CD 상태: 변경 없으면 유지
- 팀원 체크리스트: 완료/미완료 상태 갱신
- Staging 환경: 검증 결과 반영

- [ ] **Step 6: WORKFLOW Step 7+8 Status → Done**

`docs/project-management/workflow/WORKFLOW_team-lead_W3.md`:
- Step 7.10 "결과 정리" → 전체 체크
- Step 8.10 "결과 정리" → 전체 체크
- **Step 7 Status**: `[x] Done`
- **Step 8 Status**: `[x] Done`

> 일부 항목이 미완료이면 Status를 Done으로 바꾸지 말고, 미완료 사유 + W4 이월 항목을 Step 하단에 기록.

- [ ] **Step 7: 정합성 점검 (SESSION_CLOSE_CHECKLIST Step 3)**

3개 질문:
```
□ 허브 서비스 상태가 실제(ArgoCD/kubectl)와 같은가?
□ 허브의 "스포크 최종 갱신일"이 오늘(05-29) 날짜인가?
□ 허브의 "다음 세션 작업"에 오늘 완료한 항목이 남아있지 않은가?
```

하나라도 ❌이면 해당 항목 수정.

- [ ] **Step 8: 커밋 + 푸시**

```bash
git add docs/reports/E2E_REPORT_W3.md \
  docs/project-management/HANDOFF_HUB.md \
  docs/project-management/HANDOFF_SHARED.md \
  docs/project-management/workflow/WORKFLOW_team-lead_W3.md
git commit -m "docs: W3 close — E2E report + handoff hub/spoke sync for W4"
git push origin main
```

- [ ] **Step 9: W3 종료 게이트 최종 확인**

```
□ Dev 5/5 Healthy (유지)
□ Staging 5/5 Healthy (신규 달성)
□ Prometheus + Grafana + Alertmanager Running
□ Grafana에서 5개 앱 메트릭 조회 가능
□ terraform plan → no unexpected drift
□ 전체 E2E (--full) PASS
□ 팀원 PR 머지 완료 (또는 잔여분 W4 이월 명시)
□ HANDOFF_HUB/SHARED 정합성 ✅
□ WORKFLOW Step 7+8 Status → Done
```

- [ ] **Step 10: 비용 정리 (세션 종료 시)**

```bash
cd synapse-gitops/infra/aws/dev
terraform destroy -auto-approve
# S3 state bucket + DynamoDB lock table은 유지 (destroy 대상 아님)
```
