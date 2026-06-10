# 설계 — W5 Day3 세션: D-004 Stage 1 → Schema BACKWARD 전토픽 → API 문서

> **작성**: 2026-06-10 (W5 Day 3) · **작성자**: @team-lead · **발표**: 06-15(코드 동결)
> **상위 참조**: [HANDOFF_W5_DAY3](../../project-management/HANDOFF_W5_DAY3.md) · [W5_PLAN §3](../../project-management/W5_PLAN.md) · [WORKFLOW_team-lead_W5](../../project-management/workflow/WORKFLOW_team-lead_W5.md)
> **상태**: 🟢 브레인스토밍 승인(2026-06-10) — 다음 단계 = 구현 플랜(writing-plans)

---

## 1. 목적 / 범위

이번 세션은 **3개 워크스트림을 순차 실행**한다:

- **A. D-004 Stage 1** — engagement outbound UUID(F10 비파괴 해소). *기존 확정 플랜을 그대로 실행*(재설계 없음).
- **B. Schema BACKWARD 전토픽** — shared 단독, BACKWARD 호환성 강제 프로브 전수(FR-TL-302). (보조: `--avro` 라이브 라운드트립은 §4 참조.)
- **C. API 문서** — 각 서비스 SpringDoc/OpenAPI 현황 실측 + gateway 라우팅 대조 + 누락 서비스 레포별 상세 이슈 발행(FR-TL-304).

**이월(이번 세션 범위 밖, 명시)**: 커버리지 80%(FR-ALL-303), SLA 풀측정(P3 검색·P4 체인·P6 AI·P7 FCM). → §6.

**설계 원칙**: 최종 코드 기준 한 번만 측정/문서화한다. 그래서 A(engagement 코드 변경)를 먼저 머지하고, 그 뒤 B·C를 진행해 재측정·드리프트를 피한다.

## 2. 세션 스파인 (시퀀싱·게이트)

```
[A] D-004 Stage 1 (engagement)
  구현(prod5+test7) → docker 빌드 전테스트 green
  → 라이브 E2E(F10 해소 입증: UUID.fromString 통과 · DLT 0)
  → engagement dev PR → merge → dev→main PR → merge → eng#34 close
        │
        ▼  ◀── GATE 1: A가 origin/main에 실제 머지됐는지 git fetch 후 확인
[B] Schema BACKWARD 전토픽 (shared)
  9 subject 전수: BACKWARD 레벨 단언 + 강제 프로브(호환 accept · 비호환 reject)
  → docs/reports/SCHEMA_BACKWARD_W5_DAY3.md
        │
        ▼  ◀── GATE 2: B 리포트 PASS(또는 FAIL 원인 기록) 후
[C] API 문서 (shared 산출 + 레포 이슈)
  서비스별 OpenAPI survey → gateway 라우팅 대조표 → 누락 서비스 상세 이슈 발행
```

**규칙:**
- **스트림 간 순차** — A 완주(main 머지) → B → C. 각 전환에 게이트: `git fetch` 후 `origin/main` 기준으로 직전 스트림 완료 확인(머지 실측 주의, HANDOFF_HUB §0).
- **스트림 내부 병렬 허용** — B의 다토픽 프로브, C의 다서비스 survey는 서브에이전트 병렬 가능. 스트림 간 순차는 유지(A 집중도 보호).
- **머지 경계** — team-lead 직접 머지 = shared/gitops/gateway만. A 코드는 engagement owner 머지. C의 서비스 보완은 *코드가 아닌 상세 이슈*로 전달.

## 3. 워크스트림 A — D-004 Stage 1 (실행 참조)

새 설계 없음. **기존 플랜 그대로 실행**: [`plans/2026-06-09-d004-stage1-engagement-uuid-outbound.md`](../plans/2026-06-09-d004-stage1-engagement-uuid-outbound.md).

**블래스트 반경(플랜 명시)**: prod 5(`GamificationEventPublisher`·`GamificationKafkaProducer`·`NoopGamificationEventPublisher`·`GamificationService`·`EngagementKafkaEventHandler`+`GamificationController`) + 테스트 7. 시그니처: `publishLevelUp`/`publishBadgeEarned` 첫 인자 `Long`→`String(UUID)`, `addXp`에 externalUserId(UUID) 추가.

**착수 시 해소할 오픈 항목 3개:**

| 오픈 항목 (플랜 §1-2/1-3/7) | 해소 방법 |
|---|---|
| HTTP `addXp` 경로 존재 여부 | `GamificationController` grep 재확인 → 있으면 `CurrentUser`에 subject(UUID) 접근자 추가, 없으면 Kafka 전용 확정 |
| outbound `tenantId`가 UUID인지 | 소스 이벤트 tenantId 값 확인 → 비UUID 유입 시 방어 로깅 + E2E 시드 UUID tenant 정렬 |
| eng#34(F10 draft) | 본 작업으로 대체 후 close |

**완료 기준(GATE 1):** ① docker 빌드 전테스트 green ② 라이브 E2E — 경계유저 복습→레벨업 → platform consumer `UUID.fromString` 통과 + "FCM skip for user \<UUID>" 로그 + **DLT 적재 0** ③ engagement dev→main 머지(origin/main 확인) ④ eng#34 close.

## 4. 워크스트림 B — Schema BACKWARD 전토픽

**대상**: 이벤트 avsc 9종 — engagement(BadgeEarned·LevelUp), knowledge(NoteCreated·NoteUpdated), learning(CardReviewDue·CardsGenerated·ReviewCompleted), platform(NotificationSend·UserRegistered). shared 참조타입(CloudEventEnvelope·TenantId·UserId)은 토픽 아님 — subject 대상서 제외(참조로만).

**"전수"의 정의** — subject마다:
1. **정본 등록 + 레벨 단언** — canonical avsc가 레지스트리에 등록(미발행 토픽이면 등록) + compat 레벨 = `BACKWARD`.
2. **강제 프로브(양방향)** — *호환 변형*(optional 필드 + default 추가) → `ExpectCompatible=$true`; *비호환 변형*(required 필드 제거/타입 변경) → `ExpectCompatible=$false`. 둘 다 기대대로면 PASS.

**툴링** — 기존 `scripts/check-schema-compatibility.ps1`(단일 subject 검사기) *재사용*. 그 위에 **전수 러너**(subject↔avsc 매니페스트 순회 → 단일 검사기 구동) 신규 추가. 기존 스크립트 무변경. 프로브 변형은 **프로그램적 생성**(envelope optional 필드 추가=호환 / required 필드 제거=비호환)으로 9 subject 전부 커버(note-created 외 샘플파일 신규 작성 불요).

**FR-TL-302 두 갈래 구분:**
- **(주) 호환성 강제 프로브 전수** — 위 1·2(이 워크스트림의 핵심, `check-schema-compatibility.ps1` REST `/compatibility` 사용).
- **(보조) `--avro` 라이브 라운드트립** — `scripts/kafka-e2e-test.sh --avro`로 실 발행/소비 직렬화 검증. 이미 베이스라인 PASS(HANDOFF). 레지스트리+Kafka 기동 시 subject별 라운드트립 재확인을 옵션으로 포함하되, B의 PASS 기준은 (주)에 둔다.

**선결** — 로컬 Schema Registry 기동(`docker-compose.schema-registry.yml`).

**산출물** — `docs/reports/SCHEMA_BACKWARD_W5_DAY3.md`: subject·등록버전·compat레벨·프로브(호환 accept/비호환 reject)·PASS/FAIL 표. FAIL 시 원인 + 후속(정본 정렬 필요 여부).

**완료 기준(GATE 2):** 9 subject 전수 표 PASS(또는 FAIL 원인·후속 기록) + 산출물 커밋.

## 5. 워크스트림 C — API 문서

**서비스별 메커니즘 차이**: platform·engagement·knowledge·learning-card·gateway = Spring(SpringDoc `/v3/api-docs`+`/swagger-ui`). **learning-ai = Python/FastAPI**(네이티브 `/openapi.json`+`/docs`) — SpringDoc 아님.

**3단계:**

1. **Survey(실측, 읽기전용)** — e2e 스택 기동 상태에서 각 서비스 OpenAPI 엔드포인트 직접 호출:
   - Spring: `GET /v3/api-docs` 200 + 경로/스키마 노출 + Swagger UI.
   - FastAPI(learning-ai): `GET /openapi.json` 200 + `/docs`.
   - 판정: 노출 O / X / 부분(어노테이션 누락).
2. **gateway 라우팅 대조** — gateway 라우트 정의(`application*.yml` predicates) ↔ 각 서비스 OpenAPI 실재 엔드포인트 대조 → 대조표(라우트·대상서비스·선언경로·실재여부·OpenAPI노출).
3. **누락 → 레포별 상세 이슈**(`gh issue create`, 서비스 코드 직접 수정 X). 이슈 1건 = 1서비스. **구조(대단히 상세히):**
   - 제목: `docs(openapi): SpringDoc/OpenAPI 노출 보완 — <서비스> (W5 FR-TL-304)`
   - 배경/근거: FR-TL-304 + 대조 결과(증거: 호출 응답/상태코드)
   - 현재 상태: 무엇이 누락인지(의존성/설정/어노테이션/gateway 경유)
   - 정확한 변경 지점: 의존성(`springdoc-openapi-starter-webmvc-ui` 버전)·설정 클래스/yml 키·어노테이션 대상 컨트롤러·gateway 라우트 필요 시 경로
   - 검증(DoD): `/v3/api-docs` 200 + gateway 경유 200 + Swagger UI 렌더 + 주요 엔드포인트 N개 노출
   - 참조: 대조표 링크·본 스펙·정상 서비스 예시

**산출물** — `docs/reports/API_DOC_SURVEY_W5_DAY3.md`(survey+대조표) + 서비스별 이슈 URL 표.

**완료 기준(GATE 3):** 대조표 커밋 + 누락 서비스마다 이슈 발행(URL 표).

## 6. 검증·세션 산출물·이월

**세션 종료 산출물:**
- 코드: engagement A 머지(main).
- shared 커밋: 본 스펙, B 리포트, C 대조표, 신규 전수 러너 스크립트.
- 발행: 서비스별 API 문서 이슈.
- 추적 갱신: `WORKFLOW_team-lead_W5.md`(§3 Day3 체크박스), `HANDOFF_*`(D-004 Stage1 종결 + Day3 진척 + 이월).

**이월(명시):**
- 커버리지 80%(FR-ALL-303), SLA 풀측정 P3 검색·P4 체인·P6 AI(**F4 AI키 선결**)·P7 FCM.
- **이월 핵심**: A가 F10을 풀어 **P7 FCM 측정 선결 해제** → 다음 세션 즉시 측정 가능.
- C 이슈 머지(owner), B FAIL분 정본 정렬(있으면).

## 7. 리스크

- A 라이브 검증: e2e 스택 13서비스 기동 필요 → stale ZK 회피 위해 `down -v` 후 재기동.
- 비UUID tenant 시드 → platform 거부 → E2E 시드 UUID 정렬(A 플랜 §7).
- B: 레지스트리 미기동 시 전수 불가 → 선결 기동.
- 머지 실측: 모든 머지 확인은 `git fetch` 후 origin/main 기준(로컬 stale 오판 회피).
