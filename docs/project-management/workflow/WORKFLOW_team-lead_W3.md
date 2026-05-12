# WORKFLOW: @team-lead — Week 3

> **Task 문서**: [TASK_team-lead.md](../task/TASK_team-lead.md)  
> **기간**: 2026-05-26 ~ 2026-05-30  
> **PRD**: [PRD_W3.md](../prd/PRD_W3.md)

---

## Step 7: 전체 통합 테스트 조율

### 1.1 TASK 시작
- [ ] Step Goal / Done When / Scope / Input 확인
- [ ] PRD_W3 해당 요구사항 확인 (서비스 간 통합 검증)
- [ ] Duration 산정 확인

### 1.2 요구사항 분석
- [ ] Kafka 이벤트 체인 E2E 시나리오 목록 도출
- [ ] 서비스 간 이벤트 발행/소비 매핑표 작성
- [ ] 코드 리뷰 승인 기준 정의 (PR 템플릿, 리뷰어 지정)
- [ ] Instructions 초안 → TASK 문서 반영

### 1.3 Security 1차 검토
- [ ] Kafka 토픽 ACL 설정 확인 (서비스별 발행/소비 권한)
- [ ] 이벤트 페이로드 민감정보 포함 여부 점검
- [ ] 서비스 간 인증 토큰 전파 방식 확인
- [ ] 결과 → TASK Constraints 반영

### 1.4 E2E 테스트 시나리오 설계
- [ ] gamification 이벤트 체인 시나리오 (카드 복습 → XP 적립 → 레벨업 → 배지 수여 → 알림)
- [ ] community 이벤트 체인 시나리오 (신고 접수 → 모더레이션 → 알림)
- [ ] card.review.due 이벤트 체인 시나리오 (스케줄러 → Kafka → 알림 발송)
- [ ] audit 이벤트 소비 시나리오 (각 서비스 이벤트 → audit_logs 적재)
- [ ] Duration(final) 갱신

### 1.5 Security 2차 검토
- [ ] E2E 테스트 환경 시크릿 분리 확인
- [ ] 테스트 데이터 민감정보 마스킹 확인
- [ ] 테스트 환경 네트워크 격리 확인
- [ ] 결과 → TASK Constraints 반영

### 1.6 테스트 데이터 준비
- [ ] E2E 테스트용 시드 데이터 정의 (사용자, 카드, 노트, 커뮤니티 게시글)
- [ ] Kafka 토픽 사전 생성 스크립트 작성
- [ ] 테스트 실행 순서 의존성 정리

### 1.7 E2E 테스트 구현 및 조율
- [ ] Kafka 이벤트 체인 E2E 테스트 작성 (Testcontainers)
- [ ] 서비스 간 이벤트 발행 → 소비 → 결과 검증 자동화
- [ ] 코드 리뷰 전 PR 승인 프로세스 적용
- [ ] 각 서비스 담당자 테스트 결과 취합

### 1.8 통합 테스트 실행 및 검증
- [ ] 전체 서비스 Docker Compose 기동 → E2E 테스트 실행
- [ ] Kafka 이벤트 전파 지연 시간 측정 (< 3초 기준)
- [ ] 이벤트 유실 여부 확인 (재시도 로직 검증)
- [ ] 실패 테스트 원인 분석 및 담당자 배정

### 1.9 코드 리뷰 조율
- [ ] 각 서비스 PR 리뷰 현황 취합
- [ ] 크로스 서비스 영향도 리뷰 (이벤트 스키마 호환성)
- [ ] PR 승인 및 main 브랜치 머지 조율

### 1.10 결과 정리
- [ ] E2E 테스트 결과 리포트 작성
- [ ] 미해결 이슈 목록화 및 우선순위 지정
- [ ] RULE Reference → TASK 반영

**Step 7 Status**: [ ] Not Started / [ ] In Progress / [ ] Done

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

**Step 8 Status**: [ ] Not Started / [ ] In Progress / [ ] Done
