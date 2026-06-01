# W4 Day 1 — `terraform apply` 후 실행 체크리스트

> **작성**: 2026-06-01 (W4 Day 1) · **owner**: @team-lead (일부 gitops 협업)
> **전제**: gitops `terraform apply` **완료**(EKS 재기동) → 아래가 잠금 해제됨
> **근거**: [MSK_TOPIC_SETUP](../guides/MSK_TOPIC_SETUP.md) · [DEPLOY_REPORT_W3](../reports/DEPLOY_REPORT_W3.md) §A~C · [W3_EXIT_GATE](../reports/W3_EXIT_GATE.md) · [W4_PLAN](../project-management/W4_PLAN.md) Track A
> **목표(한 줄)**: EKS 접속 복구 → MSK 9토픽 재생성 → dev 5/5 재확인 → Schema Registry BACKWARD **실검증** → Step 8 staging/롤백 → W3 게이트 §1 재평가

---

## 임계 경로

```
terraform apply(완료) → [1] kubeconfig+SG(D-026) → [2] MSK 9토픽 재생성 → [3] dev 5/5 verify
                                                                            ├─→ [4] Schema Registry BACKWARD 실검증 → 게이트 §1 해소
                                                                            └─→ [5] Step 8 staging Sync + 롤백 → [6] 게이트 §1 재평가
```
> ⚠️ Track B(서비스 Kafka consumer/producer)는 **별개** — 게이트 §2~§5는 그쪽 완성 의존(Day2~). 본 체크리스트는 **인프라/배포/계약 실검증**만 다룬다.

---

## 0. 선행 확인
- [ ] `aws sts get-caller-identity` — 인증 OK
- [ ] gitops `terraform output` — cluster ARN / MSK bootstrap endpoint 확보 (apply 후 **브로커 주소 변경 가능**)

## 1. EKS 접속 복구 (D-026)
- [ ] `aws eks update-kubeconfig --name synapse-dev --region ap-northeast-2`
- [ ] **SG 수동 추가(D-026)** — `eks-cluster-sg-*` ↔ RDS/Redis/OpenSearch/MSK inbound(9094 등). 근거: gitops HISTORY 05-21(8차) "managed node group SG ≠ terraform eks_nodes SG → 4개 인프라 SG에 수동 추가"
- [ ] `kubectl get nodes` / `kubectl get pods -n synapse-dev` — 노드 Ready, 파드 기동

## 2. MSK 토픽 재생성 (9토픽)
- [ ] 브로커 주소 확인: `aws kafka get-bootstrap-brokers --cluster-arn <arn> --region ap-northeast-2`
- [ ] **변경 시** gitops ConfigMap broker 주소 갱신 (PR #42 경로)
- [ ] bastion SSM 접속: `aws ssm start-session --target <bastion-id> --region ap-northeast-2`
- [ ] 토픽 생성: `KAFKA_BROKERS="<broker>" bash scripts/create-kafka-topics.sh` → **9토픽(8 active + cards-generated 잔존)**, created/skipped 로그
- [ ] 검증: `kafka-topics.sh --bootstrap-server "$KAFKA_BROKERS" --describe --topic platform.auth.user-registered-v1` (partitions 3 / rf 3 / min.isr 2)
> 상세·TLS·트러블슈팅: [MSK_TOPIC_SETUP](../guides/MSK_TOPIC_SETUP.md) "다음 세션 실행 절차".

## 3. dev 배포 검증 (Step 8 / 1.7~1.8)
- [ ] `bash scripts/verify-argocd-deploy.sh synapse-dev` → **5/5 PASS** (App Sync=Synced·Health=Healthy / Pod Running·restarts≤3 / ExternalSecret SecretSynced)
- [ ] FAIL 시: liveness initialDelay 90s, ESO IRSA(`synapse-dev-eso-role`) 확인 (gitops HISTORY 05-21)
- → 충족 시 HANDOFF_HUB 서비스 상태 dev `🔄 검증 대기` → `✅ Healthy` 갱신

## 4. Schema Registry BACKWARD 실등록 검증 ★ W3 게이트 §1 해소
> W3 게이트 §1은 "레지스트리 실등록 BACKWARD 미검증"으로 🟡**조건부**였다(URL 미설정/EKS destroy). apply로 **이제 실검증 가능**.
- [ ] dev Schema Registry URL 확인 (compose 내부 `http://schema-registry:8081` / 외부 매핑 `:8086`)
- [ ] `bash scripts/kafka-e2e-test.sh --avro` (로컬 스택 또는 dev 대상) → **8/8** + subject `<topic>-value` 자동 등록
- [ ] compatibility 확인: 전역/subject `BACKWARD` (`GET /config`, `GET /subjects`)
- → 통과 시 게이트 §1 🟡조건부 → ✅ 갱신 근거 확보

## 5. Step 8 staging 배포 + 롤백 (1.7~1.9)
- [ ] **선결**: `platform-svc` `application-staging.yml` 추가 확인 (HANDOFF_HUB §2 블로커)
- [ ] staging 수동 Sync: `argocd app sync synapse-<svc>-staging` (manual, 승인자 @team-lead)
- [ ] `bash scripts/verify-argocd-deploy.sh synapse-staging` → 5/5
- [ ] **롤백 1회 테스트** — [DEPLOY_REPORT_W3](../reports/DEPLOY_REPORT_W3.md) §B 5단계, 목표 **<3분**
- [ ] DEPLOY_REPORT 실행 검증 체크리스트(1.7~1.9) 채움

## 6. W3 종료 게이트 §1 재평가
- [ ] [W3_EXIT_GATE](../reports/W3_EXIT_GATE.md) §1(레지스트리 BACKWARD): 🟡조건부 → ✅ (4단계 통과 시)
- [ ] 점수 갱신 — `충족 0/5` → `충족 1/5`(§1만). **§2~§5는 서비스 Kafka(Track B) 의존** → Day2 이후
- [ ] HANDOFF_HUB 인프라/서비스 상태 ✅ 반영

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
