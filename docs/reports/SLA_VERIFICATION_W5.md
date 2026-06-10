# SLA 검증 결과 — W5 (2026-06-10, Day3 종결)

> **기준 정의**: [SLA_VERIFICATION_W4](./SLA_VERIFICATION_W4.md) P1~P7 · **측정**: W5 Day2(P1/P2/P5) + Day3 라이브(P4/P5/W1) · e2e 스택(origin/main, engagement=D-004 Stage1 머지본)
> **요지**: 측정 가능분 **P1·P2·P4·P5 전부 충족** + **W1 풀체인 PASS**(A로 알림 leg 해소). P3·P6·P7은 외부/인프라 의존으로 보류(사유·이슈 명시).

## 결과 표

| 항목 | 목표 | 측정값 | 판정 | 근거 |
|---|---|---|---|---|
| **P1** API P95 | <200ms | 로그인 79.7ms · 신고 15.3ms | ✅ | W5 Day2 [E2E_W5_DAY2 §3.5](./E2E_W5_DAY2.md) |
| **P2** Kafka 홉 | <5s | ~1.42s (발행→소비→DB) | ✅ | W5 Day2 |
| **P3** 검색 | <2s | **측정 불가** | ⛔ 보류 | ES `analysis-nori` 미설치 → 인덱스 생성 실패 → 검색 500. [gitops#174](https://github.com/team-project-final/synapse-gitops/issues/174) |
| **P4** 체인 | <10s | **1.31s** (복습 발행→레벨업 audit, **알림 leg 포함**) | ✅ | Day3 라이브 실측 |
| **P5** audit 적재 | <30s | **1.31s** | ✅ | Day3 라이브(동일 체인) |
| **P6** AI 카드 | <30s | **측정 불가** | ⛔ 보류 | AI키 부재 → [learning#73](https://github.com/team-project-final/synapse-learning-svc/issues/73) (F4) |
| **P7** FCM 발송 | >95% | 경로 OK·실발송률 미측정 | 🟡 부분 | engagement→platform→FCM **skip 검증**(UUID.fromString 통과, DLT 0). 실 FCM 자격 부재로 발송률은 보류 |

## W1 풀체인 — ✅ PASS (Day3 종결)

복습→XP→레벨업→audit→**알림**. W5 Day2에 🔴(알림 leg 미배선)이던 시나리오를 **D-004 Stage1(F10) 머지로 종결**.

경계유저 UUID `11111111-1111-1111-1111-111111111111` / tenant `22222222-...`, `ReviewCompleted` 10건(10XP×10=100XP→레벨2):
1. **engagement XP/레벨업** — `user_profiles_gamification` total_xp=100·level=2, `xp_events` 10건/합100. 내부 PK=해시 Long(4091181416664085767), 외부 UUID 전파(D-004 Stage1).
2. **platform audit_logs** — `action=LEVEL_UP, user_id=11111111-…, new_value={newLevel:2,previousLevel:1,totalXp:100}` + BADGE_EARNED(FIRST_XP·LEVEL_2), 전부 UUID.
3. **알림(FCM skip)** — platform NotificationService: `FCM channel not configured - skipping for user 11111111-…` → `UUID.fromString` 통과(IllegalArgumentException 0). LevelUp NotificationSend가 UUID userId 적재.
4. **DLT 0** — `platform.notification.notification-send-v1.DLT` 미생성(0). notification-send 메인 토픽 소비 1건 정상.

## 보류 항목 사유 (owner/인프라)

- **P3 검색** — ES nori 플러그인 부재(로컬 e2e + EKS 둘 다 stock 이미지). knowledge 검색이 전 환경에서 500. → **gitops#174**(커스텀 ES 이미지). 해소 후 P3 즉시 재측정 가능.
- **P6 AI 카드** — AI키 미주입 + graceful 게이트 부재. → **learning#73**(F4).
- **P7 실 FCM 발송률** — FCM 자격 부재. 파이프라인 신뢰성(skip 경로·DLT 0)은 입증, 실 발송률은 자격 확보 후.

## 부수 관찰 (재확인)

- platform **audit 컨슈머**가 `ReviewCompleted`(raw Avro)를 처리 못 하고 `learning.card.review-completed-v1.DLT`로 적재(end offset 10) — INFO/WARN, ERROR 없음. **W1 타깃(level-up→audit→notification)과 무관**(별 토픽, lag 0). → [platform#87](https://github.com/team-project-final/synapse-platform-svc/issues/87) 가설 A(실결함) 쪽 정황 강화.

## 결론

오늘 종결: **P1·P2·P4·P5 충족 + W1 풀체인 PASS + platform 커버리지 baseline**([COVERAGE_BASELINE_W5](./COVERAGE_BASELINE_W5.md)). 보류 P3/P6/P7은 각각 gitops#174·learning#73·FCM자격으로 추적 — 발표(06-15) 데모 핵심 체인(W1)은 라이브 PASS.
