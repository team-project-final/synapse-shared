# W3 작업 구성 설계 — shared + gitops 통합 계획

> **작성일**: 2026-05-22
> **작성자**: @VelkaressiaBlutkrone
> **기간**: W3 2026-05-26 (화) ~ 05-29 (금), 4영업일
> **대상 레포**: synapse-shared + synapse-gitops

---

## 1. 배경

### W2 완료 상태

- Dev 5/5 Healthy 달성 (platform-svc, engagement-svc, knowledge-svc, learning-card, learning-ai)
- Staging overlay + ApplicationSet 생성 완료 (manual sync 대기)
- Avro 스키마 8개 BACKWARD 호환, MSK 토픽 5개 생성 완료
- E2E 테스트 스크립트/가이드/샘플 데이터 사전 준비 완료
- 서비스별 Kafka Producer/Consumer: **5/5 전부 미착수** (팀원 W3 구현 예정)

### W3 목표 (문서별 종합)

| 출처 | 목표 |
|------|------|
| KICKOFF 로드맵 | Kafka 이벤트 발행 + 검색 RRF + AI 카드 자동 생성 (팀 전체) |
| PRD_W3 FR-TL-201 | 모든 producer 토픽 BACKWARD 호환 등록 + 발행 동작 모니터링 |
| TASK Step 7+8 | E2E 검증/코드 리뷰 조율 (2일) + ArgoCD dev/staging 배포 검증 (1일) |
| HANDOFF_HUB 마일스톤 | Staging + Observability |

---

## 2. 접근법

**순차 의존 방식**: 기존 HANDOFF W2의 Day 1~4 계획을 유지하면서 Observability/terraform state 정리를 여유 있는 Day 2~3에 삽입.

- 매일 **gitops 세션 (선행) → shared 세션 (후행)** 순차 진행
- gitops 세션 결과가 shared 세션의 전제조건을 충족하는 구조
- 4개 트랙 전부 포함, 시간 부족 시 드롭 우선순위 적용

---

## 3. 4개 작업 트랙

| # | 트랙 | Day 배치 | W4 블로커 여부 |
|---|------|---------|:------------:|
| 1 | 인프라 기동 + Staging 배포 | Day 1~2 | **Yes** |
| 2 | Observability 스택 | Day 2~3 | No |
| 3 | Kafka E2E 검증 + 코드 리뷰 조율 | Day 1~4 | **Yes** |
| 4 | terraform state 정리 | Day 3 | No |

---

## 4. Day별 상세 계획

### Day 1 (05-26) — 인프라 기동 + 설계

#### gitops 세션 (선행)

| # | 작업 | 완료 기준 | 참조 |
|---|------|----------|------|
| 1-1 | terraform apply (인프라 재기동) | EKS/RDS/MSK/Redis/OpenSearch 정상 가동 | runbook 12단계 |
| 1-2 | aws eks update-kubeconfig | kubectl get nodes → Ready | |
| 1-3 | MSK 브로커 주소 확인 + 토픽 생성 | 5개 토픽 kafka-topics --list 확인 | MSK_TOPIC_SETUP.md |
| 1-4 | TLS 통신 확인 (openssl s_client) | 브로커 TLS 핸드셰이크 성공 | |
| 1-5 | verify-argocd-deploy.sh synapse-dev | 5/5 Healthy 재확인 | |
| 1-6 | verify-service-health.sh --env eks | 5/5 헬스체크 통과 | |
| 1-7 | Security 1차: Kafka ACL + 이벤트 페이로드 민감정보 점검 | 결과 → TASK Constraints 반영 | WORKFLOW Step 7.3 |

#### shared 세션 (후행)

| # | 작업 | 완료 기준 | 참조 |
|---|------|----------|------|
| 1-8 | 이벤트 흐름 매트릭스 작성 (Producer → Topic → Consumer) | 5개 토픽 × 서비스 매핑표 완성 | WORKFLOW Step 7.2 |
| 1-9 | 코드 리뷰 승인 기준 정의 (PR 템플릿, 리뷰어 지정) | Instructions → TASK 반영 | WORKFLOW Step 7.2 |
| 1-10 | 팀원 Kafka 구현 체크리스트 최종 확인 + 배포 | TEAM_CHECKLIST_W3.md 팀원 전달 완료 | |

**종료 게이트**: Dev 5/5 Healthy + MSK 5토픽 확인 + 이벤트 흐름 매트릭스 완성

---

### Day 2 (05-27) — Staging + Observability + 리뷰 시작

#### gitops 세션 (선행)

| # | 작업 | 완료 기준 | 참조 |
|---|------|----------|------|
| 2-1 | platform-svc application-staging.yml 해결 | staging 프로필 존재 확인 | HANDOFF_HUB 블로커 |
| 2-2 | staging 수동 Sync 실행 | argocd app sync → 5/5 Synced | STAGING_VERIFICATION.md |
| 2-3 | ExternalSecret staging 확인 | 5/5 SecretSynced | |
| 2-4 | staging 헬스체크 | verify-service-health.sh --env staging → 5/5 | |
| 2-5 | kube-prometheus-stack 설치 | Prometheus + Grafana + Alertmanager Running | Helm chart |
| 2-6 | Security 2차: 테스트 환경 시크릿 분리 + 네트워크 격리 확인 | 결과 → TASK Constraints 반영 | WORKFLOW Step 7.5 |

#### shared 세션 (후행)

| # | 작업 | 완료 기준 | 참조 |
|---|------|----------|------|
| 2-7 | E2E 시나리오 설계 (4개 체인) | gamification/community/card.review.due/audit 시나리오 문서화 | WORKFLOW Step 7.4 |
| 2-8 | 테스트 데이터 보강 (필요 시) | E2E 시나리오에 맞는 시드 데이터 확인 | WORKFLOW Step 7.6 |
| 2-9 | 팀원 PR 코드 리뷰 1차 착수 | 도착한 PR 리뷰 코멘트 작성 | **팀원 기한: 05-27 PR 생성** |

**종료 게이트**: Staging 5/5 Healthy + Prometheus/Grafana/Alertmanager Running + E2E 시나리오 4개 확정

---

### Day 3 (05-28) — Observability 마무리 + E2E 검증

#### gitops 세션 (선행)

| # | 작업 | 완료 기준 | 참조 |
|---|------|----------|------|
| 3-1 | ServiceMonitor 5개 생성 | Prometheus Targets에 5개 앱 등록 확인 | |
| 3-2 | Grafana 대시보드 구성 (서비스별 메트릭) | Grafana Explore에서 5개 앱 메트릭 조회 | |
| 3-3 | terraform state 정리 (SG/OIDC 코드 반영) | terraform plan → no unexpected drift | HANDOFF_HUB #6 |
| 3-4 | 롤백 시나리오 1회 테스트 | 이전 이미지 복원 → Healthy 확인 → 원복 | WORKFLOW Step 8.9 |

#### shared 세션 (후행)

| # | 작업 | 완료 기준 | 참조 |
|---|------|----------|------|
| 3-5 | 로컬 E2E 검증 (kafka-e2e-test.sh --all) | 구현 완료 서비스 PASS | WORKFLOW Step 7.7 |
| 3-6 | 코드 리뷰 피드백 반영 확인 + 추가 리뷰 | 크로스 서비스 영향도 리뷰 (스키마 호환성) | WORKFLOW Step 7.8~7.9 |
| 3-7 | PR 승인 및 main 머지 조율 | 완료된 서비스부터 순차 머지 | |

**종료 게이트**: Grafana 대시보드 가동 + terraform drift 없음 + 로컬 E2E PASS (구현 완료분)

---

### Day 4 (05-29) — 전체 E2E + 결과 정리 + 핸드오프

#### gitops 세션 (간단 정리)

| # | 작업 | 완료 기준 | 참조 |
|---|------|----------|------|
| 4-1 | Grafana 알림 규칙 설정 (에러율/P95/Kafka lag) | 알림 테스트 1회 발동 확인 | TASK Step 11 선행 |
| 4-2 | 배포 검증 결과 리포트 작성 | Step 8 결과 문서화 | WORKFLOW Step 8.10 |

#### shared 세션 (메인)

| # | 작업 | 완료 기준 | 참조 |
|---|------|----------|------|
| 4-3 | 전체 E2E 실행 (--full: 정상+에러+멀티테넌트) | 전 시나리오 PASS | WORKFLOW Step 7.8 |
| 4-4 | dev 환경 EKS E2E 검증 | EKS에서 이벤트 흐름 확인 | |
| 4-5 | E2E 테스트 결과 리포트 작성 | 미해결 이슈 목록화 + 우선순위 | WORKFLOW Step 7.10 |
| 4-6 | HANDOFF_HUB + HANDOFF_SHARED 갱신 → W4 인수인계 | 허브-스포크 정합성 ✅ | SESSION_CLOSE_CHECKLIST |
| 4-7 | WORKFLOW Step 7+8 Status → Done 갱신 | | |

**종료 게이트**: 전체 E2E PASS + 결과 리포트 + W4 핸드오프 문서 완성

---

## 5. 크리티컬 패스

```
terraform apply (1-1)
    │
    ├─→ MSK 토픽 확인 (1-3) ─→ 팀원 Kafka 구현 착수 (1-10)
    │                              │
    │                              └─→ 팀원 PR 생성 (Day 2 기한)
    │                                      │
    │                                      ├─→ 코드 리뷰 (2-9, 3-6)
    │                                      │       │
    │                                      │       └─→ PR 머지 (3-7)
    │                                      │               │
    │                                      │               └─→ 전체 E2E (4-3, 4-4)
    │                                      │
    │                                      └─→ 로컬 E2E (3-5)
    │
    ├─→ Dev 5/5 확인 (1-5) ─→ Staging sync (2-2) ─→ Staging 5/5 (2-4)
    │
    └─→ kube-prometheus-stack (2-5) ─→ ServiceMonitor (3-1) ─→ Grafana (3-2)
```

가장 긴 경로: terraform apply → 팀원 PR → 코드 리뷰 → 머지 → 전체 E2E (Day 1~4 전 구간)

---

## 6. 블로커 + 리스크

### 블로커

| 블로커 | 영향 범위 | 감지 시점 | 완화 전략 |
|--------|----------|----------|----------|
| terraform apply 실패 | 전체 Day 1 gitops + 이후 전부 | Day 1 시작 즉시 | W2에서 destroy/apply 반복 경험 있음. shared 세션은 로컬 Docker Compose 기반 독립 진행 가능 |
| platform-svc staging 프로필 미해결 | Staging 5/5 불가 | Day 2 (2-1) | application-staging.yml 추가만 필요 — 앱 레포 PR 1건 |
| 팀원 PR 미도착 (05-27 기한) | Day 3 E2E 검증 불가 | Day 2 종료 시점 | 미도착 서비스는 기존 E2E 샘플 데이터로 부분 검증. Day 3~4에 도착분부터 순차 E2E |
| MSK 브로커 주소 변경 | gitops ConfigMap 갱신 필요 | Day 1 (1-3) | PR #42 패턴 적용. ConfigMap patch → ArgoCD sync |
| Observability 설치 실패 | Day 3 ServiceMonitor/Grafana 밀림 | Day 2 (2-5) | 독립 작업. 트랙 1, 3에 영향 없음. Day 3으로 이월 후 state 정리와 병렬 시도 |

### 리스크 매트릭스

| 리스크 | 확률 | 영향 | 대응 |
|--------|:----:|:----:|------|
| EKS SG 수동 추가 누락 | 중 | 높음 | Day 1 runbook에 SG 확인 단계 포함 (D-026 재현 방지) |
| 팀원 Kafka 구현 품질 이슈 | 중 | 중 | TEAM_CHECKLIST_W3에 application.yml 예시 포함 완료. 스키마 호환성 최우선 체크 |
| E2E 테스트 환경 차이 (로컬 vs EKS) | 낮음 | 중 | Day 3 로컬 PASS 후 Day 4 EKS 검증으로 이중 확인 |
| 4영업일 시간 부족 | 중 | 중 | 드롭 우선순위 적용 |

### 드롭 우선순위 (시간 부족 시)

```
절대 보호: 트랙 1 (인프라+Staging) + 트랙 3 (Kafka E2E+리뷰)
1차 드롭: 트랙 4 (terraform state 정리) → W4 Day 1으로 이월
2차 드롭: 트랙 2 (Observability) → Grafana 대시보드만 W4로 이월, 설치는 유지
```

---

## 7. WORKFLOW Step 매핑

| 작업 ID | 작업 | WORKFLOW Step |
|---------|------|--------------|
| 1-1~1-6 | 인프라 기동 + 검증 | Step 8.1~8.2 |
| 1-7 | Security 1차 | Step 7.3 |
| 1-8~1-9 | 이벤트 흐름 매트릭스 + 리뷰 기준 | Step 7.2 |
| 2-1~2-4 | Staging sync + 검증 | Step 8.6~8.8 |
| 2-5 | kube-prometheus-stack | Step 8 범위 확장 (PRD FR-GO-303~307) |
| 2-6 | Security 2차 | Step 7.5 |
| 2-7~2-8 | E2E 시나리오 + 테스트 데이터 | Step 7.4~7.6 |
| 2-9, 3-6~3-7 | 코드 리뷰 + 머지 조율 | Step 7.9 |
| 3-1~3-2 | ServiceMonitor + Grafana | Step 8 범위 확장 |
| 3-3 | terraform state 정리 | HANDOFF_HUB #6 (WORKFLOW 외) |
| 3-4 | 롤백 테스트 | Step 8.9 |
| 3-5 | 로컬 E2E | Step 7.7~7.8 |
| 4-1 | Grafana 알림 | Step 8 범위 확장 |
| 4-2 | 배포 검증 리포트 | Step 8.10 |
| 4-3~4-4 | 전체 E2E + EKS E2E | Step 7.7~7.8 |
| 4-5 | E2E 결과 리포트 | Step 7.10 |
| 4-6~4-7 | 핸드오프 + Status 갱신 | Step 7.10 + 8.10 |

---

## 8. 산출물

| Day | 산출물 | 경로 | 레포 |
|-----|--------|------|------|
| 1 | 이벤트 흐름 매트릭스 | `docs/guides/EVENT_FLOW_MATRIX.md` | shared |
| 1 | 코드 리뷰 승인 기준 | TASK_team-lead.md Step 7 Instructions 반영 | shared |
| 2 | E2E 시나리오 문서 | `docs/guides/E2E_SCENARIOS_W3.md` | shared |
| 2 | Staging 검증 결과 | HANDOFF_SHARED.md 갱신 | shared |
| 3 | Grafana 대시보드 | Grafana UI (JSON export → gitops) | gitops |
| 3 | ServiceMonitor 매니페스트 5개 | `k8s/monitoring/` | gitops |
| 4 | E2E 테스트 결과 리포트 | `docs/reports/E2E_REPORT_W3.md` | shared |
| 4 | 배포 검증 리포트 | `docs/reports/DEPLOY_REPORT_W3.md` | shared |
| 4 | HANDOFF_HUB 갱신 (W3→W4) | `docs/project-management/HANDOFF_HUB.md` | shared |
| 4 | HANDOFF_SHARED 갱신 | `docs/project-management/HANDOFF_SHARED.md` | shared |
| 4 | WORKFLOW Step 7+8 Status Done | `docs/project-management/workflow/WORKFLOW_team-lead_W3.md` | shared |

---

## 9. W3 종료 게이트

```
□ Dev 5/5 Healthy (유지)
□ Staging 5/5 Healthy (신규 달성)
□ Prometheus + Grafana + Alertmanager Running
□ Grafana에서 5개 앱 메트릭 조회 가능
□ terraform plan → no unexpected drift
□ 전체 E2E (--full) PASS
□ 팀원 PR 머지 완료 (또는 잔여분 W4 이월 명시)
□ HANDOFF_HUB/SHARED 정합성 ✅
□ WORKFLOW Step 7+8 Status → Done
```
