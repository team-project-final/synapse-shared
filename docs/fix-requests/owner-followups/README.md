# W5 owner 후속 작업 — 미완료 owner 이슈 (2026-06-10)

전체 레포 최신화 후 실측한 **미완료 owner 작업**을 각 레포에 상세 이슈로 발행. (이미 트래커가 있는 항목은 제외 — 예: engagement #26 TLS·#28 Flyway, knowledge #48 Flyway, API 문서 #84/#67/#72.)

| 이슈 | 레포 | 항목 | 본문 |
|---|---|---|---|
| [platform#86](https://github.com/team-project-final/synapse-platform-svc/issues/86) | platform-svc | **F8** 관리자 ADMIN role 발급 메커니즘 부재(모더레이션 차단) | [platform-f8-admin-role](./platform-f8-admin-role.md) |
| [platform#87](https://github.com/team-project-final/synapse-platform-svc/issues/87) | platform-svc | audit 컨슈머 ReviewCompleted **DLT 적재** 조사(Day3 관찰) | [platform-audit-reviewcompleted-dlt](./platform-audit-reviewcompleted-dlt.md) |
| [learning#73](https://github.com/team-project-final/synapse-learning-svc/issues/73) | learning-svc (learning-ai) | **F4** AI 키 graceful 게이트 부재 + provisioning | [learning-ai-f4-key-gate](./learning-ai-f4-key-gate.md) |
| [knowledge#68](https://github.com/team-project-final/synapse-knowledge-svc/issues/68) | knowledge-svc | dev→main 미반영 18커밋(F9·MSK TLS·Flyway·검색) | [knowledge-dev-to-main-release](./knowledge-dev-to-main-release.md) |
| [learning#81](https://github.com/team-project-final/synapse-learning-svc/issues/81) | learning-svc (learning-card) | **ReviewCompleted 발행 스키마 정본 분기** → platform audit DLT 근본수정(가설 A 확정) | [learning-card-reviewcompleted-schema-align](./learning-card-reviewcompleted-schema-align.md) |
| [engagement#40](https://github.com/team-project-final/synapse-engagement-svc/issues/40) · [knowledge#77](https://github.com/team-project-final/synapse-knowledge-svc/issues/77) · [learning#82](https://github.com/team-project-final/synapse-learning-svc/issues/82) · [platform#97](https://github.com/team-project-final/synapse-platform-svc/issues/97) | 4종 owner-svc | **GitHub Actions Node 20 deprecation 업그레이드**(+ engagement amazon-ecr-login@v3 깨진 태그) — shared #56 선례 | [owner-actions-node24-upgrade](./owner-actions-node24-upgrade.md) |
| [gitops#182](https://github.com/team-project-final/synapse-gitops/issues/182) + 각 svc owner | gitops + 서비스 owner | **W5 Day4 staging**: bastion IAM(eks:DescribeCluster) 결여로 bring-up 중단(복구됨) + 서비스 ECR 레포 7종 미프로비저닝(team-lead 선생성) → **서비스 이미지 빌드·push 필요(owner)** | [STAGING_BRINGUP_W5_DAY4](../../reports/STAGING_BRINGUP_W5_DAY4.md) |
| [platform#101](https://github.com/team-project-final/synapse-platform-svc/issues/101) · [engagement#45](https://github.com/team-project-final/synapse-engagement-svc/issues/45) · [knowledge#82](https://github.com/team-project-final/synapse-knowledge-svc/issues/82) · [learning#85](https://github.com/team-project-final/synapse-learning-svc/issues/85) · [gitops#194](https://github.com/team-project-final/synapse-gitops/issues/194) | 4 svc owner + gitops | **메트릭 갭(Day4 24h 사인오프 선결)**: `/actuator/prometheus` 5/6 서비스 실패(500/401/404) + EKS 컨트롤플레인 알림 false-positive 룰 튜닝 | [STAGING_BRINGUP_W5_DAY4 §10](../../reports/STAGING_BRINGUP_W5_DAY4.md) |

> 발표(06-15) 차단 등급: F8(모더레이션 데모)·F4(AI 데모)가 🟡. knowledge 릴리스는 배포 정합. audit DLT는 **가설 A 확정**(learning#81 정본 정렬이 근본수정, platform#87은 정본 유지).
> 근거: [W4_EXIT_GATE](../../reports/W4_EXIT_GATE.md) · [SHARED_W1W4_INCOMPLETE_REVIEW](../../reports/SHARED_W1W4_INCOMPLETE_REVIEW.md) · [HANDOFF_W5_DAY3 §0](../../project-management/HANDOFF_W5_DAY3.md)
