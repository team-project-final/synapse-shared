# WORKFLOW: @team-lead — Week 3

> **Task 문서**: [TASK_team-lead.md](../task/TASK_team-lead.md)  
> **기간**: 2026-05-26 (화) ~ 2026-05-29 (금) — 4영업일 (5/25 부처님오신날 제외)  
> **PRD**: [PRD_W3.md](../prd/PRD_W3.md)

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
- [ ] Kafka 토픽 ACL 설정 확인 (서비스별 발행/소비 권한) — Day 1 gitops 세션에서 확인
- [x] 이벤트 페이로드 민감정보 포함 여부 점검 → UserRegistered.email만 PII (EVENT_FLOW_MATRIX.md §4)
- [x] 서비스 간 인증 토큰 전파 방식 확인 → CloudEvent traceparent 기반 (TASK Constraints 반영)
- [x] 결과 → TASK Constraints 반영 (05-22 선행 준비)

### 1.4 E2E 테스트 시나리오 설계
- [x] gamification 이벤트 체인 시나리오 (카드 복습 → XP 적립 → 레벨업 → 배지 수여 → 알림) → E2E_SCENARIOS_W3.md S2
- [ ] community 이벤트 체인 시나리오 (신고 접수 → 모더레이션 → 알림) — W3 범위 외, W4 이월
- [x] card.review.due 이벤트 체인 시나리오 (스케줄러 → Kafka → 알림 발송) → E2E_SCENARIOS_W3.md S3 (샘플 추가 완료)
- [ ] audit 이벤트 소비 시나리오 (각 서비스 이벤트 → audit_logs 적재) — W4 범위
- [ ] Duration(final) 갱신

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
- [ ] 각 서비스 담당자 테스트 결과 취합 — 팀원 Kafka 산출물 PR 0/5로 취합 대상 미도착 (05-27 EOD 기준)

### 1.8 통합 테스트 실행 및 검증
- [~] 전체 서비스 Docker Compose 기동 → E2E 테스트 실행 — 인프라(zookeeper/kafka/schema-registry)만 기동, 앱 서비스 Kafka 구현 0건으로 미실행
- [ ] Kafka 이벤트 전파 지연 시간 측정 (< 3초 기준) — harness 총 29s(라운드트립), 이벤트 단위 측정은 서비스 구현 후
- [x] 이벤트 유실 여부 확인 — harness `--all` 5/5 + `--full` 13/13 round-trip 무유실 (재시도 로직 검증은 서비스 consumer 도착 후)
- [x] 실패 테스트 원인 분석 및 담당자 배정 — D-1(stale ZK znode)·D-2(샘플 line-split) 분석·해결 → `E2E_BASELINE_W3.md`

### 1.9 코드 리뷰 조율
- [ ] 각 서비스 PR 리뷰 현황 취합
- [ ] 크로스 서비스 영향도 리뷰 (이벤트 스키마 호환성)
- [ ] PR 승인 및 main 브랜치 머지 조율

### 1.10 결과 정리
- [ ] E2E 테스트 결과 리포트 작성
- [ ] 미해결 이슈 목록화 및 우선순위 지정
- [ ] RULE Reference → TASK 반영

**Step 7 Status**: [ ] Not Started / [x] In Progress / [ ] Done

---

## Step 8: ArgoCD dev/staging 배포 검증

### 1.1 TASK 시작
- [ ] Step Goal / Done When / Scope / Input 확인
- [ ] PRD_W3 해당 요구사항 확인 (배포 검증)
- [ ] Duration 산정 확인

### 1.2 요구사항 분석
- [ ] dev 환경 autoSync 설정 요건 분석
- [ ] staging 환경 수동 승인 배포 플로우 분석
- [ ] 배포 후 헬스체크 기준 정의
- [ ] Instructions 초안 → TASK 문서 반영

### 1.3 Security 1차 검토
- [ ] ArgoCD RBAC 설정 확인 (dev: 자동, staging: 승인 필요)
- [ ] 배포 시 시크릿 주입 방식 확인 (Sealed Secrets / External Secrets)
- [ ] 환경별 접근 권한 분리 확인
- [ ] 결과 → TASK Constraints 반영

### 1.4 배포 전략 설계
- [ ] dev 환경 ArgoCD autoSync 정책 설정
- [ ] staging 환경 수동 승인 워크플로우 설계
- [ ] 롤백 절차 정의 (자동/수동)
- [ ] Duration(final) 갱신

### 1.5 Security 2차 검토
- [ ] 환경별 환경변수/시크릿 분리 확인
- [ ] staging 배포 승인 권한자 지정
- [ ] 배포 이력 추적 (audit trail) 확인
- [ ] 결과 → TASK Constraints 반영

### 1.6 배포 설정 구현
- [ ] ArgoCD Application 매니페스트 갱신 (dev autoSync: true)
- [ ] staging Application 매니페스트 갱신 (syncPolicy: manual)
- [ ] 환경별 values.yaml 분리 확인

### 1.7 배포 실행
- [ ] dev 환경: main push → autoSync 자동 배포 확인
- [ ] staging 환경: 수동 Sync 버튼 → 배포 실행
- [ ] ECR 이미지 태그 일치 확인

### 1.8 배포 후 검증
- [ ] dev 환경 전체 서비스 Health OK 확인
- [ ] staging 환경 전체 서비스 Health OK 확인
- [ ] Kafka 연결 상태 확인 (각 서비스 consumer group lag = 0)
- [ ] RDS/Redis/OpenSearch 연결 상태 확인

### 1.9 배포 이슈 대응
- [ ] 배포 실패 시 롤백 절차 실행 및 검증
- [ ] 환경별 로그 수집 및 이슈 분석
- [ ] 배포 성공 기준 충족 여부 최종 확인

### 1.10 결과 정리
- [ ] 배포 검증 결과 리포트 작성
- [ ] staging 배포 승인 프로세스 문서화
- [ ] RULE Reference → TASK 반영

**Step 8 Status**: [ ] Not Started / [x] In Progress / [ ] Done
