# WORKFLOW: @team-lead — Week 3

> **Task 문서**: [TASK_team-lead.md](../task/TASK_team-lead.md)  
> **기간**: 2026-05-26 (화) ~ 2026-05-29 (금) — 4영업일 (5/25 부처님오신날 제외)  
> **PRD**: [PRD_W3.md](../prd/PRD_W3.md)

> ✅ **사후 정합(2026-06-08)**: 본 주차 미완 항목은 전수 검토 완료 — 대부분 W5 Day1 해소/결정 또는 W5 일정 추적중, 미추적 잔여 0건. → [SHARED_W1W4_INCOMPLETE_REVIEW](../../reports/SHARED_W1W4_INCOMPLETE_REVIEW.md)

---

## Step 7: 전체 통합 테스트 조율

### 1.1 TASK 시작
- [x] Step Goal / Done When / Scope / Input 확인
- [x] PRD_W3 해당 요구사항 확인 (서비스 간 통합 검증 — FR-TL-201)
- [x] Duration 산정 확인 (2일: Day 3~4)

### 1.2 요구사항 분석
- [x] Kafka 이벤트 체인 E2E 시나리오 목록 도출 → `docs/guides/E2E_SCENARIOS_W3.md`
- [x] 서비스 간 이벤트 발행/소비 매핑표 작성 → `docs/guides/EVENT_FLOW_MATRIX.md`
- [x] 코드 리뷰 승인 기준 정의 (PR 템플릿, 리뷰어 지정) → TASK Step 7 갱신 완료
- [x] Instructions 초안 → TASK 문서 반영 (05-22 선행 준비)

### 1.3 Security 1차 검토
- [~] Kafka 토픽 ACL/권한 확인 — **인증 모델(MSK IAM, ACL 미사용) + 서비스별 produce/consume 권한 매트릭스 확정** → `docs/guides/KAFKA_AUTH_MATRIX.md`. IAM Policy/IRSA 실적용·검증만 EKS window
- [x] 이벤트 페이로드 민감정보 포함 여부 점검 → UserRegistered.email만 PII (EVENT_FLOW_MATRIX.md §4)
- [x] 서비스 간 인증 토큰 전파 방식 확인 → CloudEvent traceparent 기반 (TASK Constraints 반영)
- [x] 결과 → TASK Constraints 반영 (05-22 선행 준비)

### 1.4 E2E 테스트 시나리오 설계
- [x] gamification 이벤트 체인 시나리오 (카드 복습 → XP 적립 → 레벨업 → 배지 수여 → 알림) → E2E_SCENARIOS_W3.md S2
- [~] community 이벤트 체인 시나리오 (신고 접수 → 모더레이션 → 알림) — 설계 선반영 완료(E2E_SCENARIOS_W3.md S5); 구현(engagement 알림 발행)·실행 W4
- [x] card.review.due 이벤트 체인 시나리오 (스케줄러 → Kafka → 알림 발송) → E2E_SCENARIOS_W3.md S3 (샘플 추가 완료)
- [~] audit 이벤트 소비 시나리오 (각 서비스 이벤트 → audit_logs 적재) — 설계 선반영 완료(E2E_SCENARIOS_W3.md S6); 현재 user-registered 단일 토픽, 추가 토픽 W4
- [x] Duration(final) 갱신 — 팀리드 설계·검증설계분 2일(Day 3~4) 완료; 배포 실행(§1.7~1.9)은 EKS 재기동 윈도 이월(별도)

### 1.5 Security 2차 검토
- [x] E2E 테스트 환경 시크릿 분리 확인 → 로컬 throwaway 스택, 테스트 리소스 실 시크릿 0건
- [x] 테스트 데이터 민감정보 마스킹 확인 → 샘플 email 전부 `@test.synapse.dev` 합성값 (운영 Consumer 로그 마스킹은 구현 시 권장)
- [x] 테스트 환경 네트워크 격리 확인 → 로컬 `synapse-net` bridge, EKS private endpoint + 네임스페이스 분리
- [x] 결과 → TASK Constraints 반영 (Step 7 "Security 2차 검토", 05-29)

### 1.6 테스트 데이터 준비
- [x] E2E 테스트용 시드 데이터 정의 (사용자, 카드, 노트, 커뮤니티 게시글) → `src/test/resources/seed/V001~V005`
- [x] Kafka 토픽 사전 생성 스크립트 작성 → `scripts/create-kafka-topics.sh` (5개 토픽)
- [x] 테스트 실행 순서 의존성 정리 → `docs/guides/E2E_SCENARIOS_W3.md`

### 1.7 E2E 테스트 구현 및 조율
- [x] Kafka 이벤트 체인 E2E 테스트 작성 (~~Testcontainers~~ → 로컬 shell harness `scripts/kafka-e2e-test.sh`로 대체, EKS destroy로 로컬 우선)
- [x] 서비스 간 이벤트 발행 → 소비 → 결과 검증 자동화 (**전송 경로 한정**: produce→consume + CloudEvent 페이로드 단위 round-trip. consumer 비즈니스 로직은 서비스 구현 도착 시 확장)
- [x] 코드 리뷰 전 PR 승인 프로세스 적용 → work-order 발행 + 코드 리뷰 승인 기준 (`W3_KAFKA_WORKORDER.md`, TASK Step 7)
- [~] 각 서비스 담당자 테스트 결과 취합 — **06-01 코드 실측(전체 레포 pull)**: platform 🟢(Avro+Outbox+notification/audit Consumer)·learning 🟢(Avro 소비+알림) dev 완성 / engagement 🟡(06-02: 스키마 비호환 해소·Producer Avro ✅ #13 CLOSED / Consumer 0건 잔여 → #15) / knowledge 🟡(06-02: NoteCreated/Updated Producer ✅ #32, 스키마 바이트동일 / dev→main 잔여 #26). 상세 [W4_KAFKA_WORKORDER §0.5](../../work-orders/W4_KAFKA_WORKORDER.md). 완전 취합은 main 머지 후

### 1.8 통합 테스트 실행 및 검증
- [x] 전체 서비스 Docker Compose 기동 → E2E 테스트 실행 — 인프라(zookeeper/kafka/schema-registry/kafka-init) 기동 + **`--avro` 라이브 8/8 PASSED**(8토픽 Avro 라운드트립 + subject 자동등록, 전역 BACKWARD). 앱 서비스 비즈니스 로직 E2E는 구현 도착 후(W4)
- [x] Kafka 이벤트 전파 지연 측정 (< 3초) — **로컬 `EndToEndLatency` (06-01, acks=1, 2토픽×1000건): avg 1.3ms, p50 1ms, p99 3~4ms, p99.9 ~40ms** → transport 전파 **NFR(<3초) 입증**. (기존 "총 29s"는 8토픽 순차+JVM부팅 포함 비대표). end-to-end 체인(복습→알림 <10초, NFR-401)은 서비스 consumer 후
- [x] 이벤트 유실 여부 확인 — harness `--all` 5/5 + `--full` 13/13 round-trip 무유실 (재시도 로직 검증은 서비스 consumer 도착 후)
- [x] 실패 테스트 원인 분석 및 담당자 배정 — D-1(stale ZK znode)·D-2(샘플 line-split) 분석·해결 → `E2E_BASELINE_W3.md`

### 1.9 코드 리뷰 조율
- [x] 각 서비스 PR 리뷰 현황 취합 — cross-repo 실측(05-29): learning main 머지 / platform·engagement dev / knowledge 미구현
- [x] 크로스 서비스 영향도 리뷰 (이벤트 스키마 호환성) — **스키마 패밀리 분기(D-002) 발견 → Avro 사수 결정 + 이벤트 계약 표준 수립**(`EVENT_CONTRACT_STANDARD.md`). cards-generated HTTP 드리프트 정정(D-001)
- [~] PR 승인 및 main 브랜치 머지 조율 — 계약 표준 이슈(#43/#13/#26 OPEN·#32 CLOSED). **06-01 재측정: 작업이 전부 dev 고립, 열린 PR 0건** → platform(#44)·learning(#35) **dev→main PR 유도**가 즉시 조율 대상

### 1.10 결과 정리
- [x] E2E 테스트 결과 리포트 작성 → `docs/reports/E2E_REPORT_W3.md` + 종료 게이트 `W3_EXIT_GATE.md`(미통과 충족 0/5)
- [x] 미해결 이슈 목록화 및 우선순위 지정 → `W4_KAFKA_WORKORDER.md`(knowledge P0·engagement P0·platform P1) + 서비스 이슈 4건
- [x] RULE Reference → TASK 반영 (Security 2차 Constraints 등)

**Step 7 Status**: [ ] Not Started / [ ] In Progress / [x] Done — 전송/계약 경로 완료, 서비스 Kafka 4종 origin/main 머지(W5 Day1 해소). 서비스 단위 E2E는 W5 Day2 추적. ([SHARED_W1W4_INCOMPLETE_REVIEW](../../reports/SHARED_W1W4_INCOMPLETE_REVIEW.md))

---

## Step 8: ArgoCD dev/staging 배포 검증

> **블로커 = `EKS destroy`(클러스터 없음), Kafka 무관.** 설계·정책·매니페스트(1.2~1.6, 1.10 일부)는 완료(`docs/reports/DEPLOY_REPORT_W3.md` §A~C). 실행·실검증(1.7~1.9)은 `terraform apply`(재기동) 후 가능. 서비스 배포·헬스OK는 Kafka 기능 구현과 독립(W2에 dev 5/5 Healthy 달성).

### 1.1 TASK 시작
- [x] Step Goal / Done When / Scope / Input 확인
- [x] PRD_W3 해당 요구사항 확인 (배포 검증)
- [x] Duration 산정 확인 (1일)

### 1.2 요구사항 분석 → DEPLOY_REPORT §A
- [x] dev 환경 autoSync 설정 요건 분석
- [x] staging 환경 수동 승인 배포 플로우 분석
- [x] 배포 후 헬스체크 기준 정의
- [x] Instructions 초안 → TASK 문서 반영

### 1.3 Security 1차 검토 → DEPLOY_REPORT §C
- [~] ArgoCD RBAC 설정 확인 (dev: 자동, staging: 승인 필요) — 정책 정의됨, 실제 RBAC 구성·확인은 재기동 후
- [x] 배포 시 시크릿 주입 방식 확인 — ExternalSecret + ClusterSecretStore(ESO IRSA), dev 5/5 SecretSynced
- [x] 환경별 접근 권한 분리 확인 — 네임스페이스 분리(synapse-dev / synapse-staging)
- [x] 결과 → TASK Constraints 반영

### 1.4 배포 전략 설계 → DEPLOY_REPORT §A·§B
- [x] dev 환경 ArgoCD autoSync 정책 설정 (automated, prune/selfHeal)
- [x] staging 환경 수동 승인 워크플로우 설계 (manual sync)
- [x] 롤백 절차 정의 (자동/수동) — §B 5단계, 목표 <3분
- [x] Duration(final) 갱신

### 1.5 Security 2차 검토 → DEPLOY_REPORT §C
- [x] 환경별 환경변수/시크릿 분리 확인
- [~] staging 배포 승인 권한자 지정 — @team-lead 지정, ArgoCD RBAC 명문화는 재기동 후(W4)
- [x] 배포 이력 추적 (audit trail) 확인 — ArgoCD app history + gitops 커밋 이력
- [x] 결과 → TASK Constraints 반영

### 1.6 배포 설정 구현 (gitops, 05-21 구성)
- [x] ArgoCD Application 매니페스트 갱신 (dev autoSync: true)
- [x] staging Application 매니페스트 갱신 (syncPolicy: manual) — staging overlay + ApplicationSet (gitops PR #34)
- [x] 환경별 values.yaml 분리 확인 — dev/staging overlay 분리

### 1.7 배포 실행 — ⛔ EKS destroy로 대기 (재기동 후)
> 실행 설계: [W3_DEPLOY_VERIFICATION_PLAYBOOK.md](../../guides/W3_DEPLOY_VERIFICATION_PLAYBOOK.md) §1.7 (turnkey 명령·기준)
- [ ] dev 환경: main push → autoSync 자동 배포 확인
- [ ] staging 환경: 수동 Sync 버튼 → 배포 실행
- [ ] ECR 이미지 태그 일치 확인

### 1.8 배포 후 검증 — ⛔ EKS destroy로 대기 (재기동 후)
> 실행 설계: [W3_DEPLOY_VERIFICATION_PLAYBOOK.md](../../guides/W3_DEPLOY_VERIFICATION_PLAYBOOK.md) §1.8 (Kafka lag은 W4 consumer 후)
- [ ] dev 환경 전체 서비스 Health OK 확인
- [ ] staging 환경 전체 서비스 Health OK 확인
- [ ] Kafka 연결 상태 확인 (consumer group lag = 0) — consumer 배포 필요(W4 Kafka 구현 후)
- [ ] RDS/Redis/Elasticsearch 연결 상태 확인

### 1.9 배포 이슈 대응 — ⛔ EKS destroy로 대기 (절차는 §B 정의됨)
> 실행 설계: [W3_DEPLOY_VERIFICATION_PLAYBOOK.md](../../guides/W3_DEPLOY_VERIFICATION_PLAYBOOK.md) §1.9 (DEPLOY_REPORT §B 롤백 <3분)
- [ ] 배포 실패 시 롤백 절차 실행 및 검증
- [ ] 환경별 로그 수집 및 이슈 분석
- [ ] 배포 성공 기준 충족 여부 최종 확인

### 1.10 결과 정리
- [x] 배포 검증 결과 리포트 작성 → `docs/reports/DEPLOY_REPORT_W3.md` (실행 검증 체크리스트는 재기동 후 채움)
- [x] staging 배포 승인 프로세스 문서화 → DEPLOY_REPORT §A·§C
- [x] RULE Reference → TASK 반영

> 표기: [x] 완료 / [~] 부분(정의 완료·실검증 재기동 후) / [ ] EKS 재기동 대기
> **Step 8 진행률**: 설계·정책·매니페스트 완료(1.1~1.6, 1.10). 실행·실검증(1.7~1.9)만 EKS 재기동(`terraform apply`) 대기 — **Kafka 완료와 무관**.

**Step 8 Status**: [ ] Not Started / [ ] In Progress / [x] Done — 배포 정책·매니페스트 완료, dev/staging 배포·검증·롤백은 W5 Day1 ALL PASS(dev16/staging20). ([SHARED_W1W4_INCOMPLETE_REVIEW](../../reports/SHARED_W1W4_INCOMPLETE_REVIEW.md))
