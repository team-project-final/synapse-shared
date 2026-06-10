# 핸드오프 — W5 Day2 종결 → Day3+ (다음 세션 진입점)

> **작성**: 2026-06-09 (W5 Day 2 종료) · **발표**: 06-15(월) · **이 문서 = 다음 세션 시작점**
> **상위 참조**: [HANDOFF_HUB](./HANDOFF_HUB.md) · [E2E_W5_DAY2](../reports/E2E_W5_DAY2.md) · [D-004](../designs/D-004_USER_IDENTITY_MODEL.md)

---

## 0. W5 Day3 종결 업데이트 (06-10) — A·B·C 완료

이 세션에서 3개 워크스트림 모두 완료·머지([설계](../superpowers/specs/2026-06-10-w5-day3-d004stage1-schema-apidocs-design.md)):

| | 내용 | 결과 | PR/이슈 |
|---|---|---|---|
| **A. D-004 Stage 1** | engagement outbound UUID 전파(F10 비파괴 해소) | ✅ **머지(main)** · 라이브 E2E PASS(복습→레벨업 → platform `UUID.fromString` 통과 + "FCM skip for user \<UUID>" + notification-send DLT 0) · 단위 67/0 | eng **#37→#38** (dev→main) |
| **B. Schema BACKWARD 전토픽** | 9 subject 강제 프로브 전수(cards-generated 포함) | ✅ **9/9 PASS** · `scripts/check-schema-backward-all.ps1` + [리포트](../reports/SCHEMA_BACKWARD_W5_DAY3.md) | shared **#34** |
| **C. API 문서** | 5서비스 OpenAPI survey + gateway 대조 + 누락 이슈 | ✅ 노출 O: engagement·learning-ai / 누락 3건 상세 이슈 발행 · [대조표](../reports/API_DOC_SURVEY_W5_DAY3.md) | shared **#35** · platform**#84**·knowledge**#67**·learning**#72** |

**주의/관찰(다음 세션):**
- **engagement dev 재생성**: 원격 dev가 릴리스 후 삭제돼 있어 main에서 dev 재생성 후 dev-first 적용(A는 #37 dev→#38 main). 이후 dev 상시 유지.

### Day3 closeout 추가 측정·종결 (owner 무관, 06-10)
[설계/플랜: [closeout-design](../superpowers/specs/2026-06-10-w5-day3-closeout-design.md) · [closeout plan](../superpowers/plans/2026-06-10-w5-day3-closeout.md)]
- **W1 풀체인 PASS** — 복습→XP→레벨업→audit→알림(FCM skip, UUID) 라이브 종결. W5 Day2 🔴(알림 미배선) 해소. [SLA_VERIFICATION_W5](../reports/SLA_VERIFICATION_W5.md)
- **SLA P1·P2·P4·P5 충족** — **P4 체인 1.31s**·**P5 audit 1.31s**(라이브 실측). 측정분 전부 PASS.
- **platform 커버리지 baseline** — line **92.4%(>80%)**. 타서비스 jacoco 미설정(owner 이월). [COVERAGE_BASELINE_W5](../reports/COVERAGE_BASELINE_W5.md)

### 미완료 owner 이슈 (전체 레포 실측 후 발행, 06-10)
- platform [#86](https://github.com/team-project-final/synapse-platform-svc/issues/86)(F8 admin role) · [#87](https://github.com/team-project-final/synapse-platform-svc/issues/87)(audit ReviewCompleted DLT, **Day3 라이브서 실재현 — 가설 A 강화**)
- learning [#73](https://github.com/team-project-final/synapse-learning-svc/issues/73)(F4 AI키 게이트→P6 차단) · knowledge [#68](https://github.com/team-project-final/synapse-knowledge-svc/issues/68)(dev→main 18커밋 미반영)
- **gitops [#174](https://github.com/team-project-final/synapse-gitops/issues/174)(ES analysis-nori 미설치 — 검색 전 환경 500 → P3 차단, 신규)**
- API 문서 갭: platform#84·knowledge#67·learning#72

### 다음 세션 보류(외부·인프라 의존)
- **P3 검색** — gitops#174(nori) 해소 후 즉시 측정. **P6 AI** — learning#73(키). **P7 실 FCM 발송률** — FCM 자격(경로·DLT 0은 입증). 커버리지 80% — 전 서비스 jacoco(owner).

---

## 1. 한 줄 현황 (Day2 시점, 참고)

W5 Day2에 **P0 2건(F1·F2/F3) + 신원 버그 2건(F7·F9) 수정·라이브 검증·머지 완료**, learning-ai #144(ssl_context)까지 해소. 핵심 미해결이던 **D-004 Stage 1**은 **Day3(06-10)에 구현·머지 완료**(§0).

## 2. Day2 완료분 (검증·머지됨)

| 발견 | 내용 | PR | 상태 |
|---|---|---|---|
| F1 | engagement UserRegistered 정본(registeredAt 제거) | eng#32→#36 | ✅ main |
| F2/F3 | learning-ai NotificationSend 정본(namespace+메타) | learning#64 | ✅ main |
| F7 | engagement HTTP/Kafka 신원 통합 | eng#33→#36 | ✅ main |
| F9 | knowledge 검색 인증(UUID→Long 폴백) | knowledge#59 | ✅ dev |
| #144 | learning-ai Kafka ssl_context 배선 | learning#67 | ✅ main+배포검증(1/1 Running) |

- **시나리오 라이브 PASS**: W4 가입→프로필 · W2 audit · W3 알림 발행/소비 · W5 신고접수 · W1 복습→XP→레벨업→audit
- **SLA 충족**: P1 API P95(<200ms) · P2 Kafka 홉(~1.4s) · P4 체인(~0.67s) · P5 audit(~0.7s)
- **Schema BACKWARD enforcement 입증**(강제 프로브: 비호환 거부/호환 허용)
- **gitops**: #20 수신확인+후속 · #31(봇 강화) 신설 · #155/#156/#157 operator 완료·close · #144 close

## 3. 다음 세션 작업 (우선순위 순)

### ✅ (Day3 완료) D-004 Stage 1 — engagement outbound UUID (F10 해소) — eng#37→#38 머지, 라이브 PASS. 아래는 이력.
- **플랜(확정)**: [2026-06-09-d004-stage1-engagement-uuid-outbound](../superpowers/plans/2026-06-09-d004-stage1-engagement-uuid-outbound.md)
- **핵심**: 소스 이벤트의 UUID(`UserRegistered.userId`/`ReviewCompleted.userId`)를 outbound(LevelUp/BadgeEarned/NotificationSend)까지 전파 → platform `NotificationService`의 `UUID.fromString` 통과. **PK·DB 무변경(비파괴)**.
- **블래스트 반경**: prod 5(`GamificationEventPublisher` 인터페이스·`GamificationKafkaProducer`·`NoopGamificationEventPublisher`·`GamificationService`·`EngagementKafkaEventHandler`+`GamificationController`) + 테스트 7(`GamificationKafkaProducerTests`·`GamificationKafkaAclSimulationTests`·`GamificationNotificationContractTests`·`GamificationStep6ServiceTests`·`GamificationStep7EventServiceTests`·`EngagementKafkaEventHandlerTests`·`GamificationControllerWebMvcTest`)
  - 시그니처 변경: `publishLevelUp`/`publishBadgeEarned` 첫 인자 `Long userId` → `String userId(UUID)`; `addXp`에 externalUserId(UUID) 추가
  - **HTTP addXp 경로 있음**(`GamificationController` POST /xp/events) → `jwt.getSubject()`(UUID) 전달 필요(CurrentUser에 subject 접근자 추가)
  - NotificationSend(LEVEL_UP) 재배선 = eng#34(Draft)를 본 작업으로 대체 후 close
- **워크플로**: 구현 → docker 빌드 전테스트 검증 → engagement **dev PR → merge → dev→main PR → merge** → Stage 2 착수
- **라이브 검증**: 경계유저(UUID 보유) 복습→레벨업 → platform notification consumer가 `UUID.fromString` 통과 + "FCM skip for user <UUID>" 로그, DLT 적재 0

### 🥈 합의 필요 (P1, owner 세션)
- **F8**: platform ADMIN role 발급 메커니즘 부재(`DEFAULT_USER_ROLES` 하드코딩 + users에 roles 컬럼 없음 + 명명 불일치 `ROLE_ADMIN` vs engagement `ADMIN`) → W5 관리자 모더레이션 차단. @platform 결정.
- **D-004 Stage 2**: engagement·knowledge 내부 PK `bigint → uuid` 전환 + 해시 도출(F7/F9 패치) 회수. dev/staging 시드 재생성 전제. @platform·@engagement·@knowledge 합의 후 별도 플랜.

### 🥇 (다음 세션 1순위) 커버리지 80% + SLA 풀측정
- **커버리지 80%**(FR-ALL-303): jacoco/coverage/flutter_test 종합 집계 조율(전 서비스).
- **SLA 풀측정**(FR-TL-301): P3 검색(F9 후) · P4 풀체인(레벨업+알림 leg — **A로 선결 해제**) · P6 AI(**F4 AI키 선결**) · P7 FCM>95%(**A로 선결 해제**). 3회 평균.

### 🥉 W5 잔여 일정
- **Day3**(06-10) **완료분**: ✅ API 문서(FR-TL-304, shared#35) · ✅ Schema BACKWARD 전토픽(FR-TL-302, shared#34) · ✅ D-004 Stage1(§0). **잔여**: 커버리지 80% · SLA 풀측정(위 🥇).
- **Day4**(06-11): staging 최종 배포 · Observability(ServiceMonitor/대시보드/알림) · 24h 안정
- **Day5**(06-12): 발표 슬라이드 · 데모 스크립트 · 리허설 → **발표 06-15(코드 동결)**

## 4. 환경·브랜치 상태

- **E2E 스택**: `docker compose -f docker-compose.yml -f docker-compose.e2e.yml`로 13서비스 기동 가능(origin/main worktree 실빌드). 이전 세션 기동분 잔존 시 stale ZK 회피 위해 `down -v` 후 재기동 권장.
- **worktree**: `../.e2e-worktrees/synapse-*`(origin/main detached). 코드 머지 후 재빌드 전 `git checkout origin/main` 새로고침 필요.
- **learning-ai**: dev 1/1 Running(이미지 `9140e597`, ssl_context fix).
- **미해결 PR/이슈**: shared#31(봇 강화, 추적) · eng#34(F10 draft → Stage 1로 대체 후 close).

## 5. 주의사항 (다음 세션 함정 회피)

- **식별자 모델**: platform=UUID 정본 / engagement·knowledge=해시 Long(단방향, 역산 불가). inbound는 해시 재도출로 OK, **outbound는 UUID 필요** — Stage 1의 전제.
- **bash 커밋 메시지**: `git commit -m @'...'@`는 bash에서 리터럴 `@`로 감싸져 제목이 깨짐 → **heredoc `git commit -F - <<'EOF'`** 사용.
- **main 머지**: 전 레포 main은 **리뷰 1건 필수**(REVIEW_REQUIRED). `enforce_admins=False`라 owner는 `gh pr merge --admin` 가능(작성자 셀프승인 불가). dev는 보호 약함.
- **머지 방식**: 전 레포 **squash only**(merge/rebase 비활성).
- **dev→main 괴리**: engagement는 main에 #23(S5)이 있고 dev엔 없는 등 분기 존재 → dev→main은 fast-forward 아닌 머지.
- **라이브 검증 우선**: F10은 green 단위테스트가 놓친 poison-message를 라이브가 잡음 — 신원/직렬화 변경은 **반드시 서비스 E2E 라이브 확인**.

## 6. 핵심 참조 문서
- E2E 결과·신원 종합: [E2E_W5_DAY2](../reports/E2E_W5_DAY2.md) (§3.6 식별자 모델)
- 식별자 설계: [D-004](../designs/D-004_USER_IDENTITY_MODEL.md)
- Stage 1 플랜: [2026-06-09-d004-stage1](../superpowers/plans/2026-06-09-d004-stage1-engagement-uuid-outbound.md)
- 전체 대시보드: [HANDOFF_HUB](./HANDOFF_HUB.md) · SLA: [SLA_VERIFICATION_W4](../reports/SLA_VERIFICATION_W4.md) · 일정: [W5_PLAN](./W5_PLAN.md)
