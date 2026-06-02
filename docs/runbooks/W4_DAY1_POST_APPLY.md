# W4 Day 1 — `terraform apply` 후 실행 체크리스트

> **작성**: 2026-06-01 (W4 Day 1) · **owner**: @team-lead (일부 gitops 협업)
> **전제**: 배포 검증 window에 `terraform apply`로 **EKS 재기동한 직후** 실행 (EKS는 on-demand — 06-01 apply 후 비용관리 재 destroy 상태). §4 계약 BACKWARD 실검증은 **로컬 `--avro`로 EKS 없이도 가능**.
> **근거**: [MSK_TOPIC_SETUP](../guides/MSK_TOPIC_SETUP.md) · [DEPLOY_REPORT_W3](../reports/DEPLOY_REPORT_W3.md) §A~C · [W3_EXIT_GATE](../reports/W3_EXIT_GATE.md) · [W4_PLAN](../project-management/W4_PLAN.md) Track A
> **목표(한 줄)**: EKS 접속 복구 → MSK 9토픽 재생성 → dev 5/5 재확인 → Schema Registry BACKWARD **실검증** → Step 8 staging/롤백 → W3 게이트 §1 재평가

---

## 06-01 재apply 라이브 실측 (AWS API — 클러스터 네트워크 불필요, team-lead 확인 완료)

| 대상 | 상태 |
|------|------|
| EKS `synapse-dev` | ✅ **ACTIVE** (v1.30), 노드그룹 `synapse-dev-nodes` ACTIVE desired=4, health 정상 |
| MSK `synapse-dev-kafka` | ✅ **ACTIVE** (PROVISIONED) |
| EKS API 엔드포인트 | ⚠️ **`endpointPublicAccess=false` (프라이빗 전용)** → kubectl/argocd/MSK 작업은 **VPC 내부(bastion SSM)에서만**. 외부 머신 kubeconfig는 타임아웃(설계상 정상) |
| MSK 브로커 주소 | ⚠️ **변경됨** `…fark5c…` → `…v2grm6…` → **gitops ConfigMap `KAFKA_BROKERS` 갱신 필요**. TLS: `b-1/b-2.synapsedevkafka.v2grm6.c2.kafka.ap-northeast-2.amazonaws.com:9094` |
| MSK 인증 | ⚠️ **SASL/IAM 미활성** (`BootstrapBrokerStringSaslIam=null`) → [KAFKA_AUTH_MATRIX](../guides/KAFKA_AUTH_MATRIX.md)의 IAM 모델과 불일치. **결정 필요**: (A) MSK에 IAM 활성화(terraform) / (B) TLS-only로 인증 모델 수정 |
| bastion 역할 권한 | ⚠️ `synapse-dev-bastion-role`에 **`kafka:ListClustersV2`/`GetBootstrapBrokers` 없음** → bastion 자체 브로커 fetch 불가(AccessDenied). 임시: team-lead가 fetch해 BROKER 직접 전달 / durable: terraform로 역할에 kafka read 추가 |

### ⛔ bastion 검증 선결 (gitops/infra) — 06-01 실측, **이게 없으면 §1~§6 실행 불가**

bastion(`synapse-dev-bastion`)에서 직접 시도한 결과 **모든 경로가 막힘**:

| 경로 | 막힌 이유 | gitops/infra 선결 |
|------|----------|------------------|
| **kubectl** (Step 3·파드 토픽) | 클러스터 authMode=**CONFIG_MAP**, bastion 역할이 **aws-auth 미매핑** → 401 Unauthorized | `aws-auth` ConfigMap `mapRoles`에 bastion 역할 추가 (또는 authMode를 API_AND_CONFIG_MAP로 전환 후 access-entry) |
| **kafka CLI** | bastion에 Java·Kafka **미설치** | Java+Kafka 설치(NAT 필요) 또는 aws-auth 매핑 후 **EKS kafka 파드** |
| **브로커 fetch** | 역할에 `kafka:ListClustersV2`/`GetBootstrapBrokers` 없음 | (우회됨: team-lead가 BROKER 직접 전달) |

**aws-auth 매핑 예시** (gitops/terraform — cluster-creator 권한 필요):
```yaml
# kube-system/aws-auth ConfigMap data.mapRoles 에 추가
- rolearn: arn:aws:iam::963773969059:role/synapse-dev-bastion-role
  username: bastion
  groups: [system:masters]    # 또는 read 전용 그룹
```

> **다른 선결 2건**: ① 신규 브로커 주소 ConfigMap 반영 ② MSK IAM 활성화 여부 결정([KAFKA_AUTH_MATRIX](../guides/KAFKA_AUTH_MATRIX.md)).
> 인프라는 ACTIVE이나 **bastion 접근이 gitops에 막혀** §1~§6 미실행. → **gitops 선결 후** 또는 서비스 배포 준비 시점에 재개. 한편 **MSK 토픽은 terraform 선언 관리**로 전환하면 이 수동 단계 자체가 제거됨(권장).

---

## 임계 경로

```
terraform apply(완료) → [1] kubeconfig+SG(D-026) → [2] MSK 9토픽 재생성 → [3] dev 5/5 verify
                                                                            ├─→ [4] Schema Registry BACKWARD 실검증 → 게이트 §1 해소
                                                                            └─→ [5] Step 8 staging Sync + 롤백 → [6] 게이트 §1 재평가
```
> ⚠️ Track B(서비스 Kafka consumer/producer)는 **별개** — 게이트 §2~§5는 그쪽 완성 의존(Day2~). 본 체크리스트는 **인프라/배포/계약 실검증**만 다룬다.

---

## 소유 구분 — AWS 접근이 필요하다고 전부 gitops가 아니다

기준 = "IaC를 커밋하나(A)" vs "클러스터 대상으로 실행하나(B)". 둘 다 AWS 접근은 필요하다.

| | **A. gitops 레포 (IaC 커밋 = 인프라)** | **B. team-lead 운영 (스크립트=shared)** |
|---|---|---|
| 정의 | terraform/매니페스트 등 **선언적 코드** | 클러스터/MSK 대상 **실행·검증** |
| 항목 | `terraform apply`(✅완료) · SG/OIDC 코드화(D-026 영구) · MSK 브로커 ConfigMap 갱신 · `platform application-staging.yml` · ArgoCD App 매니페스트 · Observability 스택 | `update-kubeconfig` · MSK 토픽 재생성(`create-kafka-topics.sh`) · `verify-argocd-deploy.sh` · Schema Registry `--avro` 실검증 · staging `argocd app sync`+승인 · 롤백 테스트 |
| 본 체크리스트 단계 | [2]ConfigMap · [5]staging 프로필 | [1]kubeconfig · [2]토픽 · [3]verify · [4]registry · [5]sync/롤백 |

> ⚠️ **경계 1건 — SG 수동 추가(D-026)**: 당장은 AWS 콘솔/CLI 수동(접근권 가진 쪽이 실행, 과거 gitops 세션 05-21에서 처리). **영구 해결(terraform 코드화)은 A=gitops**.
> 아래 각 단계의 `(A)`/`(B)` 태그가 이 구분을 가리킨다.

---

## 0. 선행 확인 `(B)`
- [ ] `aws sts get-caller-identity` — 인증 OK
- [ ] gitops `terraform output` — cluster ARN / MSK bootstrap endpoint 확보 (apply 후 **브로커 주소 변경 가능**)

## 1. EKS 접속 복구 (D-026) `(B)` — SG 수동은 경계, 영구 코드화는 `(A)`
- [ ] `aws eks update-kubeconfig --name synapse-dev --region ap-northeast-2`
- [ ] **SG 수동 추가(D-026)** — `eks-cluster-sg-*` ↔ RDS/Redis/OpenSearch/MSK inbound(9094 등). 근거: gitops HISTORY 05-21(8차) "managed node group SG ≠ terraform eks_nodes SG → 4개 인프라 SG에 수동 추가"
- [ ] `kubectl get nodes` / `kubectl get pods -n synapse-dev` — 노드 Ready, 파드 기동

## 2. MSK 토픽 재생성 (9토픽) `(B)` — ConfigMap 갱신만 `(A)`
- [ ] 브로커 주소 확인: `aws kafka get-bootstrap-brokers --cluster-arn <arn> --region ap-northeast-2`
- [ ] **변경 시** gitops ConfigMap broker 주소 갱신 (PR #42 경로)
- [ ] bastion SSM 접속: `aws ssm start-session --target <bastion-id> --region ap-northeast-2`
- [ ] 토픽 생성: `KAFKA_BROKERS="<broker>" bash scripts/create-kafka-topics.sh` → **9토픽(8 active + cards-generated 잔존)**, created/skipped 로그
- [ ] 검증: `kafka-topics.sh --bootstrap-server "$KAFKA_BROKERS" --describe --topic platform.auth.user-registered-v1` (partitions 3 / rf 3 / min.isr 2)
> 상세·TLS·트러블슈팅: [MSK_TOPIC_SETUP](../guides/MSK_TOPIC_SETUP.md) "다음 세션 실행 절차".

## 3. dev 배포 검증 (Step 8 / 1.7~1.8) `(B)`
- [ ] `bash scripts/verify-argocd-deploy.sh synapse-dev` → **5/5 PASS** (App Sync=Synced·Health=Healthy / Pod Running·restarts≤3 / ExternalSecret SecretSynced)
- [ ] FAIL 시: liveness initialDelay 90s, ESO IRSA(`synapse-dev-eso-role`) 확인 (gitops HISTORY 05-21)
- → 충족 시 HANDOFF_HUB 서비스 상태 dev `🔄 검증 대기` → `✅ Healthy` 갱신

## 4. Schema Registry BACKWARD 실등록 검증 ★ W3 게이트 §1 해소 `(B)` — ✅ 완료(06-02, 로컬·EKS 불필요)
> W3 게이트 §1은 "레지스트리 실등록 BACKWARD 미검증"으로 🟡**조건부**였다. **06-02 로컬 docker-compose SR로 실검증 완료 → ✅** (EKS apply 불필요 확정).
- [x] 로컬 Schema Registry (`synapse-schema-registry`, 내부 `http://schema-registry:8081`)
- [x] `bash scripts/kafka-e2e-test.sh --avro` → **8/8 PASSED** + subject `<topic>-value` 8종 자동 등록
- [x] compatibility 확인: 전역 `{"compatibilityLevel":"BACKWARD"}` + subject 동일
- [x] **라이브 강제 프로브**: default 포함 필드 추가 `is_compatible=true` / default 없는 필수 필드 추가 `is_compatible=false` → BACKWARD 실제 강제 확인
- → 게이트 §1 🟡조건부 → ✅ 갱신 완료 ([W3_EXIT_GATE](../reports/W3_EXIT_GATE.md) §1)

## 5. Step 8 staging 배포 + 롤백 (1.7~1.9) `(B)` — platform staging 프로필 선결만 `(A)`
- [ ] **선결**: `platform-svc` `application-staging.yml` 추가 확인 (HANDOFF_HUB §2 블로커)
- [ ] staging 수동 Sync: `argocd app sync synapse-<svc>-staging` (manual, 승인자 @team-lead)
- [ ] `bash scripts/verify-argocd-deploy.sh synapse-staging` → 5/5
- [ ] **롤백 1회 테스트** — [DEPLOY_REPORT_W3](../reports/DEPLOY_REPORT_W3.md) §B 5단계, 목표 **<3분**
- [ ] DEPLOY_REPORT 실행 검증 체크리스트(1.7~1.9) 채움

## 6. W3 종료 게이트 §1 재평가 `(B)` — ✅ 완료(06-02)
- [x] [W3_EXIT_GATE](../reports/W3_EXIT_GATE.md) §1(레지스트리 BACKWARD): 🟡조건부 → ✅
- [x] 점수 갱신 — `충족 0/5` → `충족 1/5`(§1만). **§2~§5는 서비스 Kafka(Track B) 의존** → Day2 이후
- [x] HANDOFF_HUB 게이트 점수 1/5 반영. (인프라/서비스 dev 상태 ✅는 EKS 재기동 window에서)

---

## 성공 기준 (Day 1 인프라 트랙)
| 항목 | 기준 |
|------|------|
| EKS 접속 | `kubectl get nodes` Ready, dev 파드 기동 |
| MSK 토픽 | 9토픽 생성/스킵 확인 |
| dev 검증 | `verify-argocd-deploy.sh synapse-dev` 5/5 |
| Schema Registry | `--avro` 8/8 + BACKWARD 실등록 |
| staging | 수동 Sync 5/5 + 롤백 <3분 |
| 게이트 §1 | 조건부 → 충족 |

## 차단/주의
- **D-026**: SG 수동 추가 누락 시 RDS/Redis/OpenSearch/MSK 연결 실패 (가장 흔한 차단)
- **브로커 주소 변경**: apply 후 endpoint 바뀌면 ConfigMap 갱신 전까지 서비스 Kafka 연결 불가
- **platform staging 프로필**: 미해결 시 staging 5/5 미달
- **stale ZK znode(D-1)**: 로컬 재검증 시 `docker compose down -v` 후 기동 권장
