# Synapse 통합 핸드오프 허브

> **최종 갱신**: 2026-06-02 (W4 Day 2 — v0.1.0 발행·게이트 §1 ✅·E2E/SLA 시나리오 정의·MSK terraform/TLS 정합. gitops EKS window 하드닝 #87~89 완료, #91 잔여)
> **현재 주차**: W4 Day 2 (06-02)
> **갱신자**: @VelkaressiaBlutkrone

---

## 1. 프로젝트 상태 대시보드

### 환경별 서비스 상태

> ⏳ **EKS는 on-demand** — **현재 destroy** (06-01 apply→검증보류→destroy). 상태는 apply↔destroy로 변동 → **확인은 `aws eks describe-cluster --name synapse-dev`**(STATUS/존재 여부). **재apply 선결(bastion aws-auth·SG·브로커·토픽)은 06-02 gitops 하드닝(#87~89)으로 terraform 자동화** → 잔여는 **ArgoCD 부트스트랩([gitops #91](https://github.com/team-project-final/synapse-gitops/issues/91))**([W4_DAY1_POST_APPLY](../runbooks/W4_DAY1_POST_APPLY.md)).
> **임계경로(서비스 Kafka·통합 E2E·계약)는 EKS 무관** → **로컬 docker-compose**로 진행([W4_PLAN](./W4_PLAN.md) §0 "[배포] Kafka 무관, 병렬 가능"). EKS는 **배포 검증(Step 8/11)·Observability window**에만 재기동 → 검증 → 다시 destroy.
> 재기동 시 절차: [W4_DAY1_POST_APPLY](../runbooks/W4_DAY1_POST_APPLY.md).

| 서비스 | 로컬 compose | dev (EKS) | staging | prod |
|---|---|---|---|---|
| platform-svc | ✅ Healthy | ⏳ destroy | ⏳ destroy | ⏳ W4 |
| engagement-svc | ✅ Healthy | ⏳ destroy | ⏳ destroy | ⏳ W4 |
| knowledge-svc | ✅ Healthy | ⏳ destroy | ⏳ destroy | ⏳ W4 |
| learning-card | ✅ Healthy | ⏳ destroy | ⏳ destroy | ⏳ W4 |
| learning-ai | ✅ Healthy | ⏳ destroy | ⏳ destroy | ⏳ W4 |

> 상태 enum: ✅ Healthy / 🔄 검증 대기(apply 후) / ⚠️ Degraded / 🔴 Down / ⏳ destroy(on-demand 재기동) or Not Started
> dev/staging EKS는 05-22 5/5 Healthy 달성 → 비용관리 destroy → 06-01 apply → **재 destroy**. **배포 검증 window에 재기동** 후 `verify-argocd-deploy.sh synapse-dev` 5/5 재확인하면 ✅. 로컬 compose는 항상 ✅.

### 인프라 상태

| 컴포넌트 | 상태 | 비고 |
|---|---|---|
| EKS | ⏳ destroy (on-demand) | 06-01 destroy. 재apply 시 v1.30, 프라이빗 엔드포인트. **bastion aws-auth 코드화 완료(gitops #87)** → kubectl 401 해소 |
| RDS PostgreSQL 16 | ⏳ destroy | **D-026 SG terraform 코드화 완료(gitops #89)** — 재apply 시 자동(수동 불요) |
| MSK Kafka | ⏳ destroy | **토픽 terraform 관리(gitops kafka-topics/, RF=2)** + **브로커 주소 ConfigMap 자동화(#88)** → 재apply 시 자동. 로컬 Kafka로 대체 검증 |
| Redis | ⏳ destroy | D-026 SG terraform 코드화 완료(#89) — 자동 |
| OpenSearch | ⏳ destroy | D-026 SG terraform 코드화 완료(#89) — 자동 |
| ArgoCD | ⏳ destroy | HA, dev auto-sync + staging manual. 재apply 시 **부트스트랩 필요([gitops #91](https://github.com/team-project-final/synapse-gitops/issues/91), P0)** → verify 5/5 |
| 로컬 docker-compose | ✅ | 13 서비스 Healthy — **W4 임계경로 검증 환경**(EKS 무관) |

### Kafka / 스키마 상태

| 항목 | 상태 |
|---|---|
| **이벤트 계약 표준** | ✅ 수립 — Avro + Schema Registry (D-002 Option 1). [EVENT_CONTRACT_STANDARD](../guides/EVENT_CONTRACT_STANDARD.md) |
| Avro 스키마 | ✅ 이벤트 11종(기존 보강 + 신규 CardReviewDue/LevelUp/BadgeEarned/NotificationSend), 공통메타 적용, generateAvroJava 컴파일. BACKWARD |
| 토픽 (로컬 Kafka) | ✅ 8종 생성(신규 4종 추가: review-due/level-up/badge-earned/notification-send) + round-trip 검증 |
| MSK 토픽 (EKS) | ⏳ destroy — 재기동 window에 `create-kafka-topics.sh` 9토픽(8 active + cards-generated 잔존) 재생성 |
| 로컬 E2E harness | ✅ transport(`--all`/`--full`) + **Avro 라운드트립(`--avro`)** 모드 |
| 라이브러리 발행 | ✅ **발행 완료(06-02)** — GitHub Packages `com.synapse:synapse-shared:0.1.0`([runbook](../runbooks/PUBLISH_SHARED_LIBRARY.md)). `v0.1.0` 태그 push → publish.yml run 26792658024 성공. 잔여: 각 서비스 소비측 의존 배선(read:packages 토큰) |
| 서비스 Kafka Producer/Consumer | 🟡 dev (**06-01 코드 실측**): **platform** 🟢(Avro+Outbox·notification/audit Consumer·멱등성) · **learning** 🟢(Avro 소비+알림발행, #32 CLOSED) — 둘 다 **dev 고립·PR 0건 → main 머지 필요** / **engagement** 🔴(Consumer 0건 + ⚠️**자체 스키마 비호환**: GamificationLevelUp@event.engagement, eventId 없음, occurredAt logicalType=표준위반) / **knowledge** 🔴(NoteCreated Kafka Producer 부재, in-process listener만 → 체인 시작점 단절). cards-generated HTTP(D-001). → [W4_KAFKA_WORKORDER §0.5](../work-orders/W4_KAFKA_WORKORDER.md) |

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
| synapse-gitops | `docs/project-management/history/HISTORY_gitops.md` | 2026-06-02 | ✅ 동기 — MSK 토픽 terraform화·TLS-only·EKS window 하드닝(#87~89) 완료, #91 잔여 |
| synapse-shared | `docs/project-management/HANDOFF_SHARED.md` | 2026-06-02 | ✅ 동기 |

---

## 4. 다음 세션 작업 순서

> **W3 종료 → W4 인수인계**: W3 종료 게이트 미통과(**충족 1/5** · 부분 1 · 미확인 3, [W3_EXIT_GATE](../reports/W3_EXIT_GATE.md)). **§1 레지스트리 BACKWARD는 06-02 로컬 `--avro`(8/8)+강제 프로브로 실검증 → ✅.** shared 전제(토픽·스키마·harness·Security·배포전략·계약표준·발행)는 완료.
> **▶ 월요일(06-01) 바로 시작 순서: [W4_PLAN.md](./W4_PLAN.md)** — Day1 병렬 2트랙(A: EKS `terraform apply` / B: v0.1.0 발행 + knowledge Producer 착수 + 필드 확정), 화요일 consumer, 목요일 통합 E2E.

```
1. [shared/팀] 🔴 최우선 — Kafka 구현 완성 (05-29 실측 기반 재정렬 → W4_KAFKA_WORKORDER)
     → knowledge Producer 신규(P0) · engagement Consumer 추가+머지(P0) · platform dev→main PR(P1)
     → 선결: cards-generated HTTP/Kafka 아키텍처 결정 (W4 Day 1 데일리)
     → 완료 기준: 역할별 구현 → 승인 기준 통과 → main 머지
2. [shared] 서비스 PR 도착 시 E2E consumer 시나리오 확장 검증
     → ✅ 선행 완료: 로컬 harness 전송 경로 + CloudEvent 단위 round-trip (--all 5/5, --full 13/13)
     → 잔여: E2E_SCENARIOS_W3.md 시나리오로 consumer 비즈니스 로직까지 검증
3. [gitops] terraform apply (EKS destroy 상태) → **ArgoCD 부트스트랩([#91](https://github.com/team-project-final/synapse-gitops/issues/91), P0)** → `verify-argocd-deploy.sh synapse-dev` 5/5
     → ✅ 선결 자동화 완료(06-02): 토픽 terraform·브로커 ConfigMap(#88)·D-026 SG(#89)·bastion aws-auth(#87). 수동 단계 제거
4. [platform owner] platform-svc `application-staging.yml`(Spring 프로필) → staging 5/5
     → gitops overlay(`apps/platform-svc/overlays/staging`)는 이미 존재 — 서비스 프로필만 잔여
5. [gitops] Observability 설치 — 매니페스트 작성됨(`infra/monitoring/`) → window apply + 서비스별 `/metrics` 노출(서비스 owner)
6. [gitops] terraform state 정리 — D-026 SG ✅(#89 완료) / OIDC 코드 반영 잔여
     → 완료 기준: terraform plan → no unexpected drift
```

---

## 5. 주간 마일스톤 추적

| 주차 | 목표 | 상태 | 실제 완료일 |
|---|---|---|---|
| W1 (5/12-16) | ArgoCD bootstrap + CI | ✅ 완료 | 5/16 |
| W2 (5/19-23) | Dev 5앱 + secrets + image sync | ✅ 완료 | 5/21 (9차 세션) |
| W3 (5/26-29) | Kafka E2E + Staging + Observability | 🔴 게이트 미통과 | 종료 충족 **1/5** (부분 1·미확인 3) — §1 레지스트리 BACKWARD 06-02 실검증 ✅. shared 전제 완료. 서비스 Kafka 부분구현(learning·platform dev완성 / engagement·knowledge 🔴) + EKS destroy로 W4 이월 |
| W4 (6/01-05) | Notification/Audit 소비 + Admin 모더레이션 + 통합 E2E + dev/staging 배포 검증 | 🔄 진행(Day2) | — · team-lead: 발행·게이트§1·시나리오·인프라정합 완료 / 서비스 consumer 머지 대기 |
| W5 (6/08-12) | E2E + 버그수정 + P1 마무리 + Staging + 발표 자료/리허설 (발표 6/15) | ⏳ 계획 | — |
