# Synapse 통합 핸드오프 허브

> **최종 갱신**: 2026-05-22 (W2 → W3 전환)
> **현재 주차**: W3
> **갱신자**: @VelkaressiaBlutkrone

---

## 1. 프로젝트 상태 대시보드

### 환경별 서비스 상태

| 서비스 | dev | staging | prod |
|---|---|---|---|
| platform-svc | ✅ Healthy | ⚠️ staging 프로필 미존재 | ⏳ W4 |
| engagement-svc | ✅ Healthy | ✅ Healthy | ⏳ W4 |
| knowledge-svc | ✅ Healthy | ✅ Healthy | ⏳ W4 |
| learning-card | ✅ Healthy | ✅ Healthy | ⏳ W4 |
| learning-ai | ✅ Healthy | ✅ Healthy | ⏳ W4 |

> 상태 enum: ✅ Healthy / ⚠️ Degraded / 🔴 Down / ⏳ Not Started

### 인프라 상태

| 컴포넌트 | 상태 | 비고 |
|---|---|---|
| EKS | ✅ | destroy/apply 반복 (비용 관리), private endpoint |
| RDS PostgreSQL 16 | ✅ | SG 매 apply 후 수동 추가 필요 (D-026) |
| MSK Kafka | ✅ | 토픽 5개 생성 완료, 브로커 주소 PR #42 반영 |
| Redis | ✅ | SG 수동 추가 필요 |
| OpenSearch | ✅ | SG 수동 추가 필요 |
| ArgoCD | ✅ | HA 모드, dev auto-sync + staging manual |

### Kafka / 스키마 상태

| 항목 | 상태 |
|---|---|
| Avro 스키마 8개 | ✅ BACKWARD 호환 |
| MSK 토픽 5개 | ✅ 생성 완료 |
| 서비스 Kafka Producer/Consumer | 🔴 5/5 미착수 |

---

## 2. 교차 의존관계 맵

```
[블로커] platform-svc application-staging.yml 추가
    └─→ staging 5/5 Healthy 달성

[블로커] 5개 서비스 Kafka Producer/Consumer 구현 (서비스 레포)
    └─→ shared E2E 검증 가능
        └─→ staging 프로모션 테스트

[독립] Observability 스택 설치 (gitops)
    └─→ W3 PRD FR-GO-303~307

[독립] terraform state 정리 — SG/OIDC 코드 반영 (gitops)
```

---

## 3. 스포크 참조

| 레포 | 스포크 문서 | 최종 갱신 | 정합성 |
|---|---|---|---|
| synapse-gitops | `docs/superpowers/HANDOFF_W3.md` | 2026-05-22 | ✅ 동기 |
| synapse-shared | `docs/project-management/HANDOFF_SHARED.md` | 2026-05-22 | ✅ 동기 |

---

## 4. 다음 세션 작업 순서

```
1. [gitops] terraform apply + 세션 기동 (runbook 12단계)
     → docs/runbooks/w2-session-bootstrap-runbook.md
2. [gitops] platform-svc staging 프로필 해결 → staging 5/5
     → 완료 기준: argocd app sync synapse-platform-svc-staging → Healthy
3. [gitops] Observability 스택 설치 (kube-prometheus-stack)
     → 완료 기준: Prometheus + Grafana + Alertmanager Running
4. [gitops] ServiceMonitor 5개 + Grafana 대시보드
     → 완료 기준: Grafana Explore에서 5개 앱 메트릭 조회
5. [shared] 서비스별 Kafka 구현 상태 확인 + E2E 준비
     → 완료 기준: kafka-e2e-test.sh --all PASS
6. [gitops] terraform state 정리 (SG/OIDC 코드 반영)
     → 완료 기준: terraform plan → no unexpected drift
```

---

## 5. 주간 마일스톤 추적

| 주차 | 목표 | 상태 | 실제 완료일 |
|---|---|---|---|
| W1 (5/12-16) | ArgoCD bootstrap + CI | ✅ 완료 | 5/16 |
| W2 (5/19-23) | Dev 5앱 + secrets + image sync | ✅ 완료 | 5/21 (9차 세션) |
| W3 (5/26-29) | Staging + Observability | ⏳ 미시작 | — |
| W4 (6/01-05) | Prod + approval + rollback | ⏳ 계획 | — |
| W5 (6/08-12) | Runbooks + DR + 비용 최적화 | ⏳ 계획 | — |
