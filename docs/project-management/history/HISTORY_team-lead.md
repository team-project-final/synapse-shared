# Work History: @team-lead

> **담당**: Gateway / 인프라 / 아키텍처  
> **관련 문서**: [SCOPE](../scope/SCOPE_team-lead.md) | [TASK](../task/TASK_team-lead.md) | [WORKFLOW](../workflow/WORKFLOW_team-lead_W1.md)

---

## 진행 상태 대시보드

### W1 (2026-05-12 ~ 05-15, 4영업일)

| Step | 내용 | 상태 | 시작일 | 완료일 | 비고 |
|------|------|------|--------|--------|------|
| Step 1 | AWS 인프라 프로비저닝 | Done | 05-12 | 05-16 | EKS/RDS/MSK/Redis/OpenSearch/ArgoCD 완료 |
| Step 2 | Docker Compose 4-서비스 구성 | Not Started | — | — | W2로 이월 |
| Step 3 | CI/CD 파이프라인 구성 | Done | 05-12 | 05-19 | mirror.yml + ci-java.yml (W1) + deploy.yml (W2) |

**W1 진행률**: 3/3 Steps 완료

### W2 (2026-05-19 ~ 05-22, 4영업일)

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
| Step 7 | Kafka E2E 검증 + 코드 리뷰 조율 | In Progress | 05-22 | — | harness(--full 13/13, +`--avro`)·Security 2차·스키마 리뷰·E2E/게이트 리포트 완료. **이벤트 계약 표준(Avro/D-002) 수립 + 스키마·토픽·라이브러리 발행 정비 + 서비스 이슈 4건**. 서비스 단위 E2E는 Kafka 부분구현(learning main·platform/engagement dev·knowledge 미구현)으로 차단 |
| Step 8 | ArgoCD dev/staging 배포 검증 | In Progress | 05-22 | — | 배포 전략·승인·롤백 절차 정의 완료(DEPLOY_REPORT §A~C). 실배포 검증은 EKS destroy로 보류(재기동 후) |

**W3 진행률**: 0/2 Steps 완료 — shared 측 설계·전제·검증(harness/스키마/Security/리포트)은 완료, 그러나 **종료 게이트 미통과(1/5)**. 실행(서비스 E2E·배포)은 Kafka 부분구현(learning main / platform·engagement dev / knowledge 미구현) + EKS destroy로 W4 이월

**05-22 달성 사항:**
- platform-svc / learning-ai 앱 코드 수정 완료 → **dev 5/5 Healthy 달성**
- W3 Day 1~4 일별 작업 계획 수립
- MSK 토픽 생성 절차 확인 (Day 1 gitops 세션 실행 예정)

**05-26~27 달성 사항 (W3 Day 1~2):**
- W3 shared 실행 설계 스펙 + 구현 플랜 작성 (로컬 E2E 중심 · work-order 추적)
- W3 Kafka cross-repo **work-order 발행** — 5개 서비스 할당 + GH 이슈 연결 (`docs/work-orders/W3_KAFKA_WORKORDER.md`)
- 인프라 방침 전환: EKS 비용관리 destroy → **로컬 docker-compose 우선** 검증 (TEAM_CHECKLIST_W3 현행화)
- **로컬 E2E harness 베이스라인 + D-2 해결**: `kafka-e2e-test.sh` compact_json 추가 → `--all` 5/5 validated(WARN 0), `--full` 13/13 PASSED, CloudEvent 페이로드 단위 round-trip 검증 신뢰 가능
- work-order Day 2 추적: 팀원 Kafka Producer/Consumer 산출물 **PR 0/5** (열린 PR 2건은 범위 밖) → **W3 종료 게이트 핵심 리스크**

### W4 (2026-06-01 ~ 06-05, 4영업일 — 6/3 지방선거 제외)

| Step | 내용 | 상태 | 시작일 | 완료일 | 비고 |
|------|------|------|--------|--------|------|
| Step 9 | E2E 테스트 시나리오 정의/조율 | Not Started | — | — | |
| Step 10 | SLA 성능 검증 | Not Started | — | — | |
| Step 11 | Staging 최종 배포 + 모니터링 | Not Started | — | — | |
| Step 12 | 발표 자료 + 시연 리허설 | Not Started | — | — | |

**W4 진행률**: 0/4 Steps 완료

---

## 작업 로그

### W1 (2026-05-12 ~ 05-15, 4영업일)

#### 2026-05-12 (화) Day 1
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-13 (수) Day 2
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-14 (목) Day 3
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-15 (금) Day 4
- **완료**:
- **진행 중**:
- **이슈**:
- **주간 요약**:

### W2 (2026-05-19 ~ 05-22, 4영업일)

#### 2026-05-19 (화) Day 1
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

#### 2026-05-20 (수) Day 2
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-21 (목) Day 3
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

#### 2026-05-22 (금) Day 4
- **완료**:
- **진행 중**:
- **이슈**:
- **주간 요약**:

### W3 (2026-05-26 ~ 05-29, 4영업일 — 5/25 부처님오신날 제외)

#### 2026-05-26 (화) Day 1
- **완료**:
  - **[Step 7]** W3 shared 실행 설계 스펙 + 구현 플랜 작성 (`specs/2026-05-26-w3-shared-execution-design.md`, `plans/2026-05-26-w3-shared-execution.md`)
  - **[Step 7]** W3 Kafka cross-repo work-order 발행 — 5개 서비스(platform/knowledge/learning-card/learning-ai/engagement) 할당 + GH 이슈 연결 (`docs/work-orders/W3_KAFKA_WORKORDER.md`)
  - **[Step 8]** 팀 체크리스트 인프라 현황 현행화 — EKS 비용관리 destroy 반영, **로컬 docker-compose 우선** 검증으로 방침 전환 (`TEAM_CHECKLIST_W3.md`)
  - **[Step 7]** 로컬 E2E harness 베이스라인 — `scripts/kafka-e2e-test.sh --all` → 5개 토픽 produce→consume 5/5 PASSED (`docs/reports/E2E_BASELINE_W3.md`)
- **진행 중**: 팀원 Kafka Producer/Consumer 구현 (PR 기한 05-27 EOD)
- **이슈**:
  - **D-1**: ZK에 5일 전 unclean shutdown의 stale ephemeral znode(`/brokers/ids/1`) 잔존 → 신규 broker 등록 시 NodeExistsException으로 kafka Exited(1). `docker compose down -v` 클린 재생성으로 해결. (재발 방지: 세션 종료 시 `down -v` 권장)
  - **D-2**: E2E 샘플이 멀티라인 pretty-print JSON → `kafka-console-producer`가 줄 단위 분리 발행 → consumer가 첫 줄만 읽어 CloudEvent 단위 검증 불완전 (전송 경로 produce→consume는 PASS)
- **다음**: D-2 해결(샘플 1라인 compact), work-order PR 추적

#### 2026-05-27 (수) Day 2
- **완료**:
  - **[Step 7]** harness D-2 해결 — `kafka-e2e-test.sh`에 `compact_json`(jq -c, 깨진 JSON은 `tr -d '\r\n'` fallback) 추가 → produce 직전 1라인 압축. `--all` 5/5 `[CONSUME] OK validated`(WARN 0건), `--full` 13/13 PASSED. CloudEvent 페이로드 단위 round-trip 검증 신뢰 가능
  - **[Step 7]** work-order Day 2 추적 — `gh pr list` 조회: Kafka 산출물 PR **0/5**. 열린 PR 2건(platform #33 = W2/MSA test env, knowledge #23 = 그래프 API+청킹, Kafka 파일 미포함)은 work-order 범위 밖
- **진행 중**: 팀원 Kafka Producer/Consumer PR 대기
- **이슈**: 팀원 Kafka 산출물 PR 0/5 (기한 05-27 EOD 초과) — **W3 종료 게이트(PRD_W3 §5) 핵심 차단**. E2E consumer 비즈니스 로직 검증은 서비스 구현 도착까지 보류
- **다음**: 서비스 PR 도착 시 `E2E_SCENARIOS_W3.md` 시나리오로 consumer 처리 확장 검증 / staging 검증은 인프라 재기동 후

#### 2026-05-28 (목) Day 3
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-05-29 (금) Day 4
- **완료**:
  - **[Step 7]** Security 2차 검토 완료 — E2E 시크릿 분리/테스트데이터 마스킹(`@test.synapse.dev` 합성)/네트워크 격리(`synapse-net`) → TASK Constraints 반영
  - **[Step 7]** 크로스서비스 스키마 호환성 리뷰 — Avro 8종 형식(jq) + `generateAvroJava` 컴파일(9 클래스) + CloudEvent 8필드 통과 (`docs/reports/SCHEMA_COMPAT_REVIEW_W3.md`)
  - **[Step 7]** E2E 결과 리포트 작성 — 전송 경로 5/5·13/13, 서비스 단위 미실행(체인 양끝 미충족) (`docs/reports/E2E_REPORT_W3.md`)
  - **[Step 7]** E2E harness 체인 시나리오 스캐폴딩 — `--scenarios` 모드(S1~S4 의존성 순서 produce + service-check 안내) `scripts/kafka-e2e-test.sh`
  - **[Step 8]** 배포 전략·승인 플로우·롤백 절차 정의 (`docs/reports/DEPLOY_REPORT_W3.md` §A~C) — 실행 검증은 EKS destroy로 보류
  - **[게이트]** W3 종료 게이트 평가 — **미통과(1/5)**, 차단=서비스 Kafka 미완성(실측 반영) (`docs/reports/W3_EXIT_GATE.md`)
  - **[문서]** 프로젝트 관리 문서 W3 현행화 + W1~W4 날짜·요일 정합성 정정 (커밋 b97e99a)
  - **[cross-repo]** 전체 레포 fetch/pull 최신화 + Kafka 구현 **실측** — "PR 0/5" 폐기. learning-svc main 머지(#26, card 완전·ai consumer), platform·engagement는 **dev 미머지**, **knowledge 미구현**. cards-generated 경로 **HTTP 대체** 발견 → 추적 문서 6종 현행화 + [W4_KAFKA_WORKORDER.md](../../work-orders/W4_KAFKA_WORKORDER.md) 발행
  - **[D-001]** cards-generated **HTTP 채택 확정** + EVENT_FLOW_MATRIX 정정 + AI카드 알림 트리거 설계(platform 알림 버스 notification-send-v1 재사용 — `NOTIFICATION_TRIGGER_AI_CARDS.md`)
  - **[D-002]** 스키마 패밀리 분기 발견(5서비스 4방식: Confluent-Avro/수동-Avro/JSON×2, shared 라이브러리 **고아=아무도 미사용**) → **Avro + Schema Registry 사수 결정**(Option 1, `D-002_SCHEMA_FAMILY_DECISION.md`)
  - **[표준]** 이벤트 계약 표준 수립 — `EVENT_CONTRACT_STANDARD.md` (Avro 봉투·토픽/필드 카탈로그·Kafka 설정 복붙·멱등성·BACKWARD)
  - **[스키마]** `NotificationSend`(platform 미러) + `CardReviewDue`/`LevelUp`/`BadgeEarned` 초안 + **기존 4종(UserRegistered/NoteCreated/NoteUpdated/ReviewCompleted)에 공통메타(eventId/occurredAt) 보강** — `generateAvroJava` 전체 컴파일 확인
  - **[토픽]** 신규 4종(review-due/level-up/badge-earned/notification-send) `create-kafka-topics.sh` + `docker-compose kafka-init` 추가
  - **[배포]** 근본원인 해소 — shared **GitHub Packages 발행 구현**(`build.gradle.kts` publishing + `publish.yml`), `synapse-shared-0.1.0.jar` Avro 클래스 포함 검증, `runbooks/PUBLISH_SHARED_LIBRARY.md`
  - **[harness]** Avro 라운드트립 모드 `--avro` 추가 → **로컬 스택 기동 후 라이브 검증 8/8 PASSED**(8토픽 produce→consume + subject `<topic>-value` 자동등록, 전역 BACKWARD). 검증 중 `occurredAt` logicalType를 평문 long으로 정정(콘솔 도구 직렬화 한계, wire/BACKWARD 호환 — 레지스트리 v1→v2 수락으로 입증)
  - **[이슈]** 4개 서비스 레포에 계약 표준 적용 이슈 발행/갱신 — platform #43, engagement #13, knowledge #26, learning #32 (Avro/shared 사용/Kafka 설정/로컬 실행/DoD/기한 W4 D1-2)
- **진행 중**: knowledge Producer/engagement Consumer/platform·engagement dev→main PR 대기 (W4 carryover)
- **이슈**: W3 종료 게이트 미통과(1/5) — 어떤 체인도 Producer+Consumer가 main 동시 충족 안 됨. knowledge 미구현이 체인 B 차단. cards-generated HTTP 드리프트로 매트릭스 정정 필요
- **주간 요약**: shared/team-lead W3 책임(토픽·스키마·harness·work-order·검증 설계)은 완료. 추가로 **cross-repo 실측 → D-001(cards HTTP)·D-002(Avro 사수) 결정 → 이벤트 계약 표준 수립 → 스키마/토픽 정비 → shared 라이브러리 발행 구현(근본원인 해소) → 서비스 이슈 4건**까지 W4 롤아웃 선결 완료. 서비스 Kafka는 실측 결과 부분 진행(learning main / platform·engagement dev / knowledge 미구현)이라 **E2E service 단위·종료 게이트 미달**. EKS destroy로 dev/staging·Observability 미진행 → 구현/배포는 W4 이월. Step 7/8 In Progress 유지

### W4 (2026-06-01 ~ 06-05, 4영업일 — 6/3 지방선거 제외)

#### 2026-06-01 (월) Day 1
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-06-02 (화) Day 2
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-06-03 (수) — 지방선거 (휴무)

#### 2026-06-04 (목) Day 3
- **완료**:
- **진행 중**:
- **이슈**:
- **다음**:

#### 2026-06-05 (금) Day 4
- **완료**:
- **진행 중**:
- **이슈**:
- **주간 요약**:

---

## 변경 이력

| 날짜 | 변경 사항 |
|------|-----------|
| 2026-05-29 | 계약 표준화 — D-001(cards HTTP)+D-002(Avro 사수) 결정, EVENT_CONTRACT_STANDARD 수립, 스키마 3종 초안+기존 4종 공통메타 보강, 신규 토픽 4종, GitHub Packages 발행 구현+runbook, harness `--avro`, 서비스 이슈 4건 |
| 2026-05-29 | cross-repo Kafka 실측 — learning main 머지/platform·engagement dev/knowledge 미구현/cards-generated HTTP 드리프트 → 추적 6종 현행화 + W4_KAFKA_WORKORDER 발행 |
| 2026-05-29 | W3 Day 4 — 종료 게이트 평가(미통과)·E2E 결과·스키마 호환성·배포 전략/롤백 리포트 4종 + harness `--scenarios` 스캐폴딩 + Security 2차 |
| 2026-05-29 | W3 Day 1~2 현행화 — work-order 발행 + 로컬 E2E harness 검증(D-1/D-2 해결) + PR 0/5 추적 반영 / W3·W4 날짜·요일 정정 (W3 05-26~29, W4 06-01~05, 토요일 05-30 항목 제거) |
| 2026-05-19 | W2 Step 4-5 완료 + gitops EKS provider swap + PRD 검수 + 문서 갱신 |
| 2026-05-11 | W2/W3/W4 대시보드 및 로그 템플릿 추가 |
| 2026-05-11 | 초기 템플릿 생성 |
