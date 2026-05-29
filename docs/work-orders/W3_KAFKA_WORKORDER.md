# W3 Kafka 구현 Work-Order

> **작성일**: 2026-05-26 (W3 Day 1)
> **작성자**: @team-lead (synapse-shared)
> **우선순위**: P0 — W3/W4 Kafka E2E 통합 차단
> **PR 생성 기한**: 2026-05-27 (수, Day 2 종료)

## 배경

W3 목표는 모든 producer 토픽 발행 + consumer 처리(PRD_W3 FR-*-201 계열). 현재 5개 서비스 Kafka Producer/Consumer **전부 미착수**. 각 owner는 아래 할당 범위를 구현하고 기한 내 PR을 생성한다.

## 인프라 현황 (중요)

- EKS 클러스터는 비용 관리로 **destroy 상태** — 검증은 **로컬 docker-compose** 기준.
- 로컬 Kafka: `localhost:9092`(외부) / `kafka:29092`(컨테이너), Schema Registry `http://schema-registry:8081`.
- (선택) 로컬 k8s로 띄우려면 synapse-gitops `local-k8s/` 참조.

## 서비스별 할당

| # | 서비스 | 레포 | 역할 | 상세 구현 항목 | 이슈 |
|---|--------|------|------|----------------|------|
| 1 | platform-svc | synapse-platform-svc | Producer(UserRegistered) + Consumer(CardsGenerated) | TEAM_CHECKLIST_W3.md §platform-svc | [#30](https://github.com/team-project-final/synapse-platform-svc/issues/30) |
| 2 | knowledge-svc | synapse-knowledge-svc | Producer(NoteCreated, NoteUpdated) | TEAM_CHECKLIST_W3.md §knowledge-svc | [#22](https://github.com/team-project-final/synapse-knowledge-svc/issues/22) |
| 3 | learning-card | synapse-learning-svc | Producer(ReviewCompleted) | TEAM_CHECKLIST_W3.md §learning-card-svc | [#21](https://github.com/team-project-final/synapse-learning-svc/issues/21) |
| 4 | learning-ai | synapse-learning-svc | Producer(CardsGenerated) + Consumer(NoteCreated) | TEAM_CHECKLIST_W3.md §learning-ai-svc | [#22](https://github.com/team-project-final/synapse-learning-svc/issues/22) |
| 5 | engagement-svc | synapse-engagement-svc | Consumer(UserRegistered, ReviewCompleted) | TEAM_CHECKLIST_W3.md §engagement-svc | [#9](https://github.com/team-project-final/synapse-engagement-svc/issues/9) |

## 공통 요구사항 + 코드 리뷰 승인 기준

→ [TEAM_CHECKLIST_W3.md](../guides/TEAM_CHECKLIST_W3.md) "공통 요구사항" / "코드 리뷰 승인 기준" 참조.

## 참조 문서

- 이벤트 흐름: [EVENT_FLOW_MATRIX.md](../guides/EVENT_FLOW_MATRIX.md)
- E2E 시나리오: [E2E_SCENARIOS_W3.md](../guides/E2E_SCENARIOS_W3.md)
- E2E 검증 가이드: [KAFKA_E2E_TEST.md](../guides/KAFKA_E2E_TEST.md)

## 추적 — 최종 (2026-05-29 실측, origin 코드 직접 확인)

> ⚠️ **Day 2 "PR 0/5" 스냅샷 폐기.** 05-29 cross-repo `git fetch` 후 origin 브랜치 코드 직접 확인 결과 아래로 갱신. W4 carryover·재정렬은 → **[W4_KAFKA_WORKORDER.md](./W4_KAFKA_WORKORDER.md)**.

| 서비스 | 구현 위치 | 머지 | 역할 충족 | 비고 |
|--------|----------|:----:|:--------:|------|
| learning-card | **main (#26)** | ✅ | ✅ | CardReviewed + ReviewDue Publisher + 테스트 |
| learning-ai | **main (#26)** | ✅ | 🟡 | Consumer(NoteCreated) ✅. 카드 등록은 **HTTP(card_client)** → CardsGenerated 미발행 |
| platform-svc | dev | ❌ 미머지 | 🟡 | Producer(UserRegistered, Outbox) + audit/notification Consumer. open PR 없음. CardsGenerated 소비 ❌ |
| engagement-svc | dev | ❌ 미머지 | 🟡 | GamificationKafkaProducer만. **Consumer(@KafkaListener) 0건** — 할당 역할 미이행 |
| knowledge-svc | — | ❌ | 🔴 | **Kafka 전무**. in-process `@TransactionalEventListener`만. NoteCreated/Updated Producer 필요 |

> **종합**: main 머지 = learning-svc(#26)뿐(card 완전·ai 부분). platform/engagement는 dev 고립(PR 미생성). knowledge 미구현. **cards-generated 경로 HTTP 대체** → 아키텍처 정정 필요(W4 work-order §1).
> 상태: ✅ 완료 / 🟡 부분 / ❌ 미충족 / 🔴 미구현
