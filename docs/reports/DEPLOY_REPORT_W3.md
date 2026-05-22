# W3 배포 검증 리포트

> **작성일**: 2026-05-29 (예정)
> **WORKFLOW**: Step 8.10
> **작성자**: @team-lead

---

## Dev 환경

| 항목 | 결과 | 비고 |
|------|:----:|------|
| ArgoCD 5/5 Synced + Healthy | | |
| 헬스체크 ALL HEALTHY | | |
| Kafka 연결 (각 서비스 로그) | | |
| RDS 연결 | | |
| Redis 연결 | | |
| OpenSearch 연결 | | |

## Staging 환경

| 항목 | 결과 | 비고 |
|------|:----:|------|
| Namespace synapse-staging Active | | |
| ArgoCD 5/5 Synced + Healthy | | |
| ExternalSecret 5/5 SecretSynced | | |
| Replicas >= 2 (HA) | | |
| SPRING_PROFILES_ACTIVE=staging | | |
| 헬스체크 ALL HEALTHY | | |
| dev/staging 리소스 분리 확인 | | |

## Observability

| 항목 | 결과 | 비고 |
|------|:----:|------|
| Prometheus Running | | |
| Grafana Running | | |
| Alertmanager Running | | |
| ServiceMonitor 5개 등록 | | |
| Prometheus Targets 5개 up | | |
| Grafana 대시보드 조회 가능 | | |
| 알림 규칙 3개 설정 | | |
| 알림 테스트 발동 확인 | | |

## 롤백 테스트

| 항목 | 결과 | 비고 |
|------|:----:|------|
| 이전 리비전 롤백 실행 | | 대상 서비스: |
| 롤백 후 Healthy 확인 | | |
| 원복 sync 후 Healthy 확인 | | |
| 롤백 소요 시간 | | 목표: < 3분 |

## terraform state

| 항목 | 결과 | 비고 |
|------|:----:|------|
| SG 코드 반영 | | |
| OIDC 코드 반영 | | |
| terraform plan → no unexpected drift | | |

## 미해결 항목

| # | 항목 | 우선순위 | W4 이월 여부 | 비고 |
|---|------|----------|:----------:|------|
| | | | | |
