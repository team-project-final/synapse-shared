# Synapse 통합 핸드오프 허브

> **최종 갱신**: 2026-05-29 (W3 종료 세션 — 게이트 평가 + W4 인수인계)
> **현재 주차**: W3 종료 → W4 전환
> **갱신자**: @VelkaressiaBlutkrone

---

## 1. 프로젝트 상태 대시보드

### 환경별 서비스 상태

> ⚠️ **EKS 클러스터는 비용관리로 destroy 상태** (05-26~). W3 검증은 **로컬 docker-compose** 기준. dev/staging EKS 상태는 인프라 재기동(`terraform apply`) 후 재확인 필요.

| 서비스 | 로컬 compose | dev (EKS) | staging | prod |
|---|---|---|---|---|
| platform-svc | ✅ Healthy | ⏳ destroy | ⏳ destroy | ⏳ W4 |
| engagement-svc | ✅ Healthy | ⏳ destroy | ⏳ destroy | ⏳ W4 |
| knowledge-svc | ✅ Healthy | ⏳ destroy | ⏳ destroy | ⏳ W4 |
| learning-card | ✅ Healthy | ⏳ destroy | ⏳ destroy | ⏳ W4 |
| learning-ai | ✅ Healthy | ⏳ destroy | ⏳ destroy | ⏳ W4 |

> 상태 enum: ✅ Healthy / ⚠️ Degraded / 🔴 Down / ⏳ destroy(재기동 필요) or Not Started
> dev/staging EKS는 05-22 시점 5/5 Healthy 달성 후 비용관리 destroy. 재기동 시 마지막 검증 상태 복원 예상.

### 인프라 상태

| 컴포넌트 | 상태 | 비고 |
|---|---|---|
| EKS | ⏳ destroy | 비용관리로 종료, 재기동은 `terraform apply` (SG/OIDC 수동 단계 D-026 동반) |
| RDS PostgreSQL 16 | ⏳ destroy | apply 후 SG 수동 추가 필요 (D-026) |
| MSK Kafka | ⏳ destroy | (로컬 Kafka로 대체 검증) apply 후 토픽 재생성 + 브로커 주소 ConfigMap 갱신 필요 |
| Redis | ⏳ destroy | apply 후 SG 수동 추가 필요 |
| OpenSearch | ⏳ destroy | apply 후 SG 수동 추가 필요 |
| ArgoCD | ⏳ destroy | HA 모드, dev auto-sync + staging manual (재기동 시 복원) |
| 로컬 docker-compose | ✅ | 13 서비스 Healthy — W3 검증 기준 환경 |

### Kafka / 스키마 상태

| 항목 | 상태 |
|---|---|
| Avro 스키마 8개 | ✅ BACKWARD 호환 |
| 토픽 5개 (로컬 Kafka) | ✅ 생성 + E2E round-trip 검증 (`--all` 5/5, `--full` 13/13) |
| MSK 토픽 (EKS) | ⏳ destroy — 재기동 후 재생성 |
| 로컬 E2E harness | ✅ CloudEvent 페이로드 단위 검증 신뢰 가능 (D-2 해결) |
| 서비스 Kafka Producer/Consumer | 🟡 부분 (05-29 실측): learning-card ✅main / learning-ai 🟡Consumer만main / platform·engagement 🟡dev미머지 / knowledge 🔴미구현. cards-generated HTTP 대체. → [W4_KAFKA_WORKORDER](../work-orders/W4_KAFKA_WORKORDER.md) |

---

## 2. 교차 의존관계 맵

```
[블로커-최우선] 서비스 Kafka 구현 (05-29 실측: learning main머지 / platform·engagement dev미머지 / knowledge 미구현)
    ├─ knowledge NoteCreated/Updated Producer 신규 (체인 B 시작점)
    ├─ engagement Consumer 추가 (역할 미이행) + dev→main
    └─ platform dev→main PR
    └─→ shared E2E consumer 비즈니스 로직 검증 가능 (현재 전송 경로만 검증됨)
        └─→ W3 종료 게이트 충족 (PRD_W3 §5) → staging 프로모션 테스트

[선행완료] 로컬 E2E harness — 전송 경로 + CloudEvent 단위 round-trip 검증 ✅

[블로커] terraform apply (인프라 재기동) — EKS destroy 상태
    └─→ dev/staging EKS 검증 + MSK 토픽 재생성

[블로커] platform-svc application-staging.yml 추가
    └─→ staging 5/5 Healthy 달성 (인프라 재기동 후)

[독립] Observability 스택 설치 (gitops) → W3 PRD FR-GO-303~307
[독립] terraform state 정리 — SG/OIDC 코드 반영 (gitops)
```

---

## 3. 스포크 참조

| 레포 | 스포크 문서 | 최종 갱신 | 정합성 |
|---|---|---|---|
| synapse-gitops | `docs/superpowers/HANDOFF_W3.md` | 2026-05-22 | ⚠️ W3 미반영 (gitops 세션 미진행) |
| synapse-shared | `docs/project-management/HANDOFF_SHARED.md` | 2026-05-29 | ✅ 동기 |

---

## 4. 다음 세션 작업 순서

> **W3 종료 → W4 인수인계**: W3 종료 게이트 미통과(0.5/5, [W3_EXIT_GATE](../reports/W3_EXIT_GATE.md)). shared 전제(토픽·스키마·harness·Security·배포전략)는 완료, 아래 1~2가 W4 Day 1 최우선 carryover.

```
1. [shared/팀] 🔴 최우선 — Kafka 구현 완성 (05-29 실측 기반 재정렬 → W4_KAFKA_WORKORDER)
     → knowledge Producer 신규(P0) · engagement Consumer 추가+머지(P0) · platform dev→main PR(P1)
     → 선결: cards-generated HTTP/Kafka 아키텍처 결정 (W4 Day 1 데일리)
     → 완료 기준: 역할별 구현 → 승인 기준 통과 → main 머지
2. [shared] 서비스 PR 도착 시 E2E consumer 시나리오 확장 검증
     → ✅ 선행 완료: 로컬 harness 전송 경로 + CloudEvent 단위 round-trip (--all 5/5, --full 13/13)
     → 잔여: E2E_SCENARIOS_W3.md 시나리오로 consumer 비즈니스 로직까지 검증
3. [gitops] terraform apply + 세션 기동 (runbook 12단계) — EKS destroy 상태
     → docs/runbooks/w2-session-bootstrap-runbook.md, MSK 토픽 재생성
4. [gitops] platform-svc staging 프로필 해결 → staging 5/5 (재기동 후)
     → 완료 기준: argocd app sync synapse-platform-svc-staging → Healthy
5. [gitops] Observability 스택 설치 (kube-prometheus-stack) + ServiceMonitor 5개 + Grafana
6. [gitops] terraform state 정리 (SG/OIDC 코드 반영)
     → 완료 기준: terraform plan → no unexpected drift
```

---

## 5. 주간 마일스톤 추적

| 주차 | 목표 | 상태 | 실제 완료일 |
|---|---|---|---|
| W1 (5/12-16) | ArgoCD bootstrap + CI | ✅ 완료 | 5/16 |
| W2 (5/19-23) | Dev 5앱 + secrets + image sync | ✅ 완료 | 5/21 (9차 세션) |
| W3 (5/26-29) | Kafka E2E + Staging + Observability | 🔴 게이트 미통과 | 종료 0.5/5 — shared 전제 완료. 서비스 Kafka 부분구현(learning main / platform·engagement dev / knowledge 미구현) + EKS destroy로 W4 이월 |
| W4 (6/01-05) | Prod + approval + rollback | ⏳ 계획 | — |
| W5 (6/08-12) | Runbooks + DR + 비용 최적화 | ⏳ 계획 | — |
