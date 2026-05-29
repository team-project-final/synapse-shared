# W3 배포 검증 리포트

> **작성일**: 2026-05-29 (W3 Day 4)
> **WORKFLOW**: Step 8 (설계·정책 §1.2/1.4/1.5/1.10 = 작성 / 실행 §1.7~1.9 = 차단)
> **작성자**: @team-lead

> **상태 요약**: dev/staging **실배포 검증은 EKS destroy(비용관리)로 미실행**. 본 리포트는 오늘 가능한 **배포 전략·승인 플로우·롤백 절차 정의**(Step 8 설계 항목)를 확정하고, 실행 검증 항목은 인프라 재기동 후 채울 체크리스트로 남긴다. gitops 측 매니페스트(staging overlay 5개 + ApplicationSet manual, ESO 5/5)는 05-21~22 세션에서 이미 구성됨.

---

## A. 배포 전략 정의 (오늘 작성 — Step 8 §1.2 / §1.4)

### 환경별 Sync 정책

| 환경 | syncPolicy | 트리거 | 승인 |
|------|-----------|--------|------|
| dev | **automated** (autoSync: true, prune/selfHeal) | main push → deploy.yml → ECR tag → gitops 갱신 | 불필요 |
| staging | **manual** (autoSync: false) | dev 이미지 태그 프로모션 | 수동 Sync(승인자) |
| prod | (W4) manual + 승인 게이트 | — | — |

### dev → staging 프로모션 플로우

```
dev 배포 검증 OK (Healthy)
  → 이미지 태그를 staging overlay에 프로모션 (kustomize image tag)
  → ArgoCD staging Application 수동 Sync
  → 헬스체크 통과 → 프로모션 완료
```

### 헬스체크 기준 (배포 완료 판정)

- 모든 서비스 ArgoCD `Synced` + `Healthy`
- `/actuator/health` (Java) / `/health` (FastAPI) → UP
- 의존성 연결: Kafka consumer group lag = 0(해당 서비스), RDS/Redis/OpenSearch 연결 OK
- replicas: dev ≥ 1, staging ≥ 2 (HA)

## B. 롤백 절차 정의 (오늘 작성 — Step 8 §1.4 / 목표 < 3분)

| 단계 | 동작 | 명령/방법 |
|:----:|------|----------|
| 1 | 이상 감지 | ArgoCD Degraded / 헬스체크 실패 / 알림 |
| 2 | 직전 정상 리비전 식별 | `argocd app history <app>` |
| 3 | 롤백 실행 | `argocd app rollback <app> <revision>` (또는 gitops 이미지 태그 직전 값으로 revert + Sync) |
| 4 | 검증 | 헬스체크 ALL HEALTHY 재확인 |
| 5 | 원복(수정 후) | 수정 이미지 재배포 → Sync → Healthy |

> dev는 autoSync/selfHeal 때문에 git revert 기반 롤백 권장(매니페스트 직전 상태로). staging은 manual이라 `app rollback` 직접 사용 가능.

## C. Security 2차 (오늘 작성 — Step 8 §1.5)

| 항목 | 정의 |
|------|------|
| 환경별 시크릿 분리 | dev/staging 별 ExternalSecret + ClusterSecretStore(ESO IRSA `synapse-dev-eso-role`). 환경 네임스페이스 분리(synapse-dev / synapse-staging) |
| staging 배포 승인 권한자 | @team-lead (ArgoCD RBAC: staging sync 권한 한정) — 재기동 후 RBAC 정책 명문화 필요 |
| 배포 이력(audit trail) | ArgoCD app history + Git 커밋 이력(gitops) = 배포 추적원 |
| 자동 배포 경계 | dev만 autoSync. staging/prod는 수동 — 비검증 이미지 자동 승격 차단 |

---

## D. 실행 검증 체크리스트 (인프라 재기동 후 채움)

### Dev 환경

| 항목 | 결과 | 비고 |
|------|:----:|------|
| ArgoCD 5/5 Synced + Healthy | ⏳ 미실행 | EKS destroy |
| 헬스체크 ALL HEALTHY | ⏳ 미실행 | |
| Kafka 연결 (각 서비스 로그) | ⏳ 미실행 | |
| RDS / Redis / OpenSearch 연결 | ⏳ 미실행 | apply 후 SG 수동 추가(D-026) |

### Staging 환경

| 항목 | 결과 | 비고 |
|------|:----:|------|
| Namespace synapse-staging Active | ⏳ 미실행 | overlay/ApplicationSet는 구성 완료 |
| ArgoCD 5/5 Synced + Healthy | ⏳ 미실행 | manual sync 대기 |
| ExternalSecret 5/5 SecretSynced | ⏳ 미실행 | |
| Replicas ≥ 2 (HA) | ⏳ 미실행 | |
| SPRING_PROFILES_ACTIVE=staging | ⏳ 미실행 | platform-svc staging 프로필 이슈 재확인 필요 |
| dev/staging 리소스 분리 확인 | ⏳ 미실행 | |

### Observability (W3 PRD FR-GO-303~307, gitops)

| 항목 | 결과 | 비고 |
|------|:----:|------|
| Prometheus / Grafana / Alertmanager Running | ⏳ 미실행 | gitops 세션 미진행 |
| ServiceMonitor 5개 + Targets up | ⏳ 미실행 | |
| Grafana 대시보드 + 알림 규칙 3개 | ⏳ 미실행 | |

### 롤백 테스트

| 항목 | 결과 | 비고 |
|------|:----:|------|
| 이전 리비전 롤백 실행 / Healthy / 원복 | ⏳ 미실행 | 절차는 §B 정의 완료 |
| 롤백 소요 시간 (목표 < 3분) | ⏳ 미실행 | |

### terraform state

| 항목 | 결과 | 비고 |
|------|:----:|------|
| SG / OIDC 코드 반영 | ⏳ 미실행 | apply 시 SG 수동 추가 단계 코드화 필요(D-026) |
| terraform plan → no unexpected drift | ⏳ 미실행 | |

---

## E. 미해결 항목

| # | 항목 | 우선순위 | W4 이월 | 비고 |
|---|------|:--------:|:-------:|------|
| 1 | dev/staging 실배포 검증 전체 | P0 | ✅ | terraform apply 선행 |
| 2 | Observability 스택 설치 (gitops) | P1 | ✅ | W3 PRD FR-GO-303~307 |
| 3 | platform-svc staging 프로필 | P1 | ✅ | staging 5/5 달성 차단 |
| 4 | SG/OIDC terraform 코드화 (D-026 수동 단계 제거) | P2 | ✅ | |
| 5 | staging sync ArgoCD RBAC 승인자 명문화 | P2 | ✅ | §C |
