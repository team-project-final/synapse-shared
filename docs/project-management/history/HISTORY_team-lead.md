# Work History: @team-lead

> **담당**: Gateway / 인프라 / 아키텍처  
> **관련 문서**: [SCOPE](../scope/SCOPE_team-lead.md) | [TASK](../task/TASK_team-lead.md) | [WORKFLOW](../workflow/WORKFLOW_team-lead_W1.md)

---

## 진행 상태 대시보드

### W1 (2026-05-12 ~ 05-16)

| Step | 내용 | 상태 | 시작일 | 완료일 | 비고 |
|------|------|------|--------|--------|------|
| Step 1 | AWS 인프라 프로비저닝 | Done | 05-12 | 05-16 | EKS/RDS/MSK/Redis/OpenSearch/ArgoCD 완료 |
| Step 2 | Docker Compose 4-서비스 구성 | Not Started | — | — | W2로 이월 |
| Step 3 | CI/CD 파이프라인 구성 | Done | 05-12 | 05-19 | mirror.yml + ci-java.yml (W1) + deploy.yml (W2) |

**W1 진행률**: 3/3 Steps 완료

### W2 (2026-05-19 ~ 05-23)

| Step | 내용 | 상태 | 시작일 | 완료일 | 비고 |
|------|------|------|--------|--------|------|
| Step 2 | Docker Compose 4-서비스 구성 | Done | 05-19 | 05-19 | 12 서비스 compose + .env.example + README |
| Step 3 | CI/CD 파이프라인 구성 (deploy.yml) | Done | 05-19 | 05-19 | deploy.yml 추가 완료 |
| Step 4 | Kafka 토픽 설계 | Done | 05-18 | 05-19 | Avro 스키마 4개 + 토픽 생성 스크립트 (PR #2 머지) |
| Step 5 | Schema Registry 구성 | Done | 05-18 | 05-19 | BACKWARD 호환성 정책 + Gradle wrapper CI 수정 |
| Step 6 | Gateway 라우팅 | Done | 05-19 | 05-19 | Boot 4.0.6 + Gateway 5.0.1, 프로그래밍 방식 라우트/Rate Limit/CORS |

**W2 진행률**: 5/5 Steps 완료

### W3 (2026-05-26 ~ 05-29, 4영업일)

| Step | 내용 | 상태 | 시작일 | 완료일 | 비고 |
|------|------|------|--------|--------|------|
| Step 7 | Kafka E2E 검증 + 코드 리뷰 조율 | In Progress | 05-22 | — | 계획 수립 완료, 팀원 구현 W3 진행 예정 |
| Step 8 | ArgoCD dev/staging 배포 검증 | In Progress | 05-22 | — | 5/5 Healthy 달성, staging sync 대기 |

**W3 진행률**: 0/2 Steps 완료 (계획 수립 + 선행 조건 확보 완료)

**05-22 달성 사항:**
- platform-svc / learning-ai 앱 코드 수정 완료 → **dev 5/5 Healthy 달성**
- W3 Day 1~4 일별 작업 계획 수립
- MSK 토픽 생성 절차 확인 (Day 1 gitops 세션 실행 예정)

### W4 (2026-06-02 ~ 06-06)

| Step | 내용 | 상태 | 시작일 | 완료일 | 비고 |
|------|------|------|--------|--------|------|
| Step 9 | E2E 테스트 시나리오 정의/조율 | Not Started | — | — | |
| Step 10 | SLA 성능 검증 | Not Started | — | — | |
| Step 11 | Staging 최종 배포 + 모니터링 | Not Started | — | — | |
| Step 12 | 발표 자료 + 시연 리허설 | Not Started | — | — | |

**W4 진행률**: 0/4 Steps 완료

---

## 작업 로그

### W1 (2026-05-12 ~ 05-16)

#### 2026-05-12 (월)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-13 (화)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-14 (수)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-15 (목)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-16 (금)
- **완료**:
- **진행 중**:
- **이슈**:
- **주간 요약**:

### W2 (2026-05-19 ~ 05-23)

#### 2026-05-19 (월)
- **완료**:
  - **[Step 2]** Docker Compose 전체 로컬 환경 구성 (12 서비스: postgres, redis, zookeeper, kafka, schema-registry, opensearch, kafka-init, platform/engagement/knowledge/learning-card/learning-ai)
  - **[Step 2]** .env.example 환경변수 템플릿 + README Quick Start 가이드
  - **[Step 2]** 인프라 healthcheck 전체 동작 확인 (Kafka 토픽 5개 자동 생성, Schema Registry BACKWARD 설정)
  - **[Step 3]** deploy.yml 추가 (ECR push + gitops tag update) — mirror.yml/ci-java.yml은 W1에 이미 완료
  - **[Step 6]** Spring Cloud Gateway 구현 완료 (synapse-gateway 레포)
    - Boot 4.0.6 + Cloud 2025.1.1 + Gateway 5.0.1
    - 프로그래밍 방식 라우트 (Boot 4.0.6 YAML 라우트 버그 대응)
    - Rate Limit: RedisRateLimiter(1, 60) IP 기반 — 429 at #64 확인
    - CORS: CorsWebFilter (localhost:3000/8080)
    - docker-compose.yml gateway stub → 실제 빌드 이미지 교체
  - **[HISTORY]** 대시보드 Step 번호/상태 불일치 정정 (W1~W4 전체)
  - Avro 스키마 4개 작성: NoteCreated, NoteUpdated, ReviewCompleted, CardsGenerated
  - MSK 토픽 생성 스크립트 `scripts/create-kafka-topics.sh`
  - Gradle 8.8 wrapper 추가 (CI 빌드 실패 수정)
  - `.gitignore` 순서 수정 (`!gradle-wrapper.jar` 예외가 `*.jar` 뒤로)
  - `gradlew` 실행 권한 추가
  - Schema Registry BACKWARD 호환성 정책 검증
  - PR #2 (`feat/w2-kafka-schemas`) CI 통과 및 main 머지
- **진행 중**: —
- **이슈**:
  - CI gradlew 누락 → wrapper 추가 후 Permission denied → chmod +x 로 해결
  - Spring Boot 4.0.6 + Gateway 5.0.1에서 YAML routes 미로드 버그 → 프로그래밍 방식으로 전환
  - YAML globalcors 미동작 → CorsWebFilter 빈으로 전환
  - Gradle 8.14+ 필요 (Boot 4.0.6 요구사항)
  - Dockerfile alpine에서 gradlew CRLF 문제 → dos2unix + bash 추가
  - ECR synapse-gateway 레포지토리 미존재 → aws ecr create-repository로 생성
- **다음**: W3 Step 7 (Kafka E2E 검증), Step 8 (ArgoCD dev/staging 배포 검증)

**(오후 — gitops 레포 작업)**:
- **완료**:
  - terraform apply: 기존 인프라(다른 PC) 확인, 중복 생성분 24개 리소스 destroy 완료
  - EKS provider swap: ExternalSecret → aws-secrets-manager, 이미지 → ECR, ClusterSecretStore 매니페스트 추가
  - PRD W2 검수: FR-GO-201/205/206 완료, 203/204 매니페스트 완료
  - gitops 프로젝트 관리 문서 갱신 (TASK/WORKFLOW/HISTORY/HANDOFF)
  - gitops PR #21 생성 (`feat/w2-dev-deploy`)
  - shared 프로젝트 관리 문서 갱신
- **이슈**: terraform state가 새 bucket이라 기존 인프라 인식 못함 → 중복 리소스 생성 사고 → 즉시 destroy로 정리

#### 2026-05-20 (화)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-21 (수)
- **완료**:
  - **[gitops 8차]** terraform re-apply 인프라 재기동
  - **[gitops 8차]** EKS managed node group SG 문제 해결 — eks-cluster-sg-*가 terraform eks_nodes SG와 다른 문제 → 4개 인프라 SG에 수동 추가
  - **[gitops 8차]** liveness probe initialDelaySeconds 30s → 90s (gitops PR #35)
  - **[gitops 8차]** 3/5 서비스 Healthy: engagement-svc, knowledge-svc, learning-card
  - **[gitops 8차]** staging overlay 5개 서비스 생성 + ApplicationSet (gitops PR #34)
  - **[gitops 8차]** ExternalSecret dev 5/5 SecretSynced + ClusterSecretStore Valid
  - **[gitops 8차]** ESO IRSA 설정 완료 (role: synapse-dev-eso-role)
  - **[shared]** E2E 테스트 인프라 선제 준비 (PR #5 머지)
  - **[shared]** 에러/멀티테넌트 샘플, DB 시드 V004/V005, 검증 스크립트 3개
  - **[shared]** synapse-shared 브랜치 정리 (2개 삭제)
  - **[shared]** 핸드오프 + 가이드 문서 현행화
- **이슈**:
  - platform-svc: DB 기동 후 `mfa_credentials` 테이블 미존재 → Flyway migration 또는 ddl-auto 수정 필요 (앱 레벨)
  - learning-ai: Python uvicorn restart 반복 → 서비스 레포 코드 레벨 문제 (앱 레벨)
- **다음**: platform-svc/learning-ai 앱 코드 수정 → 5/5 Healthy 달성 → dev 환경 검증 스크립트 실행

#### 2026-05-22 (목)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-23 (금)
- **완료**:
- **진행 중**:
- **이슈**:
- **주간 요약**:

### W3 (2026-05-26 ~ 05-30)

#### 2026-05-26 (월)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-27 (화)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-28 (수)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-29 (목)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-30 (금)
- **완료**:
- **진행 중**:
- **이슈**:
- **주간 요약**:

### W4 (2026-06-02 ~ 06-06)

#### 2026-06-02 (월)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-06-03 (화)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-06-04 (수)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-06-05 (목)
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-06-06 (금)
- **완료**:
- **진행 중**:
- **이슈**:
- **주간 요약**:

---

## 변경 이력

| 날짜 | 변경 사항 |
|------|-----------|
| 2026-05-19 | W2 Step 4-5 완료 + gitops EKS provider swap + PRD 검수 + 문서 갱신 |
| 2026-05-11 | W2/W3/W4 대시보드 및 로그 템플릿 추가 |
| 2026-05-11 | 초기 템플릿 생성 |
