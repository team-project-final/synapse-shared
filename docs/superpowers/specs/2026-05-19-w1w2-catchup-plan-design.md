# W1/W2 미완료 작업 캐치업 계획

> **작성일**: 2026-05-19  
> **대상**: @team-lead  
> **기간**: 2026-05-19 ~ 2026-05-23 (W2)  
> **접근 방식**: A안 — 순차 진행 (의존관계 기반)

---

## 1. 배경

W1(05-12~05-16) 기간에 Step 1(AWS 인프라 프로비저닝)은 완료했으나 Step 2(Docker Compose), Step 3(CI/CD)가 미시작 상태로 남았다. W2 첫날(05-19)에 Step 4(Kafka 토픽), Step 5(Schema Registry)는 완료했으나 Step 6(Gateway)이 남아 있다.

W2 남은 4영업일(05-19~05-23) 안에 밀린 Step 2, 3과 원래 W2 작업인 Step 6을 모두 완료해야 한다.

## 2. 미완료 항목

| Step | 내용 | 원래 주차 | 상태 | 예상 소요 |
|:----:|------|:--------:|:----:|:---------:|
| 2 | Docker Compose 4-서비스 구성 | W1 | 미시작 | 1일 |
| 3 | CI/CD 파이프라인 구성 | W1 | 미시작 | 2일 |
| 6 | Gateway 라우팅/Rate Limit | W2 | 미시작 | 1일 |

합계: 4일 (W2 남은 영업일과 동일)

## 3. 의존관계

```
Step 2 (Docker Compose)
  ├─→ Step 3 (CI/CD) — Dockerfile + compose 기반으로 ci.yml/deploy.yml 작성
  └─→ Step 6 (Gateway) — Gateway를 compose에 포함 + 라우팅 테스트 시 4-서비스 필요
```

Step 2가 Step 3, 6의 공통 선행 조건이다.

## 4. 일정 계획

### D1 (05-19) — Step 2: Docker Compose 4-서비스 구성

**포함 서비스 (11개)**:
- 인프라: postgres, redis, kafka, zookeeper, schema-registry, elasticsearch
- 앱: platform-svc, engagement-svc, knowledge-svc, learning-card-svc, learning-ai-svc

**작업 순서**:
1. TASK Step 2 Status → "In Progress" 갱신
2. docker-compose.yml 작성
   - 서비스 간 `depends_on` + `healthcheck` 설정
   - 네트워크: 단일 bridge 네트워크 (`synapse-net`)
   - 볼륨: DB 데이터 영속화 (`postgres-data`, `redis-data`, `es-data`)
   - 포트 매핑 정의
3. `.env.example` 전체 환경변수 정리
4. kafka-init 서비스 연동 (Step 4 토픽 자동 생성 스크립트 활용)
5. Schema Registry 포트/호환성 설정 반영 (포트 8085, BACKWARD)
6. `docker compose up` → Health OK 확인 (< 2분)
7. README에 실행 방법 문서화
8. WORKFLOW Step 2 체크박스 업데이트
9. TASK Step 2 Done When 체크 + Status → "Done"
10. HISTORY 05-19 로그 작성

**제약 조건**:
- 단일 `docker compose up`으로 전체 실행
- 메모리 8GB 환경에서 동작
- Apple Silicon(ARM) 호환

**산출물**: `docker-compose.yml`, `.env.example`, README 실행 방법 섹션

### D2 (05-20) — Step 3 전반: mirror.yml + ci.yml

**작업 순서**:
1. TASK Step 3 Status → "In Progress" 갱신
2. mirror.yml 작성
   - 트리거: `on: push` (main)
   - 동작: 소스 레포 → synapse-mirror 동기화
   - Secrets: `MIRROR_TOKEN`
3. ci.yml 작성
   - 트리거: `on: pull_request` (main 대상)
   - 단계: checkout → Java 21 → `./gradlew build` → test → Modulith verify
   - Python(learning-ai): `pip install` → `pytest`
   - Gradle dependencies 캐시
4. mirror.yml 동작 테스트
5. ci.yml 동작 테스트 (PR 생성 → 빌드/테스트 통과)
6. WORKFLOW Step 3 전반부 체크박스 업데이트
7. HISTORY 05-20 로그 작성

**제약 조건**: CI 실행 시간 < 5분

**산출물**: `.github/workflows/mirror.yml`, `.github/workflows/ci.yml`

### D3 (05-21) — Step 3 후반: deploy.yml + 전체 검증

**작업 순서**:
1. deploy.yml 작성
   - 트리거: `on: push` (main, ci 성공 후)
   - 단계: checkout → Docker build → ECR push → gitops image tag patch → ArgoCD dev 동기화
   - Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `ECR_REGISTRY`, `ARGOCD_TOKEN`
2. deploy.yml 동작 테스트 (main push → ECR → ArgoCD Sync)
3. 전체 파이프라인 E2E 검증
   - PR → ci.yml → squash merge → deploy.yml → mirror.yml 순차 동작 확인
4. 파이프라인 문서화
5. WORKFLOW Step 3 나머지 체크박스 완료
6. TASK Step 3 Done When 체크 + Status → "Done"
7. HISTORY 05-21 로그 작성

**제약 조건**: dev만 자동 배포, staging/prod는 수동 승인

**산출물**: `.github/workflows/deploy.yml`, 파이프라인 문서

### D4 (05-22) — Step 6: Gateway 라우팅/Rate Limit

**작업 순서**:
1. TASK Step 6 Status → "In Progress" 갱신
2. Spring Cloud Gateway 프로젝트 설정
3. application.yml 라우팅 규칙 작성
   - `/api/platform/**` → platform-svc
   - `/api/engagement/**` → engagement-svc
   - `/api/knowledge/**` → knowledge-svc
   - `/api/learning/**` → learning-svc
4. Redis 기반 Rate Limit 설정 (분당 60회, 사용자별)
5. CORS 글로벌 설정
6. Health check 엔드포인트 (`/actuator/health`)
7. docker-compose.yml에 Gateway 서비스 추가/갱신
8. 테스트: 라우팅 + Rate Limit 429 + CORS preflight
9. WORKFLOW Step 6 전체 체크박스 완료
10. TASK Step 6 Done When 체크 + Status → "Done"
11. HISTORY 05-22 로그 작성

**제약 조건**: Rate Limit 분당 60회, 타임아웃 30초, JWT 검증은 Out of Scope

**산출물**: Gateway application.yml, docker-compose.yml 갱신, Gateway 문서

### D5 (05-23) — 버퍼 + 문서 정리

| 시나리오 | 할 일 |
|----------|-------|
| 밀린 작업 있음 | D1~D4 미완료 항목 마무리 |
| 모두 완료 | HISTORY 주간 요약, SCOPE 성공 기준 체크, W3 선행 준비 (Step 7/8 TASK 읽기) |

## 5. 문서 업데이트 규칙

매 Step 완료 시 3종 문서를 반드시 갱신한다:

| 문서 | 갱신 내용 |
|------|-----------|
| TASK | Done When 체크 + Status → "Done" |
| WORKFLOW | 해당 체크박스 모두 `[x]` |
| HISTORY | 당일 로그 + 대시보드 상태/완료일 갱신 |

## 6. 리스크

| 리스크 | 영향 | 대응 |
|--------|------|------|
| Step 3(CI/CD)가 2일 초과 | Step 6 밀림 | D5 버퍼 활용, 최악의 경우 Gateway를 W3 초로 이동 |
| 4-서비스 Dockerfile 미존재 | Step 2 지연 | 최소 health endpoint만 있는 stub Dockerfile 사용 |
| ECR/ArgoCD 연동 이슈 | Step 3 후반 지연 | deploy.yml은 dry-run 모드로 먼저 검증 |
