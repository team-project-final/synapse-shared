# Staging Bring-up & Day4 검증 — W5 Day4 (2026-06-11)

> **작성**: 2026-06-11 (team-lead) · **클러스터**: synapse-dev(EKS, ap-northeast-2) · **상위**: [W5_PLAN §4](../project-management/W5_PLAN.md) · [HANDOFF_W5_DAY3_CLOSEOUT](../project-management/HANDOFF_W5_DAY3_CLOSEOUT.md)

## 1. 한 줄 요약

gitops bring-up이 **bastion IAM 권한 결함으로 ArgoCD 부트스트랩 전에 중단**된 것을 team-lead가 로컬(SSM 터널+admin)으로 우회 복구. **인프라·ArgoCD·ESO·DB·Kafka·schema-registry·ES(nori)·Observability 전부 가동**. 남은 차단은 **서비스 이미지 미빌드(owner)** 1건.

## 2. bring-up 중단 근본 원인 (해소)

- bastion `synapse-dev-bastion-role`의 부착 정책이 **`AmazonSSMManagedInstanceCore` 하나뿐** → `eks:DescribeCluster` 없음. cloud-init bring-up의 `aws eks update-kubeconfig`가 `AccessDeniedException`으로 즉시 실패(02:44) → **ArgoCD 설치·부트스트랩·앱 sync 전 단계 미실행**(클러스터+노드만 ACTIVE, 35분간 무활동).
- **회복**: synapse-admin이 클러스터 access entry 보유 → 로컬 SSM 터널 + `bring-up.sh --from tunnel`로 argocd→eso→...→observability 멱등 재개. tfvars 시크릿(rds_password/redis) 주입.
- ⚠️ **근본 수정 필요(gitops/terraform)**: bastion role에 `eks:DescribeCluster`(+ 클러스터 접근) 권한 부여 — 안 하면 **다음 window bring-up도 동일하게 실패**. → gitops 이슈.

## 3. 검증 결과 (synapse-dev)

| 영역 | 상태 | 근거 |
|---|---|---|
| EKS 컨트롤플레인/노드 | ✅ ACTIVE / 4 Ready | `eks describe-cluster`, `get nodes` |
| ArgoCD | ✅ 설치 + 전 앱 **Synced** | `get applications` |
| ExternalSecrets(ESO) | ✅ 6종 SecretSynced | manifests phase |
| DB (RDS) | ✅ dev+staging 5종 생성 | db-init phase |
| Kafka 토픽 | ✅ 생성(멱등) | kafka-topics-init Completed |
| schema-registry | ✅ **Healthy** | app health |
| **Elasticsearch (nori)** | ✅ **Synced/Healthy, cluster green, analysis-nori 로드** | 아래 §4 |
| **Observability** | ✅ prometheus·alertmanager·grafana·loki·promtail Running + **ServiceMonitor 2·PrometheusRule 1·Grafana 대시보드 2** | monitoring ns |
| 서비스 앱 7종 | 🔴 **ImagePullBackOff (Degraded)** | 아래 §5 |

## 4. ES nori 정상화 (P3 인프라 leg)

- 초기 증상: `elasticsearch-0` CrashLoop — `failed to obtain lock on /usr/share/elasticsearch/data`(node.lock **AccessDenied**). EBS 데이터 볼륨이 root 소유라 ES(uid 1000)가 쓰기 불가.
- 원인: **fsGroup 적용 전 생성된 옛 파드**. main의 statefulset엔 `fsGroup:1000`+`OnRootMismatch`가 이미 있으나(커밋 727ad58), 라이브 StatefulSet이 fsGroup 반영 전 상태로 파드를 띄움.
- 조치: 파드 재생성 → fsGroup+OnRootMismatch가 EBS 볼륨 chown → **정상 부팅**. `cluster health=green`, `analysis-nori` 로드 확인.
- 잔여: `notes-v1`은 미생성(앱 인덱싱 전 정상 — 첫 색인 시 nori로 생성). **기능검색(결과>0)은 knowledge 인덱서(owner) 필요**.

## 5. 서비스 이미지 ImagePullBackOff (owner 차단)

- 증상: 7종(engagement-svc/frontend/gateway/knowledge-svc/learning-ai/learning-card/platform-svc) 전부 `ImagePullBackOff`.
- 근본 원인: **서비스 ECR 레포 자체가 부재**(`RepositoryNotFoundException`) — 가동 ECR 레포가 `synapse/elasticsearch`(team-lead가 #53때 생성) **단 하나뿐이었음**. gitops 핀 SHA 이미지(예: `synapse/platform-svc:ad235daa…`)가 push될 레포가 없었음.
- 조치(team-lead): 누락 **서비스 ECR 레포 7종 선생성**(MUTABLE, scanOnPush) — owner CI가 push 가능하도록 준비 완료.
- **남은 owner 작업**: 각 서비스 CI(deploy 파이프라인)로 **gitops 핀 SHA 이미지 빌드·push**(또는 gitops 태그를 새 빌드로 bump). engagement는 [engagement#40](https://github.com/team-project-final/synapse-engagement-svc/issues/40)(amazon-ecr-login@v3 깨진 태그)로 push 자체가 차단 → 선행 수정 필요.
- gateway는 team-lead/gitops 직접 대상 — 별도 빌드 경로 확인 필요.

## 6. 후속 (이 리포트 기준)

| # | 항목 | 책임 |
|---|---|---|
| 1 | bastion role `eks:DescribeCluster`(+클러스터 접근) 부여 — bring-up 자동화 복구 | gitops/terraform |
| 2 | 서비스 ECR 레포 7종 **terraform 관리화**(현재 수동 생성) | gitops/terraform |
| 3 | 서비스 이미지 빌드·push(레포 준비됨) | 각 owner |
| 4 | 기능검색 결과>0 — knowledge 인덱서 | knowledge owner |
| 5 | staging 24h 안정 모니터 — Observability 가동으로 착수 가능 | team-lead |

## 7. 접근 메모

- private 엔드포인트 → 로컬 kubectl은 **SSM 포트포워딩 터널**(`synapse-dev-bastion` 경유, `scripts/lib/eks-tunnel.sh` 또는 수동 `aws ssm start-session ... RemoteHost`) 필요. SSM 세션은 유휴 시 끊겨 재수립 빈번.
- 복구 절차: `bring-up.sh --from <phase>`(멱등, tfvars 시크릿 주입). ES 파드 크래시 시 파드 재생성으로 fsGroup chown 트리거.
