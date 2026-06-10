# SLA 검증 결과 — W5 (2026-06-10, Day3 종결)

> **기준 정의**: [SLA_VERIFICATION_W4](./SLA_VERIFICATION_W4.md) P1~P7 · **측정**: W5 Day2(P1/P2/P5) + Day3 라이브(P4/P5/W1) · e2e 스택(origin/main, engagement=D-004 Stage1 머지본)
> **요지**: **P1·P2·P4·P5·P7 충족** + **W1 풀체인 PASS**(A로 알림 leg 해소). P3 레이턴시 PASS(기능검색 잔여)·P6은 owner 체인 갭으로 보류(사유·이슈 명시).

## 결과 표

| 항목 | 목표 | 측정값 | 판정 | 근거 |
|---|---|---|---|---|
| **P1** API P95 | <200ms | 로그인 79.7ms · 신고 15.3ms | ✅ | W5 Day2 [E2E_W5_DAY2 §3.5](./E2E_W5_DAY2.md) |
| **P2** Kafka 홉 | <5s | ~1.42s (발행→소비→DB) | ✅ | W5 Day2 |
| **P3** 검색 | <2s | **0.012s**(직접)/0.021s(gw) | 🟡 레이턴시 PASS·기능 미완 | **nori 해결**(커스텀 ES 이미지, `notes-v1` korean_nori 생성, 검색 200·0.012s≪2s, [gitops#174]). **단 결과 0건** — note→ES 인덱서 컨슈머 미등록([knowledge#71](https://github.com/team-project-final/synapse-knowledge-svc/issues/71)), 청킹 pgvector([knowledge#72](https://github.com/team-project-final/synapse-knowledge-svc/issues/72)) |
| **P4** 체인 | <10s | **1.31s** (복습 발행→레벨업 audit, **알림 leg 포함**) | ✅ | Day3 라이브 실측 |
| **P5** audit 적재 | <30s | **1.31s** | ✅ | Day3 라이브(동일 체인) |
| **P6** AI 카드 | <30s | **측정 불가(FAIL)** | ⛔ 보류 | 실키 주입·인증 OK이나 체인 다중 갭: deckId([knowledge#74](https://github.com/team-project-final/synapse-knowledge-svc/issues/74))·note본문 계약([learning#78](https://github.com/team-project-final/synapse-learning-svc/issues/78))·**Anthropic 모델ID 폐기**([learning#77](https://github.com/team-project-final/synapse-learning-svc/issues/77))·OpenAI 폴백 할당량0(사용자 키). F4 키([learning#73])는 필요했으나 불충분 |
| **P7** FCM 발송 | >95% | **10/10 = 100%** | ✅ | 실 웹 등록 토큰(브라우저 자동 발급) 등록 → NotificationSend 10건 → FCM 전건 accept(notifications SENT 10/0, DLT 0). SA synapse-fcm 정상·`sendEachForMulticast` 1/1 succeeded |

## W1 풀체인 — ✅ PASS (Day3 종결)

복습→XP→레벨업→audit→**알림**. W5 Day2에 🔴(알림 leg 미배선)이던 시나리오를 **D-004 Stage1(F10) 머지로 종결**.

경계유저 UUID `11111111-1111-1111-1111-111111111111` / tenant `22222222-...`, `ReviewCompleted` 10건(10XP×10=100XP→레벨2):
1. **engagement XP/레벨업** — `user_profiles_gamification` total_xp=100·level=2, `xp_events` 10건/합100. 내부 PK=해시 Long(4091181416664085767), 외부 UUID 전파(D-004 Stage1).
2. **platform audit_logs** — `action=LEVEL_UP, user_id=11111111-…, new_value={newLevel:2,previousLevel:1,totalXp:100}` + BADGE_EARNED(FIRST_XP·LEVEL_2), 전부 UUID.
3. **알림(FCM skip)** — platform NotificationService: `FCM channel not configured - skipping for user 11111111-…` → `UUID.fromString` 통과(IllegalArgumentException 0). LevelUp NotificationSend가 UUID userId 적재.
4. **DLT 0** — `platform.notification.notification-send-v1.DLT` 미생성(0). notification-send 메인 토픽 소비 1건 정상.

## 보류 항목 사유 (owner/인프라)

- **P3 검색** — **nori 부분 해소**(06-10): shared 커스텀 ES 이미지(`docker/elasticsearch/Dockerfile`, `analysis-nori`)로 로컬 e2e 인덱스 생성·검색 200·**레이턴시 0.012s≪2s** 확인. EKS는 gitops#174(ECR 커스텀 이미지) 잔여. **기능 검색(결과>0)은 knowledge owner 잔여**: 인덱서 컨슈머 미등록(#71)·청킹 pgvector(#72).
- **P6 AI 카드** — 실 AI키 주입(06-10)·Anthropic 인증 OK 확인. 단 **체인 4중 갭**으로 카드 생성 0: ① deckId(knowledge#74) ② note 본문 fetch 계약 불일치(learning#78, 500→DLQ) ③ Anthropic 모델ID 폐기(learning#77, 404) ④ OpenAI 폴백 할당량0(사용자 키 빌링). 모델ID(#77) 교체가 최단 해소 — 이후 deckId·note계약까지 풀려야 풀체인 P6 측정.
- **P7 FCM — ✅ 충족(06-10)**: SA(synapse-fcm) 주입(`docker-compose.fcm.yml`) + **실 웹 등록 토큰 발급**(Playwright headed+persistent context로 Firebase getToken 자동화, `secrets/fcm-web/`) → 등록 후 NotificationSend 10건 → **FCM 전건 accept(10/10=100%, SENT 10/0, DLT 0)**. 부가(경미): `NotificationService`가 batch 부분실패에도 status=SENT 기록 — platform 후속(별 트리아지).

## 부수 관찰 (재확인)

- platform **audit 컨슈머**가 `ReviewCompleted`(raw Avro)를 처리 못 하고 `learning.card.review-completed-v1.DLT`로 적재(end offset 10) — INFO/WARN, ERROR 없음. **W1 타깃(level-up→audit→notification)과 무관**(별 토픽, lag 0). → [platform#87](https://github.com/team-project-final/synapse-platform-svc/issues/87) 가설 A(실결함) 쪽 정황 강화.

## 결론

종결: **P1·P2·P4·P5·P7 충족 + W1 풀체인 PASS + platform 커버리지 baseline**([COVERAGE_BASELINE_W5](./COVERAGE_BASELINE_W5.md)). 잔여: **P3 기능검색**(knowledge#71/#72·nori EKS gitops#174) · **P6 AI**(knowledge#74·learning#77/#78·OpenAI 할당량). 발표(06-15) 데모 핵심 체인(W1)·알림(P7)·SLA 대부분 라이브 PASS.
