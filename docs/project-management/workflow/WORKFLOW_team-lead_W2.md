# WORKFLOW: @team-lead — Week 2

> **Task 문서**: [TASK_team-lead.md](../task/TASK_team-lead.md)  
> **기간**: 2026-05-19 ~ 2026-05-23  
> **PRD**: [PRD_W2.md](../prd/PRD_W2.md)

---

## Step 4: Kafka 토픽 설계 + 생성

### 4.1 TASK 시작
- [x] Step Goal / Done When / Scope / Input 확인
- [x] PRD_W2 해당 요구사항 확인 (FR-TL-101)
- [x] Duration 산정 확인

### 4.2 요구사항 분석
- [x] 도메인별 토픽 목록 확정 (5개: user-registered, note-created, note-updated, review-completed, cards-generated)
- [x] 토픽 파티션 수 / 복제 팩터 정의 (3 partitions, replication-factor 2)
- [x] 토픽 네이밍 컨벤션 확정 (`{service}.{domain}.{event}-v1`)
- [x] 메시지 보존 기간 정책 정의 (7일)
- [x] Instructions 초안 → TASK 문서 반영

### 4.3 Security 1차 검토 (네트워크 보안)
- [ ] Kafka ACL 토픽별 생산자/소비자 권한 정의 — MSK 배포 후
- [ ] SASL/TLS 인증 설정 확인 — MSK 배포 후
- [x] 토픽 접근 제어 최소 권한 원칙 적용 (설계 완료)
- [x] 결과 → TASK Constraints 반영

### 4.4 인프라 아키텍처 설계
- [x] 도메인별 토픽 목록 및 파티션 구성도 작성
- [x] 프로듀서/컨슈머 매핑 다이어그램 작성
- [x] 토픽 보존 기간 / cleanup.policy 설정 설계
- [x] Duration(final) 갱신

### 4.5 Security 2차 검토
- [ ] 토픽 메시지 암호화 전송 (TLS) 확인 — MSK 배포 후
- [ ] 민감 데이터 토픽 접근 제한 확인 — MSK 배포 후
- [x] 결과 → TASK Constraints 반영

### 4.6 N/A (인프라 — DTO/Entity 해당 없음)

### 4.7 Kafka 토픽 생성
- [ ] MSK/Kafka 클러스터에 토픽 생성 — MSK 배포 후 (`scripts/create-kafka-topics.sh` 준비됨)
- [x] 각 토픽 파티션 수 / 복제 팩터 설정 (스크립트에 반영)
- [x] 토픽 config 설정 (retention.ms, cleanup.policy)
- [x] docker-compose에 토픽 자동 생성 스크립트 반영 (`kafka-init` 서비스)

### 4.8 토픽 검증 테스트
- [x] kafka-topics.sh --list 로 토픽 목록 확인 (Docker Compose 검증)
- [ ] kafka-console-producer/consumer 로 메시지 송수신 테스트 — MSK 배포 후
- [x] 파티션 배분 확인 (Docker Compose 검증)
- [x] docker compose 환경에서 토픽 자동 생성 확인

### 4.9 N/A (인프라 — Controller 해당 없음)

### 4.10 N/A (인프라 — View 해당 없음)

**Step 4 Status**: [ ] Not Started / [ ] In Progress / [x] Done

---

## Step 5: Schema Registry BACKWARD 호환성 강제

### 5.1 TASK 시작
- [x] Step Goal / Done When / Scope / Input 확인
- [x] PRD_W2 해당 요구사항 확인 (FR-TL-102)
- [x] Duration 산정 확인

### 5.2 요구사항 분석
- [x] Schema Registry 글로벌 호환성 정책 요건 분석 (BACKWARD)
- [x] Avro 스키마 호환성 규칙 분석 (필드 추가=default 필수, 삭제 불가)
- [x] 서비스별 스키마 등록 절차 정의
- [x] Instructions 초안 → TASK 문서 반영

### 5.3 Security 1차 검토 (네트워크 보안)
- [x] Schema Registry API 접근 제한 (내부 네트워크만) — VPC 내부 설계
- [x] 스키마 등록/수정 권한 관리 확인
- [x] 결과 → TASK Constraints 반영

### 5.4 인프라 아키텍처 설계
- [x] 글로벌 호환성 레벨 설정 전략 수립 (BACKWARD)
- [x] 스키마 버전 관리 정책 정의 (`docs/SCHEMA_EVOLUTION.md`)
- [x] Duration(final) 갱신

### 5.5 Security 2차 검토
- [x] 스키마 삭제 방지 정책 확인 (soft delete만)
- [x] 비인가 스키마 등록 방지 확인
- [x] 결과 → TASK Constraints 반영

### 5.6 N/A (인프라 — DTO/Entity 해당 없음)

### 5.7 Schema Registry 설정 적용
- [x] 글로벌 호환성 레벨 BACKWARD 설정 (Docker Compose `SCHEMA_REGISTRY_COMPATIBILITY_LEVEL: BACKWARD`)
- [x] 기존 토픽 subject별 호환성 레벨 확인
- [x] docker-compose Schema Registry 환경변수 반영 (포트 8085)

### 5.8 호환성 검증 테스트
- [x] 호환 스키마 등록 → 성공 확인
- [x] 비호환 스키마 등록 → 409 거부 확인 (필드 삭제 시)
- [x] `GET /config` → BACKWARD 확인
- [x] 각 서비스별 호환성 테스트

### 5.9 N/A (인프라 — Controller 해당 없음)

### 5.10 N/A (인프라 — View 해당 없음)

**Step 5 Status**: [ ] Not Started / [ ] In Progress / [x] Done

---

## Step 6: Gateway 라우팅

### 6.1 TASK 시작
- [x] Step Goal / Done When / Scope / Input 확인
- [x] PRD_W2 해당 요구사항 확인 (Gateway 라우팅)
- [x] Duration 산정 확인

### 6.2 요구사항 분석
- [x] 4-서비스 경로 매핑 요건 정의 (/api/platform/**, /api/engagement/**, /api/knowledge/**, /api/learning/**)
- [x] Rate Limit 요건 분석 (서비스별/글로벌 제한)
- [x] CORS 설정 요건 확인
- [x] Instructions 초안 → TASK 문서 반영

### 6.3 Security 1차 검토 (네트워크 보안)
- [x] Gateway → 서비스 간 내부 통신만 허용
- [x] 외부 접근 Gateway 단일 진입점 확인
- [x] Rate Limit으로 DDoS 완화 확인
- [x] 결과 → TASK Constraints 반영

### 6.4 인프라 아키텍처 설계
- [x] 서비스별 라우팅 테이블 설계
- [x] Rate Limit 정책 설계 (req/sec per IP)
- [x] Health check 엔드포인트 바이패스 설계
- [x] Duration(final) 갱신

### 6.5 Security 2차 검토
- [ ] JWT 검증 Gateway 레벨 적용 확인 — Out of Scope (향후 Step)
- [x] Rate Limit 버스트 정책 확인
- [x] 민감 헤더 전파 제한 확인
- [x] 결과 → TASK Constraints 반영

### 6.6 N/A (인프라 — DTO/Entity 해당 없음)

### 6.7 Gateway 구현
- [x] Spring Cloud Gateway 라우트 설정 (4-서비스 경로 매핑) — RoutesConfig.java (프로그래밍 방식, Boot 4.0.6 YAML 라우트 버그 대응)
- [x] Rate Limit 필터 설정 (Redis 기반 RedisRateLimiter) — RoutesConfig.java (1 req/sec, burst 60)
- [x] CORS 글로벌 설정 — CorsConfig.java (CorsWebFilter)
- [x] docker-compose에 Gateway 서비스 추가/갱신 (실제 빌드 이미지)

### 6.8 라우팅 테스트
- [x] 각 서비스 경로 라우팅 동작 확인 (500 — stub upstream, 404 — 미매치 경로)
- [x] Rate Limit 초과 시 429 응답 확인 (#64에서 429 발생)
- [x] CORS preflight 요청 처리 확인 (Access-Control-Allow-Origin 헤더 확인)
- [x] Health endpoint 확인 (/actuator/health → UP, Redis UP)

### 6.9 N/A (인프라 — Controller 해당 없음)

### 6.10 N/A (인프라 — View 해당 없음)

**Step 6 Status**: [ ] Not Started / [ ] In Progress / [x] Done
