# D-004 — 사용자 식별자 정본 통일 (UUID) — **초안 (owner 합의 대기)**

> **상태**: 🟡 초안 — @platform·@engagement·@knowledge 합의 필요 (결정 미확정)
> **작성**: 2026-06-09 (W5 Day 2) · **작성자**: @team-lead
> **근거**: [E2E_W5_DAY2 §3.6](../reports/E2E_W5_DAY2.md) (F7·F8·F9·F10 라이브 검증)
> **영향 서비스**: platform · engagement · knowledge (learning은 userId를 그대로 전달만 함)

---

## 1. 문제

W5 Day2 E2E에서 발견한 신원 관련 결함 4건(F7·F8·F9·F10)은 **단일 근본 원인**으로 수렴한다:
**사용자 식별자 정본이 서비스마다 다르다.**

- **platform**: 사용자 정본 = **UUID** (`users.id`, JWT `subject`, 이벤트 `userId`, `NotificationSend.userId`)
- **engagement·knowledge**: 내부 식별자 = **Long(bigint)** — platform UUID를 `UUID.nameUUIDFromBytes(uuid).getMostSignificantBits() & Long.MAX_VALUE`로 **단방향 해시**

단방향이라 **Long → UUID 복원이 불가능**하다. 이 비대칭이 inbound(인증)에서는 봉합되지만 outbound(알림)에서는 깨진다.

## 2. 실측 (2026-06-09, 서비스 단위 E2E)

| ID | 방향 | 증상 | 현재 상태 |
|----|------|------|----------|
| **F7** | inbound | engagement 인증 API가 platform JWT(UUID subject) 거부(숫자 요구) | ✅ 패치(UUID→해시 재도출, engagement#33) |
| **F9** | inbound | knowledge 검색이 platform JWT(UUID subject) 거부 | ✅ 패치(동일 해시, knowledge#59) |
| **F8** | — | platform이 ADMIN role 자체를 발급 안 함(식별자와 별개 role 모델 부재) | 🔴 미해소 |
| **F10** | **outbound** | engagement가 레벨업 알림 발행 → platform `NotificationService`가 `UUID.fromString(userId)` 강제 → **해시 Long은 UUID 아님 → consumer 무한 재시도** | 🔴 미해소(engagement#34 Draft) |

> inbound 3건은 "UUID를 받아 같은 해시로 내부 Long 도출"로 통과. **F10(outbound)은 해시 Long에서 UUID를 만들 수 없어 패치 불가** — 해시 우회의 방향성 한계가 드러난 지점.

## 3. 현재 식별자 흐름

```
platform: users.id = UUID(gen_random_uuid) ── JWT subject=UUID ── 이벤트 userId=UUID
   │ UserRegistered(userId=UUID)
   ▼
engagement: resolveUserId(UUID) = nameUUIDFromBytes 해시 → Long  ← 단방향, UUID 폐기
   │ user_profiles_gamification.user_id = bigint
   │ LevelUp.userId = String.valueOf(Long)   ← 더 이상 UUID 아님
   ▼
platform NotificationService: UUID.fromString(userId)  ✗ 실패
```

knowledge도 동일: `notes.user_id`=bigint, JWT UUID를 해시해 사용.

**핵심**: engagement·knowledge가 UserRegistered의 UUID를 **저장하지 않고 즉시 해시·폐기**한다. 그래서 platform으로 되돌려 보낼 UUID가 없다.

## 4. 선택지

### Option 1 — 전 서비스 UUID 정본 통일 (✅ 권고)
사용자 식별자를 **모든 서비스에서 UUID**로 정본화. engagement·knowledge가 `user_id`를 UUID로 보관하고 이벤트에도 UUID를 싣는다.
- **장점**: 단일 정본, 양방향 무손실, F7/F9 해시 패치 제거, F10 자연 해소, 멀티테넌트/audit 상관관계 정합.
- **단점**: engagement·knowledge 스키마 마이그레이션(bigint → uuid) + 기존 데이터 변환 필요. 가장 큰 변경.

### Option 2 — 이벤트에 UUID 동반(dual identity, 부분 채택 가능)
내부 PK는 Long 유지하되, **이벤트·저장에 platform UUID를 함께 보존**(`userExternalId` 컬럼/필드). outbound 시 UUID 사용.
- **장점**: PK 마이그레이션 회피, 변경 최소. F10만 우선 해소 가능.
- **단점**: 식별자 이원화 지속(Long+UUID 동기 부담), 근본 정합 아님. 누락 시 재발.

### Option 3 — platform이 Long↔UUID 매핑 테이블 (기각/보조)
platform이 해시 Long↔UUID 매핑 보관, 수신 시 역매핑.
- **단점**: 해시 충돌 가능성, platform이 타 서비스 내부식별자에 결합, 복잡도↑. 보조 수단으로도 비권장.

### Option 4 — 현행(해시 Long) 유지 (기각)
- outbound 알림(레벨업·배지 등) 전반 불가. F10 영구 미해소. 기각.

## 5. 권고 (초안)

- **목표 정본 = Option 1 (UUID 통일)**. 단 일시 마이그레이션 부담이 크므로 **2단계**:
  1. **단기(F10 해소)**: Option 2로 engagement가 UserRegistered의 UUID를 보존(`user_profiles_gamification.external_user_id UUID` 추가 + 컬럼 채움) → LevelUp/NotificationSend에 UUID 탑재. F10·outbound 즉시 해소.
  2. **중기(정합)**: Option 1로 내부 PK까지 UUID 전환, 해시 도출(F7/F9 패치) 제거.
- **F8(role)**: 식별자와 별개 트랙 — platform에 role 발급(users.roles 또는 user_roles) + claim 규칙(`ROLE_ADMIN`↔engagement `ADMIN`) 합의. 본 문서 범위 밖이나 동일 인증 합의 세션에서 함께 결정 권고.

> ⚠️ 본 §5는 **제안**이다. UUID PK 전환은 platform 외 서비스의 도메인/마이그레이션 결정이므로 **각 owner 합의 후 확정**한다.

## 6. 영향 / 변경 범위 (Option 1 기준)

| 서비스 | 변경 | 마이그레이션 |
|--------|------|------------|
| platform | 변경 거의 없음(이미 UUID 정본). NotificationService 그대로 | — |
| engagement | `user_profiles_gamification.user_id` bigint→uuid, `xp_events`/`reports.reporter_id` 등 FK, `CurrentUser.resolveUserId`/`EngagementKafkaEventHandler.resolveUserId` 해시 제거, LevelUp/BadgeEarned/NotificationSend.userId=UUID | bigint→uuid 변환(기존 Long은 해시라 원본 UUID 복원 불가 → **개발/E2E 데이터는 폐기 후 재생성** 전제) |
| knowledge | `notes.user_id` bigint→uuid, `CurrentUserArgumentResolver` 해시 제거 | 동일 |
| learning | userId 전달만 — 영향 없음(UUID 그대로 패스스루) | — |
| shared (avsc) | userId 필드 의미를 "UUID 문자열"로 문서화(타입은 string 유지) | — |

### 마이그레이션 주의
- 기존 해시 Long은 **원본 UUID로 역산 불가** → 운영 데이터 이관 시 platform `users`와 조인 가능한 매핑이 없으면 손실. **dev/staging은 시드 재생성 전제**, prod 데이터가 있다면 platform 측 사용자 기준 재매핑 절차 별도 설계 필요.

## 7. 미해결 질문 (합의 항목)

- [ ] 내부 PK까지 UUID로 갈지(Option 1) vs 이벤트/외부식별자만 UUID(Option 2 단기) — 각 서비스 owner 판단
- [ ] 마이그레이션 시점(W5 내 vs W5 이후) — 발표(06-15) 전 범위 결정
- [ ] F8 role 모델을 본 트랙과 함께 결정할지
- [ ] shared `NotificationSend`/`LevelUp` 등 userId 필드에 "UUID" 제약을 doc/검증으로 명시할지

> **다음 단계**: 본 초안을 인증/식별자 합의 세션(@platform·@engagement·@knowledge)에 상정 → 결정 확정 후 D-004 상태를 ✅로 갱신하고 서비스별 구현 플랜 분기.
