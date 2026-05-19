# TASK: @team-lead

> **담당 서비스**: Gateway / 인프라 / 아키텍처  
> **GitHub Repository**: [syn](https://github.com/team-project-final/syn) · [synapse-shared](https://github.com/team-project-final/synapse-shared) · [synapse-mirror](https://github.com/team-project-final/synapse-mirror) · [synapse-gitops](https://github.com/team-project-final/synapse-gitops)  
> **주차**: W1 (2026-05-12 ~ 2026-05-16)  
> **관련 문서**: [SCOPE](../scope/SCOPE_team-lead.md) | [PRD_W1](../prd/PRD_W1.md) | [WORKFLOW](../workflow/WORKFLOW_team-lead_W1.md) | [HISTORY](../history/HISTORY_team-lead.md)

---

## Step 1: AWS 인프라 프로비저닝

- **Step Goal**: 팀장이 AWS 인프라(EKS, RDS, MSK, ElastiCache, OpenSearch)와 ArgoCD를 프로비저닝하여 4-서비스 배포 기반을 확보한다.
- **Done When**:
  - [x] EKS 클러스터 정상 가동 (kubectl get nodes → Ready)
  - [x] RDS PostgreSQL 16 인스턴스 접속 가능
  - [x] MSK(Kafka) 클러스터 브로커 접속 가능
  - [x] ElastiCache(Redis 7) 접속 가능
  - [x] OpenSearch 도메인 접속 가능
  - [x] ArgoCD 대시보드 접근 가능
- **Scope**:
  - In Scope:
    - EKS 클러스터 생성 (3 node)
    - RDS PostgreSQL 16 (db.t3.medium)
    - MSK Kafka 3.x (3 broker)
    - ElastiCache Redis 7 (cache.t3.micro)
    - OpenSearch 8.x (1 node dev)
    - ArgoCD 설치 + ApplicationSet
  - Out of Scope:
    - Production 규모 인프라 (dev 환경만)
    - 모니터링 대시보드 (W3)
    - 비용 최적화
- **Input**: AWS 계정 정보, VPC 설계도, 09_Git_규칙_정의서 §C1
- **Instructions**:
  1. EKS 클러스터 생성 (eksctl 또는 Terraform)
  2. RDS PostgreSQL 인스턴스 생성 + 보안 그룹 설정
  3. MSK 클러스터 생성 + Schema Registry 설정
  4. ElastiCache Redis 클러스터 생성
  5. OpenSearch 도메인 생성 + nori 플러그인
  6. ArgoCD 설치 + ApplicationSet(5서비스×3환경) 구성
  7. 접속 테스트 및 팀원 접근 권한 부여
- **Output Format**: 인프라 구성도 + 접속 정보 문서 (Notion 또는 .env.example 업데이트)
- **Constraints**:
  - dev 환경 전용 (최소 사양)
  - VPC 내부 통신만 허용 (퍼블릭 접근 제한)
  - 비용: 월 $200 이내
- **Duration**: 2일
- **RULE Reference**: wiki 14_배포_가이드 §2, wiki 10_환경_설정_템플릿
- **Assignee**: @team-lead
- **Reviewer**: —

**Status**: [ ] Not Started / [ ] In Progress / [ ] Done

---

## Step 2: Docker Compose 4-서비스 구성

- **Step Goal**: 팀장이 Docker Compose로 4개 서비스와 Schema Registry를 포함한 전체 로컬 개발 환경을 한 번에 실행할 수 있다.
- **Done When**:
  - [x] `docker compose up` → 4-서비스 Health OK (< 2분)
  - [x] Schema Registry 접속 (http://localhost:8086)
  - [x] PostgreSQL + Redis + Kafka + ES 접속 가능
  - [x] 팀원 온보딩 문서에 실행 방법 기재
- **Scope**:
  - In Scope:
    - docker-compose.yml (4-서비스 + infra)
    - .env.example 업데이트
    - Schema Registry 컨테이너
    - Health check 설정
  - Out of Scope:
    - Production Docker 이미지 최적화
    - K8s Helm Chart (별도 관리)
- **Input**: 각 서비스 Dockerfile, .env.example, Schema Registry 설정
- **Instructions**:
  1. docker-compose.yml 작성 (services: platform, engagement, knowledge, learning-card, learning-ai, postgres, redis, kafka, zookeeper, schema-registry, elasticsearch)
  2. 각 서비스 health check 설정 (depends_on + healthcheck)
  3. .env.example에 전체 환경 변수 정리
  4. README에 실행 방법 문서화
  5. 팀원 로컬 테스트
- **Output Format**: `docker-compose.yml` + `.env.example` + README 섹션
- **Constraints**:
  - 단일 `docker compose up`으로 전체 실행
  - 메모리 8GB 환경에서 동작
  - Apple Silicon(ARM) 호환
- **Duration**: 1일
- **RULE Reference**: wiki 10_환경_설정_템플릿
- **Assignee**: @team-lead
- **Reviewer**: —

**Status**: [ ] Not Started / [ ] In Progress / [x] Done

---

## Step 3: CI/CD 파이프라인 구성

- **Step Goal**: 팀장이 GitHub Actions CI/CD 파이프라인(mirror, CI, deploy)을 구성하여 main push 시 자동 빌드와 dev 환경 배포가 동작한다.
- **Done When**:
  - [x] mirror.yml: 소스 레포 → 미러 레포 동기화 동작
  - [x] ci.yml: PR → 빌드 + 테스트 + lint 동작
  - [x] deploy.yml: main push → ECR 이미지 푸시 → ArgoCD dev 동기화
  - [x] 파이프라인 문서화
- **Scope**:
  - In Scope:
    - mirror.yml (소스 → 미러 동기화)
    - ci.yml (빌드 + 테스트 + Modulith verify)
    - deploy.yml (ECR push + ArgoCD image tag 업데이트)
    - GitHub Secrets 설정
  - Out of Scope:
    - staging/prod 배포 (수동 승인 — W3)
    - 성능 테스트 CI
    - Canary/Blue-Green 배포
- **Input**: GitHub 레포 구조, ECR 레지스트리, ArgoCD API
- **Instructions**:
  1. mirror.yml 작성 (on: push main → mirror sync)
  2. ci.yml 작성 (on: PR → gradle build + test + modulith verify)
  3. deploy.yml 작성 (on: push main → docker build → ECR push → gitops image tag patch)
  4. GitHub Secrets 설정 (AWS credentials, ECR URL, ArgoCD token)
  5. 전체 플로우 테스트 (dummy commit → 파이프라인 동작 확인)
- **Output Format**: `.github/workflows/mirror.yml`, `ci.yml`, `deploy.yml`
- **Constraints**:
  - dev 환경만 자동 배포 (autoSync: true)
  - staging/prod는 수동 승인 (autoSync: false)
  - CI 실행 시간 < 5분
- **Duration**: 2일
- **RULE Reference**: wiki 09_Git_규칙_정의서 §B3, wiki 14_배포_가이드
- **Assignee**: @team-lead
- **Reviewer**: —

**Status**: [ ] Not Started / [ ] In Progress / [x] Done

---

## W2 (2026-05-19 ~ 2026-05-23)

---

## Step 4: Kafka 도메인별 토픽 설계 및 생성

- **Step Name**: Kafka 토픽 설계/생성
- **Step Goal**: 팀장이 도메인별 Kafka 토픽을 설계하고 Kafka 클러스터에 생성한다.
- **Done When**:
  - [x] 도메인별 Kafka 토픽 네이밍 규칙 정의 완료 (`{service}.{domain}.{event}-v1`)
  - [x] 4개 서비스 도메인에 필요한 토픽 목록 확정 (5개 토픽)
  - [ ] MSK 클러스터에 전체 토픽 생성 완료 — 인프라 재생성 후
  - [x] 토픽 파티션/복제 설정 확인 (`scripts/create-kafka-topics.sh`)
  - [x] 로컬 Docker Compose Kafka에도 동일 토픽 반영 (`kafka-init` 서비스)
- **Scope**:
  - In Scope:
    - 도메인별 토픽 설계 (platform, engagement, knowledge, learning)
    - 토픽 네이밍 컨벤션 정의
    - MSK 클러스터 토픽 생성 (kafka-topics.sh)
    - Docker Compose Kafka 토픽 초기화 스크립트
    - 토픽 설정 (파티션 수, retention, replication)
  - Out of Scope:
    - 이벤트 스키마 정의 (Step 5에서 처리)
    - Consumer Group 설정
    - Kafka Streams / KSQL
- **Input**: 03_아키텍처_정의서 §이벤트 설계, 각 서비스 SCOPE 문서, MSK 접속 정보
- **Instructions**:
  1. 도메인별 이벤트 목록 정리 (platform: auth.*, engagement: gamification.*, knowledge: note.*, learning: card.*)
  2. 토픽 네이밍 규칙 확정 ({domain}.{entity}.{action})
  3. 토픽별 파티션 수/retention 설정 결정
  4. MSK 클러스터에 토픽 생성
  5. Docker Compose Kafka 초기화 스크립트 작성
  6. 토픽 생성 확인 (kafka-topics.sh --list)
- **Output Format**: 토픽 목록 문서 + Kafka 초기화 스크립트
- **Constraints**:
  - 토픽 네이밍: kebab-case ({domain}.{entity}.{action})
  - 파티션: dev 환경 3개, retention: 7일
  - 토픽 수 50개 이하
- **Duration**: 1일
- **RULE Reference**: wiki 03_아키텍처_정의서 §이벤트 설계, wiki 10_환경_설정_템플릿
- **Assignee**: @team-lead
- **Reviewer**: —

**Status**: [ ] Not Started / [ ] In Progress / [x] Done (토픽 설계 + 생성 스크립트 완료, MSK 반영은 인프라 재생성 후)

---

## Step 5: Schema Registry BACKWARD 호환성 정책 설정

- **Step Name**: Schema Registry 호환성 정책
- **Step Goal**: 팀장이 Schema Registry에 BACKWARD 호환성 정책을 글로벌로 강제하여 비호환 스키마 등록을 방지한다.
- **Done When**:
  - [x] Schema Registry 글로벌 호환성 모드 BACKWARD 설정 완료 (Docker Compose)
  - [x] 비호환 스키마 등록 시도 시 거부 확인 (검증 완료)
  - [x] 호환 스키마 등록 정상 동작 확인 (검증 완료)
  - [x] 팀원에게 스키마 등록 가이드 공유 (`docs/SCHEMA_EVOLUTION.md`)
- **Scope**:
  - In Scope:
    - Schema Registry 글로벌 호환성 모드 설정 (BACKWARD)
    - 호환성 검증 테스트 (호환/비호환 시나리오)
    - 스키마 등록 가이드 작성
    - Docker Compose Schema Registry 설정 반영
  - Out of Scope:
    - 개별 서비스 Avro 스키마 작성 (각 서비스 담당)
    - FORWARD/FULL 호환성 모드
    - Schema Registry UI
- **Input**: Schema Registry 접속 정보, Avro 스키마 문서
- **Instructions**:
  1. Schema Registry 글로벌 호환성 모드 설정 (`PUT /config` → BACKWARD)
  2. 테스트용 Avro 스키마 등록
  3. 비호환 스키마 등록 시도 → 거부 확인
  4. 호환 스키마 (필드 추가 + default) 등록 → 성공 확인
  5. Docker Compose Schema Registry에 동일 설정 반영
  6. 팀원용 스키마 등록/검증 가이드 작성
- **Output Format**: Schema Registry 설정 문서 + 스키마 등록 가이드
- **Constraints**:
  - 글로벌 호환성: BACKWARD (필수)
  - 스키마 포맷: Avro
  - 새 필드 추가 시 default 값 필수
- **Duration**: 1일
- **RULE Reference**: wiki 03_아키텍처_정의서 §이벤트 설계, wiki 18_기술_스택_정의서 §Kafka
- **Assignee**: @team-lead
- **Reviewer**: —

**Status**: [ ] Not Started / [ ] In Progress / [x] Done (BACKWARD 정책 설정 + 검증 완료)

---

## Step 6: Spring Cloud Gateway 라우팅 및 Rate Limit 설정

- **Step Name**: Gateway 라우팅/Rate Limit
- **Step Goal**: 팀장이 Spring Cloud Gateway에서 4개 서비스로의 라우팅과 Rate Limit을 설정한다.
- **Done When**:
  - [x] Gateway → platform-svc 라우팅 동작
  - [x] Gateway → engagement-svc 라우팅 동작
  - [x] Gateway → knowledge-svc 라우팅 동작
  - [x] Gateway → learning-svc 라우팅 동작
  - [x] Rate Limit 설정 적용 (Redis 기반)
  - [x] Rate Limit 초과 시 429 응답 확인
- **Scope**:
  - In Scope:
    - Spring Cloud Gateway 프로젝트 설정
    - 4개 서비스 라우팅 규칙 (path prefix 기반)
    - Redis 기반 Rate Limit (RequestRateLimiter)
    - CORS 설정
    - Health check 엔드포인트
  - Out of Scope:
    - JWT 검증 필터 (Step 7 이후)
    - Circuit Breaker (W3)
    - WebSocket 프록시
- **Input**: 각 서비스 API 경로 목록, Redis 접속 정보, 03_아키텍처_정의서 §Gateway
- **Instructions**:
  1. Spring Cloud Gateway 프로젝트 생성 (또는 기존 프로젝트에 설정)
  2. application.yml에 4개 서비스 라우팅 규칙 작성
  3. Redis 기반 RequestRateLimiter 설정 (분당 60회)
  4. CORS 설정 (허용 도메인, 메서드, 헤더)
  5. Health check 엔드포인트 추가 (/actuator/health)
  6. 라우팅 테스트 (각 서비스 API 호출 확인)
  7. Rate Limit 테스트 (초과 시 429 확인)
- **Output Format**: Gateway 설정 파일 + 라우팅 문서
- **Constraints**:
  - Rate Limit: 분당 60회 (사용자별, Redis key)
  - 라우팅: /api/platform/**, /api/engagement/**, /api/knowledge/**, /api/learning/**
  - 응답 타임아웃: 30초
- **Duration**: 1일
- **RULE Reference**: wiki 03_아키텍처_정의서 §Gateway, wiki 18_기술_스택_정의서 §Spring Cloud Gateway
- **Assignee**: @team-lead
- **Reviewer**: —

**Status**: [ ] Not Started / [ ] In Progress / [x] Done

---

## W3 (2026-05-26 ~ 2026-05-29, 5/25 부처님오신날 제외 — Kafka 발행 모니터링)

---

## Step 7: 전체 서비스 간 Kafka 이벤트 E2E 검증 및 코드 리뷰 조율

- **Step Name**: Kafka 이벤트 E2E 검증/코드 리뷰
- **Step Goal**: 팀장이 전체 서비스 간 Kafka 이벤트 흐름을 E2E로 검증하고 코드 리뷰를 조율한다.
- **Done When**:
  - [ ] platform → engagement 이벤트 흐름 정상 동작
  - [ ] knowledge → learning 이벤트 흐름 정상 동작
  - [ ] learning → engagement 이벤트 흐름 정상 동작 (card.reviewed → XP)
  - [ ] engagement → platform 이벤트 흐름 정상 동작 (알림 트리거)
  - [ ] 전체 서비스 코드 리뷰 1차 완료
  - [ ] 리뷰 피드백 반영 확인
- **Scope**:
  - In Scope:
    - 서비스 간 Kafka 이벤트 흐름 E2E 테스트
    - 이벤트 스키마 호환성 검증
    - 4개 서비스 코드 리뷰 조율
    - 리뷰 피드백 트래킹 및 반영 확인
    - 이벤트 흐름 다이어그램 업데이트
  - Out of Scope:
    - 성능 테스트 (W4)
    - Dead Letter Queue 설정
    - 이벤트 소싱 패턴
- **Input**: 각 서비스 Kafka Producer/Consumer 코드, 토픽 목록, 스키마 정의
- **Instructions**:
  1. 서비스 간 이벤트 흐름 매트릭스 작성 (Producer → Topic → Consumer)
  2. Docker Compose로 전체 서비스 기동
  3. E2E 이벤트 흐름 테스트 (시나리오별)
  4. 이벤트 유실/지연 확인
  5. 코드 리뷰 일정 조율 (PR 단위)
  6. 리뷰 피드백 정리 및 반영 추적
  7. 이벤트 흐름 다이어그램 최종 업데이트
- **Output Format**: 이벤트 흐름 매트릭스 + E2E 테스트 결과 + 코드 리뷰 피드백 목록
- **Constraints**:
  - 이벤트 전달 보장: at-least-once
  - E2E 이벤트 전달 시간 < 5초
  - 코드 리뷰 피드백 48시간 내 반영
- **Duration**: 2일
- **RULE Reference**: wiki 03_아키텍처_정의서 §이벤트 설계, wiki 09_Git_규칙_정의서 §코드 리뷰
- **Assignee**: @team-lead
- **Reviewer**: —

**Status**: [ ] Not Started / [ ] In Progress / [ ] Done

---

## Step 8: ArgoCD dev/staging 환경 배포 검증

- **Step Name**: ArgoCD dev/staging 배포 검증
- **Step Goal**: 팀장이 ArgoCD로 dev/staging 환경 배포를 검증한다.
- **Done When**:
  - [ ] dev 환경 4개 서비스 ArgoCD Sync 정상
  - [ ] staging 환경 4개 서비스 ArgoCD Sync 정상
  - [ ] dev → staging 프로모션 워크플로우 동작
  - [ ] 배포 후 Health check 통과
  - [ ] Rollback 시나리오 테스트 완료
- **Scope**:
  - In Scope:
    - ArgoCD dev 환경 배포 검증
    - ArgoCD staging 환경 배포 검증
    - dev → staging 프로모션 프로세스
    - 배포 후 Health check 자동화
    - Rollback 테스트
  - Out of Scope:
    - Production 환경 배포
    - Canary/Blue-Green 배포 전략
    - 배포 알림 (Slack 연동)
- **Input**: ArgoCD ApplicationSet, Helm Chart, ECR 이미지, K8s manifest
- **Instructions**:
  1. dev 환경 ArgoCD Sync 상태 확인
  2. 4개 서비스 dev 환경 배포 테스트
  3. staging 환경 ApplicationSet 설정 (autoSync: false)
  4. dev → staging 이미지 태그 프로모션 테스트
  5. staging 수동 Sync + Health check 확인
  6. Rollback 시나리오 테스트 (이전 이미지로 복원)
  7. 배포 가이드 문서 업데이트
- **Output Format**: 배포 검증 체크리스트 + 배포 가이드 업데이트
- **Constraints**:
  - dev: autoSync true, staging: autoSync false (수동 승인)
  - Health check 통과 후 배포 완료 처리
  - Rollback은 3분 이내 완료
- **Duration**: 1일
- **RULE Reference**: wiki 14_배포_가이드, wiki 09_Git_규칙_정의서 §B3
- **Assignee**: @team-lead
- **Reviewer**: —

**Status**: [ ] Not Started / [ ] In Progress / [ ] Done

---

## W4 (2026-06-01 ~ 2026-06-05, 6/3 지방선거 제외 — 통합 테스트 조율 + dev/staging 배포)

---

## Step 9: 전체 E2E 테스트 시나리오 정의 및 실행 조율

- **Step Name**: E2E 테스트 시나리오 정의/조율
- **Step Goal**: 팀장이 전체 E2E 테스트 시나리오를 정의하고 실행을 조율한다.
- **Done When**:
  - [ ] 전체 E2E 테스트 시나리오 목록 확정
  - [ ] 서비스별 테스트 담당자 배정 완료
  - [ ] 크리티컬 패스 E2E 시나리오 통과
  - [ ] E2E 테스트 결과 리포트 작성
  - [ ] 실패 시나리오 이슈 등록 및 할당
- **Scope**:
  - In Scope:
    - E2E 테스트 시나리오 정의 (인증→기능→결제→알림)
    - 서비스별 테스트 담당자 배정
    - E2E 테스트 실행 조율
    - 테스트 결과 리포트 작성
    - 실패 시나리오 이슈 트래킹
  - Out of Scope:
    - 부하/성능 테스트 (Step 10)
    - 자동화 테스트 프레임워크 구축
    - 보안 테스트 (침투 테스트)
- **Input**: 각 서비스 API 목록, PRD, 이벤트 흐름 매트릭스
- **Instructions**:
  1. 전체 E2E 시나리오 목록 작성 (회원가입→로그인→노트생성→복습→XP→알림)
  2. 크리티컬 패스 식별 및 우선순위 지정
  3. 서비스별 테스트 담당자 배정
  4. E2E 테스트 실행 일정 조율
  5. 테스트 실행 및 결과 수집
  6. 실패 시나리오 이슈 등록 (GitHub Issues)
  7. E2E 테스트 결과 리포트 작성
- **Output Format**: E2E 테스트 시나리오 문서 + 테스트 결과 리포트
- **Constraints**:
  - 크리티컬 패스 100% 통과 필수
  - 테스트 환경: staging
  - 테스트 데이터 초기화 후 실행
- **Duration**: 1일
- **RULE Reference**: wiki 03_아키텍처_정의서 §테스트 전략, wiki 09_Git_규칙_정의서 §이슈 관리
- **Assignee**: @team-lead
- **Reviewer**: —

**Status**: [ ] Not Started / [ ] In Progress / [ ] Done

---

## Step 10: 전체 서비스 SLA 성능 검증

- **Step Name**: SLA 성능 검증
- **Step Goal**: 팀장이 전체 서비스 성능이 SLA(API P95<200ms, Kafka<5s)를 만족하는지 검증한다.
- **Done When**:
  - [ ] API P95 응답시간 < 200ms 확인
  - [ ] Kafka 이벤트 전달 지연 < 5초 확인
  - [ ] 동시 사용자 100명 기준 성능 유지 확인
  - [ ] 성능 병목 지점 식별 및 개선 방안 도출
  - [ ] 성능 테스트 리포트 작성
- **Scope**:
  - In Scope:
    - API 성능 테스트 (P50/P95/P99 응답시간)
    - Kafka 이벤트 전달 지연 측정
    - 동시 사용자 부하 테스트
    - 성능 병목 분석
    - 성능 테스트 리포트
  - Out of Scope:
    - Production 규모 부하 테스트
    - 인프라 스케일링 (Auto Scaling)
    - CDN/캐시 최적화
- **Input**: staging 환경 접속 정보, API 목록, SLA 기준
- **Instructions**:
  1. 성능 테스트 도구 설정 (k6 또는 JMeter)
  2. API 엔드포인트별 성능 테스트 시나리오 작성
  3. Kafka 이벤트 전달 지연 측정 스크립트 작성
  4. 동시 사용자 부하 테스트 실행 (10/50/100명)
  5. 성능 메트릭 수집 및 분석
  6. 병목 지점 식별 (DB 쿼리, 네트워크, 메모리)
  7. 성능 테스트 리포트 작성
- **Output Format**: 성능 테스트 리포트 (메트릭 + 그래프 + 개선 방안)
- **Constraints**:
  - SLA: API P95 < 200ms, Kafka 이벤트 전달 < 5초
  - 테스트 환경: staging (dev 환경 스펙 기준)
  - 최소 3회 반복 측정 후 평균
- **Duration**: 1일
- **RULE Reference**: wiki 03_아키텍처_정의서 §성능 요구사항, wiki 17_스케줄_정의서
- **Assignee**: @team-lead
- **Reviewer**: —

**Status**: [ ] Not Started / [ ] In Progress / [ ] Done

---

## Step 11: Staging 최종 배포 및 모니터링 대시보드 가동

- **Step Name**: Staging 최종 배포/모니터링
- **Step Goal**: 팀장이 Staging 환경에 최종 배포하고 모니터링 대시보드를 가동한다.
- **Done When**:
  - [ ] Staging 환경 4개 서비스 최종 배포 완료
  - [ ] Grafana 모니터링 대시보드 구성 완료
  - [ ] 주요 메트릭 알림 설정 (에러율, 응답시간, Kafka lag)
  - [ ] 모니터링 대시보드 팀 공유
  - [ ] 운영 가이드 문서 작성
- **Scope**:
  - In Scope:
    - Staging 환경 최종 배포 (ArgoCD)
    - Grafana 대시보드 구성 (서비스별 메트릭)
    - 알림 설정 (Slack/이메일)
    - 모니터링 가이드 문서
    - 운영 체크리스트
  - Out of Scope:
    - Production 배포
    - APM 도구 (Datadog, New Relic)
    - 로그 중앙화 (ELK — 별도 태스크)
- **Input**: Staging 환경, Grafana 접속 정보, Prometheus 메트릭
- **Instructions**:
  1. Staging 환경 최종 이미지 배포 (ArgoCD Sync)
  2. 배포 후 전체 서비스 Health check 확인
  3. Grafana 대시보드 구성 (서비스별 CPU/메모리/응답시간/에러율)
  4. Kafka 메트릭 대시보드 구성 (lag, throughput, error)
  5. 알림 규칙 설정 (에러율 > 1%, P95 > 500ms, Kafka lag > 1000)
  6. 팀원에게 대시보드 접근 권한 부여 및 공유
  7. 운영 가이드 문서 작성
- **Output Format**: Grafana 대시보드 URL + 알림 설정 + 운영 가이드
- **Constraints**:
  - Grafana 대시보드 로딩 < 3초
  - 알림: 5분 이내 발송
  - 메트릭 보존: 30일
- **Duration**: 1일
- **RULE Reference**: wiki 14_배포_가이드, wiki 10_환경_설정_템플릿
- **Assignee**: @team-lead
- **Reviewer**: —

**Status**: [ ] Not Started / [ ] In Progress / [ ] Done

---

## Step 12: 최종 발표 자료 준비 + 시연 리허설

- **Step Goal**: 팀장이 최종 발표 자료를 준비하고 전체 팀과 시연 리허설을 1회 이상 수행한다.
- **Done When**:
  - [ ] 발표 슬라이드 작성 완료 (15~20슬라이드)
  - [ ] 데모 시나리오 스크립트 확정
  - [ ] 시연 환경 사전 점검 (네트워크, 테스트 데이터, 시드 계정)
  - [ ] 전체 팀 시연 리허설 1회 이상 수행 (W5 마지막 영업일 6/12 권장)
  - [ ] 리허설 회고 + 보완점 반영
- **Scope**:
  - In Scope:
    - 발표 슬라이드 (배경/문제/솔루션/아키텍처/시연/회고)
    - 데모 시나리오 스크립트 (5분 시연 흐름)
    - 시연 환경 사전 점검 체크리스트
    - 시연 리허설 진행
    - 회고 + 보완
  - Out of Scope:
    - Q&A 답변 자료 작성 (별도)
    - 영상 녹화
    - 발표 자료 인쇄
- **Input**: 전체 시스템, 17 스케줄 v3.0, 발표 슬라이드 템플릿, 시드 데이터
- **Instructions**:
  1. 발표 슬라이드 초안 작성 (15~20슬라이드)
  2. 데모 시나리오 스크립트 작성 (5분 시연 흐름)
  3. 시연 환경 사전 점검 (Staging, 네트워크, 시드 계정)
  4. 전체 팀과 시연 리허설 진행 (W5 마지막 영업일 6/12 권장)
  5. 리허설 회고 → 보완점 도출
  6. 슬라이드/스크립트 최종 보완
- **Output Format**: 발표 슬라이드 + 데모 스크립트 + 리허설 회고 노트
- **Constraints**:
  - 시연 시간: 5분 ± 1분
  - 슬라이드 수: 20장 이하
  - 리허설은 발표일(6/15) D-3 이전 완료
  - 코드 변경은 발표일 동결 (긴급 P0 hotfix만 허용)
- **Duration**: 1일
- **RULE Reference**: wiki 17_스케줄 §발표일 규칙
- **Assignee**: @team-lead
- **Reviewer**: —

**Status**: [ ] Not Started / [ ] In Progress / [ ] Done
