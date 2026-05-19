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

### W3 (2026-05-26 ~ 05-30)

| Step | 내용 | 상태 | 시작일 | 완료일 | 비고 |
|------|------|------|--------|--------|------|
| Step 7 | Kafka E2E 검증 + 코드 리뷰 조율 | Not Started | — | — | |
| Step 8 | ArgoCD dev/staging 배포 검증 | Not Started | — | — | |

**W3 진행률**: 0/2 Steps 완료

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
- **진행 중**:
- **이슈**: CI 실패 — gradlew 누락 → wrapper 추가 후 Permission denied → chmod +x 로 해결
- **다음**: gitops 레포 Task 2 (terraform apply), Task 9 (PRD 검수), Task 8 (EKS provider swap)

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
- **진행 중**:
- **이슈**:
- **다음**:

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
