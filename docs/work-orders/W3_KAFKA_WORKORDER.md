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

## 추적 (Day 2~3 갱신)

> **Day 2 조회 (2026-05-27 오전, `gh pr list`)**: Kafka Producer/Consumer work-order 산출물 PR **0/5**. 열린 PR 2건은 work-order 범위(Kafka 발행/소비) 밖. 기한은 오늘 EOD — 미도착 시 EOD 후 ❌ 표기.

| 서비스 | PR 생성 | 리뷰 | 머지 | 비고 |
|--------|:------:|:----:|:----:|------|
| platform-svc | ⏳ | — | — | PR [#33](https://github.com/team-project-final/synapse-platform-svc/pull/33) 열림 — W2 완료/MSA 테스트 env, **Kafka 파일 0건 → work-order 아님** |
| knowledge-svc | ⏳ | — | — | PR [#23](https://github.com/team-project-final/synapse-knowledge-svc/pull/23) 열림 — 그래프 조회 API + 청킹(in-process `@TransactionalEventListener`) + `note-created-v1.avsc` 스키마 기반작업. **Kafka NoteCreated/Updated Producer 미포함** (스키마는 선행 토대로 관련) |
| learning-card | ⏳ | — | — | 열린 PR 없음 |
| learning-ai | ⏳ | — | — | 열린 PR 없음 |
| engagement-svc | ⏳ | — | — | 열린 PR 없음 |

> 상태: ⏳ 대기 / 🔄 진행 / ✅ 완료 / ❌ 미착수(기한 초과)
