# W4 성능 SLA 검증 시나리오 (Step 10.1)

> **작성**: 2026-06-02 (W4 Day 2 — prep) · **owner**: @team-lead
> **상태**: 시나리오·측정방법 **정의 완료** / **P2 브로커 전송 지연 06-05 측정**(§5) / 풀 측정은 서비스 E2E 통과 후(W5 Step 10.2)
> **근거**: [PRD_W4](../project-management/prd/PRD_W4.md) §3(NFR) · [WORKFLOW_team-lead_W4](../project-management/workflow/WORKFLOW_team-lead_W4.md) Step 10 · [E2E_SCENARIOS_W4](../guides/E2E_SCENARIOS_W4.md)
> **베이스라인**: 로컬 transport 전파 지연 [E2E_BASELINE_W3](./E2E_BASELINE_W3.md) (EndToEndLatency 측정 기준)

---

## 1. SLA 목표 (측정 항목)

| ID | 항목 | 목표 | 측정 대상 | 출처 |
|----|------|------|----------|------|
| P1 | API 응답 (P95) | **< 200ms** | 주요 REST 엔드포인트 (가입/복습/노트/검색/알림목록) | TASK Step 10 / NFR |
| P2 | Kafka 이벤트 처리 | **< 5초** | produce → consumer 처리 완료 (단일 홉) | NFR (Kafka<5s) |
| P3 | 검색 응답 | **< 2초** | 하이브리드 검색 API (BM25+시맨틱 RRF) | NFR / FR-K2-401 |
| P4 | E2E 이벤트 체인 | **< 10초** | 복습→XP→레벨업→알림 (W1 전체) | NFR-401 |
| P5 | Audit 적재 지연 | **< 30초** | 이벤트 발행 → audit_logs 적재 | NFR-403 |
| P6 | AI 카드 생성 | **< 30초** | 노트 생성 → 카드 저장 (W3 체인) | NFR-405 |
| P7 | FCM 발송 성공률 | **> 95%** | 알림 발송 시도 대비 성공 | NFR-402 |

---

## 2. 측정 방법

### P1 — API P95 (<200ms)
- 도구: `hey` 또는 `k6` (없으면 `curl -w "%{time_total}"` N회 루프 + p95 계산).
- 부하: 동시 10 · 총 500요청/엔드포인트, 워밍업 후 측정.
- 측정 엔드포인트(로컬 포트):
  | 엔드포인트 | 서비스 | 포트 |
  |---|---|---|
  | POST /api/v1/auth/register | platform | 8081 |
  | POST /api/v1/reviews | learning-card | 8084 |
  | POST /api/v1/notes | knowledge | 8083 |
  | GET /api/v1/search?q=... | knowledge-2 | 8083 |
  | GET /api/v1/notifications | platform | 8081 |
- 기록: p50/p95/p99 + 에러율. **DB seed 적용 후** 측정(콜드 캐시 영향 분리).

### P2 — Kafka 단일 홉 (<5초)
- 방법: produce 시각 ↔ consumer 처리 로그/DB write 시각 차. `kafka-e2e-test.sh`의 EndToEndLatency 패턴 재사용([E2E_BASELINE_W3](./E2E_BASELINE_W3.md)).
- consumer 처리 완료 기준 = DB 반영(예: user_profiles insert) 시각.

### P3 — 검색 (<2초)
- 하이브리드 검색 API에 테스트 쿼리 세트(§3) 투입 → `time_total` 측정. Elasticsearch 인덱스 워밍업 후.

### P4 — E2E 체인 (<10초)
- W1 시나리오([E2E_SCENARIOS_W4 §2](../guides/E2E_SCENARIOS_W4.md)) 전체. 시작 = 복습 API 요청 시각, 종료 = platform FCM 발송(시도) 로그 시각.
- 측정 자동화: 각 서비스 로그의 eventId(=correlationId) 추적 → 타임스탬프 delta. 멱등 eventId가 correlation 키.

### P5 — Audit 적재 (<30초)
- 이벤트 발행 시각 ↔ `platform.audit_logs.created_at`(또는 ingest 시각) 차.

### P6 — AI 카드 생성 (<30초)
- W3 시나리오. 노트 생성 요청 시각 ↔ learning.cards/ai_generation_history `COMPLETED` 시각. LLM 호출 지연 포함.

### P7 — FCM 성공률 (>95%)
- 발송 시도/성공 카운트(platform 로그 또는 메트릭). FCM 미설정 시 **N/A 처리 + 발송 시도 경로 검증**으로 대체(PRD §6 리스크: 이메일 폴백).

---

## 3. 부하 / 테스트 데이터 준비 (Step 10.1 "테스트 데이터")

| 용도 | 데이터 | 상태 |
|------|--------|------|
| API 부하 (가입) | 유니크 email N개 생성 스크립트 | 🔴 준비 필요 — 동적 생성(`register-load.sh`, email=`load-{i}@...`) |
| 복습 부하 | 카드 seed (V003) 반복 복습 | 🟡 V003 3장 — 부하용 카드 대량 시드 권장(`V006_load_cards` 선택) |
| 검색 쿼리 세트 | 정확도/지연 측정용 쿼리 10~20개 + 기대 노트 | 🔴 준비 필요 — §3.1 |
| 체인(P4) | 레벨업 경계 사용자 | 🔴 [E2E_SCENARIOS_W4 §4](../guides/E2E_SCENARIOS_W4.md) 갭과 동일 (engagement 임계 확정) |

### 3.1 검색 쿼리 세트(초안, 정확도 70%+ 측정용 — NFR-404)
seed 노트(V002: "Kafka Basics", "Distributed Systems") 기반 예시:
| 쿼리 | 기대 상위 노트 |
|------|--------------|
| "Kafka event streaming" | e2e-note-01 |
| "CAP theorem consistency" | e2e-note-02 |
| "distributed messaging" | e2e-note-01 |
> 실측 시 노트 코퍼스를 20+로 확장해야 정확도 지표가 유의미 → knowledge-2 owner와 코퍼스/정답셋 합의.

---

## 4. 측정 절차 (W4 Day 4)

```
[선결] 서비스 E2E(W1~W5) 통과 + seed 적용
  ↓
1. 로컬 스택 워밍업 (docker compose up -d, seed-test-data.sh)
2. P1 API P95 → 엔드포인트별 부하 → p50/p95/p99 기록
3. P2/P4/P5/P6 체인 지연 → eventId correlation 로그 delta
4. P3 검색 지연 + 정확도(NFR-404)
5. P7 FCM 성공률(또는 N/A + 폴백)
6. 미달 항목 → P0/P1 트리아지 (Step 10.3) → 수정 지시
```

## 5. 결과 기록 양식

| ID | 목표 | 실측 | 판정 | 비고 |
|----|------|------|:----:|------|
| P1 | <200ms (P95) | **로그인 p95 79.7ms·p99 131.9ms / 신고생성 p95 15.3ms** | ✅ | 06-09 라이브(서비스 E2E 스택). bcrypt 포함값 |
| P2 | <5초 | **풀 홉 ~1.42s** (가입→engagement insert, 06-09) · 브로커 발행 p99 113ms(06-05) | ✅ | 06-09 풀 홉 측정(wall-clock 상한). 서비스 E2E 통과 후 |
| P3 | <2초 | — | 🔴 | knowledge 검색 401(F9) + 코퍼스 부재 — 미측정 |
| P4 | <10초 | — | ⏳ | W1 체인 — 레벨업 경계 시드 갭 |
| P5 | <30초 | **~0.72s** (가입→audit_logs, 06-09) | ✅ | 풀 홉 측정 |
| P6 | <30초 | — | ⏳ | LLM 포함 — F4(더미 키) |
| P7 | >95% | N/A | N/A | FCM 미설정 — 발송 시도 스킵 경로만 검증 |

> **06-09(W5 Day2) 라이브 측정**: P1·P2·P5 ✅ 충족(여유). 상세 [E2E_W5_DAY2 §3.5](./E2E_W5_DAY2.md). P3는 F9, P4/P6는 시드/AI 키 해소 후.

> 판정: ✅ 충족 / 🟡 경계(±10%) / 🔴 미달 / **🟡=부분측정**. 미달 시 [WORKFLOW_W4](../project-management/workflow/WORKFLOW_team-lead_W4.md) Step 10.3~10.5 트리아지·수정·회귀.

### 5.1 P2 부분측정 상세 (2026-06-05, 로컬 docker-compose)
- 도구: `kafka-producer-perf-test`(1000건·256B·200 rec/s·acks=all) + `kafka-consumer-perf-test`(1000건).
- **발행 지연**: avg 6.6ms · p50 1ms · p95 43ms · **p99 113ms** · max 283ms.
- **소비**: fetch.time 39ms / 1000건(≈25.6k msg/s), rebalance 3187ms(최초 1회).
- 판정: **브로커 전송 계층은 <5s를 압도적 여유로 충족**. 단 P2 정의("produce→consumer 처리 완료=DB write")의 **앱 컨슈머 처리·DB 반영 구간은 미측정** → 서비스 E2E(W5 Step 10.2)에서 eventId correlation 로그 delta로 풀 측정.
- 비고: produce→consume **왕복 wall-clock 7.9s**는 `kafka-console-consumer` JVM 콜드스타트 포함 값이라 실지연 아님(실지연은 위 ms 단위).
