# WORKFLOW: @team-lead — Week 4

> **Task 문서**: [TASK_team-lead.md](../task/TASK_team-lead.md)  
> **기간**: 2026-06-01 (월) ~ 2026-06-05 (금) — 4영업일 (6/3 지방선거 제외)  
> **PRD**: [PRD_W4.md](../prd/PRD_W4.md)

> **📍 06-05(Day 4) origin/main 실측 상태**: **4서비스 Kafka Producer/Consumer 전원 origin/main 머지 완료**(knowledge #40·platform #46·engagement #23·learning) → **Step 9 통합 E2E는 머지에 막히지 않고 지금 로컬 compose에서 실행 가능**. 차단요인 없음 = 9.2 실행이 곧 잔여 작업. (주의: `git fetch` 후 `origin/main` 기준 확인 — 로컬 stale main은 미머지 오판 유발). dev 잔여(S6 audit·TLS·KAFKA_ENABLED 게이트·staging 프로파일)는 EKS/MSK 배포용 하드닝으로 별도 머지, 로컬 E2E 무관.

> ✅ **사후 정합(2026-06-08)**: 본 주차 미완 항목(Step 9~12)은 전수 검토 완료 — Staging 5/5·Observability는 W5 Day1 해소, E2E·SLA·발표는 W5 일정 추적중, 미추적 잔여 0건. → [SHARED_W1W4_INCOMPLETE_REVIEW](../../reports/SHARED_W1W4_INCOMPLETE_REVIEW.md)
> ✅ **체크박스 정합(2026-06-10)**: W4 Step 9~11 산출물은 **W5에서 실제 종결**(통합 E2E·W1 풀체인·SLA P1/P2/P4/P5·dev/staging 5/5). 본 파일 체크박스를 그 실측에 맞춰 갱신(완료 시점=W5, 근거 주석). **잔여 [~]/[ ]=owner/인프라 차단**: 커버리지 80%(전 서비스 jacoco) · 검색 기능(knowledge#71/nori) · 모더레이션 F8(platform#86) · AI생성 F4(learning#73). 상세 [SLA_VERIFICATION_W5](../../reports/SLA_VERIFICATION_W5.md)·[WORKFLOW_W5](./WORKFLOW_team-lead_W5.md).

---

## Step 9: 전체 E2E 시나리오 정의 + 테스트 실행 조율

### 9.1 E2E 시나리오 정의
- [x] 전체 서비스 통합 E2E 시나리오 목록 작성 — [E2E_SCENARIOS_W4.md](../../guides/E2E_SCENARIOS_W4.md) (W1~W5 + W3 S1~S4/E1~E3/M1 재사용), 06-02 prep
- [~] 테스트 데이터 준비 — seed V001~V005 S1~S4 커버 ✅ / **갭 2건**(레벨업 경계 사용자·신고 reports) = engagement 임계·스키마 확정 후

### 9.2 E2E 테스트 실행
- [x] **계약·전송 E2E 06-05 실행** — harness 4모드 PASS(`--avro`8/8·`--all`5/5·`--full`13/13·`--scenarios`5/5), [E2E_REPORT_W4](../../reports/E2E_REPORT_W4.md)
- [x] 서비스 비즈니스 로직 E2E — **W5 핵심 시나리오 PASS**(W1 풀체인·W2·W3·W4·W5, 06-09~10). AI생성·검색 leg는 F4/nori 잔여
- [x] 실패 항목 기록 — 전송/계약 0건 실패

### 9.3 버그 트리아지
- [x] P0/P1/P2 분류
- [x] P0 즉시 수정 대상 확정

### 9.4 버그 수정
- [x] P0 버그 수정 지시 + 추적 — F1/F2/F3/F7/F9/F10(D-004 Stage1) 수정·머지(W5)
- [x] 수정 코드 리뷰 + 테스트

### 9.5 회귀 테스트
- [x] 수정 후 전체 테스트 재실행
- [~] 커버리지 80% 이상 확인

### 9.6 문서 업데이트
- [x] API 문서 최신화 — survey+gateway 대조(W5 shared#35)
- [x] HISTORY 완료 기록

**Step 9 Status**: [ ] Not Started / [x] In Progress / [ ] Done — 정의·실행·트리아지·수정·문서 **W5 종결**(핵심 시나리오·W1 풀체인 PASS). 잔여 [~]=커버리지 80%(전 서비스 jacoco·owner)

---

## Step 10: 성능 SLA 검증

### 10.1 E2E 시나리오 정의
- [x] 성능 SLA 검증 시나리오 목록 작성 (API P95, Kafka, 검색) — [SLA_VERIFICATION_W4.md](../../reports/SLA_VERIFICATION_W4.md) P1~P7 + 측정방법, 06-02 prep
- [~] 테스트 데이터 준비 (부하 테스트용) — 측정방법·쿼리세트 초안 정의 / 부하 생성 스크립트·코퍼스 확장은 측정 직전(Day4)

### 10.2 E2E 테스트 실행
- [x] API P95 < 200ms 검증 — 79.7/15.3ms(W5)
- [x] Kafka 이벤트 처리 < 5s 검증 — ~1.42s(W5)
- [~] 검색 응답 < 2s 검증 — 레이턴시 0.012s PASS·기능검색 knowledge#71(W5)
- [x] 실패 항목 기록

### 10.3 버그 트리아지
- [x] P0/P1/P2 분류
- [x] P0 즉시 수정 대상 확정

### 10.4 버그 수정
- [x] 성능 미달 항목 P0 수정 — 측정분(P1/P2/P4/P5) 미달 없음(W5)
- [x] 수정 코드 리뷰 + 테스트

### 10.5 회귀 테스트
- [x] 수정 후 전체 테스트 재실행
- [~] 커버리지 80% 이상 확인

### 10.6 문서 업데이트
- [x] 성능 SLA 검증 결과 문서화 — SLA_VERIFICATION_W5(W5)
- [x] HISTORY 완료 기록

**Step 10 Status**: [ ] Not Started / [x] In Progress / [ ] Done — **W5 측정 종결**: P1·P2·P4·P5 충족(SLA_VERIFICATION_W5). 잔여 [~]=P3 검색 기능·P6 AI·P7 발송률(인프라/키/토큰)·커버리지·부하

---

## Step 11: Staging 배포 + 모니터링 대시보드 가동

### 11.1 E2E 시나리오 정의
- [x] Staging 배포 검증 시나리오 목록 작성 — verify-argocd-deploy.sh로 대체(W5)
- [x] 테스트 데이터 준비 — verify 스크립트 + 시드(W5)

### 11.2 E2E 테스트 실행
- [x] Staging 환경 전체 서비스 배포 실행 — dev 16/0/0·staging 20/0/0(W5 D1, gitops#136)
- [x] 모니터링 대시보드 가동 확인 — Observability(kube-prometheus-stack) 기동(W5 D1)
- [x] 실패 항목 기록

### 11.3 버그 트리아지
- [x] P0/P1/P2 분류
- [x] P0 즉시 수정 대상 확정

### 11.4 버그 수정
- [x] P0 버그 수정 — platform/gateway CrashLoop 해소(gitops#136, W5 D1)
- [x] 수정 코드 리뷰 + 테스트

### 11.5 회귀 테스트
- [x] 수정 후 전체 테스트 재실행
- [~] 커버리지 80% 이상 확인

### 11.6 문서 업데이트
- [~] Staging 배포 결과 문서화 — dev/staging 결과 기록(HUB/HISTORY) · 24h 안정·운영가이드 Day4 잔여
- [x] HISTORY 완료 기록

**Step 11 Status**: [ ] Not Started / [x] In Progress / [ ] Done — dev/staging 5/5 + Observability(W5 D1). 잔여=24h 안정·운영가이드(Day4)

---

> **Step 12 (발표 자료 + 시연 리허설)**: TASK_team-lead에 정의되어 있으나 **실행은 W5**(6/12 리허설·6/15 발표, [PRD_W5](../prd/PRD_W5.md)). W4 범위는 Step 9~11이며, Step 12는 W5 워크플로우에서 추적한다.
