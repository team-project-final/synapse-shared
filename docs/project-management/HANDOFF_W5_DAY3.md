# 핸드오프 — W5 Day2 종결 → Day3+ (다음 세션 진입점)

> **작성**: 2026-06-09 (W5 Day 2 종료) · **발표**: 06-15(월) · **이 문서 = 다음 세션 시작점**
> **상위 참조**: [HANDOFF_HUB](./HANDOFF_HUB.md) · [E2E_W5_DAY2](../reports/E2E_W5_DAY2.md) · [D-004](../designs/D-004_USER_IDENTITY_MODEL.md)

---

## 1. 한 줄 현황

W5 Day2에 **P0 2건(F1·F2/F3) + 신원 버그 2건(F7·F9) 수정·라이브 검증·머지 완료**, learning-ai #144(ssl_context)까지 해소. 핵심 미해결은 **사용자 식별자 모델 통일(D-004)** 한 갈래로 수렴 — **Stage 1 구현이 다음 세션 1순위**.

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

### 🥇 D-004 Stage 1 구현 — engagement outbound UUID (F10 해소)
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

### 🥉 W5 잔여 일정
- **Day3**(06-10): 커버리지 80% · API 문서(SpringDoc) · SLA 잔여(P3 검색·P6 AI — F4 AI키 선결) · Schema BACKWARD 전 토픽(미발행 토픽 포함 전수)
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
