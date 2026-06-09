# 구현 플랜 — D-004 Stage 1: engagement outbound UUID (F10 비파괴 해소)

> **근거**: [D-004 §5](../../designs/D-004_USER_IDENTITY_MODEL.md) 2단계 권고 — 단기 Option-2. **상태**: ✅ 확정(2026-06-09, 사용자 승인) — **구현은 전용 세션에서 진행 예정**
> **착수 시 선행**: ① prod 5파일(인터페이스·producer·noop·service·핸들러/컨트롤러) + 테스트 7파일(ProducerTests·AclSimulation·NotificationContract·Step6/Step7Service·HandlerTests·ControllerWebMvc) 일괄 수정 ② docker 빌드 전테스트 검증 ③ dev PR→merge→main PR→merge. 블래스트 반경 큼 — 집중 세션 권장.
> **범위**: engagement 단독, **비파괴**(내부 PK Long 유지, outbound 이벤트만 UUID화). knowledge/platform 무변경.
> **목표**: 레벨업·배지 알림(outbound)이 platform이 요구하는 **UUID userId**를 싣게 해 F10 해소. (platform `NotificationService`는 `UUID.fromString(userId/tenantId/eventId)` 강제)

---

## 0. 핵심 통찰

- 소스 이벤트(`UserRegistered.userId`·`ReviewCompleted.userId`)는 **이미 platform UUID**(정본 avsc doc 확인).
- 현재 engagement는 이를 `resolveUserId` 해시 → Long으로 변환 후 outbound 이벤트에 `String.valueOf(Long)`을 실어 보냄 → platform UUID.fromString 실패(F10).
- **해결**: 내부 처리(XP/프로필 PK)는 Long 유지하되, **원본 UUID를 outbound 이벤트까지 전파**해 그대로 싣는다. 스키마/PK 변경 없음 → 비파괴.

## 1. 변경 대상

### 1-1. 신원 전파 (Long 옆에 UUID 동반)
| 파일 | 변경 |
|---|---|
| `GamificationService.addXp(...)` | 시그니처에 **외부 userId(UUID 문자열)** 추가 — 내부 Long은 그대로 쓰되, levelup/badge 발행 시 UUID를 넘김 |
| `EngagementKafkaEventHandler.handleReviewCompleted` | `event.getUserId()`(UUID)를 addXp에 전달 |
| `GamificationEventPublisher` 인터페이스 | `publishLevelUp`/`publishBadgeEarned`에 **externalUserId(UUID)** 파라미터 추가 |
| `GamificationKafkaProducer` | LevelUp/BadgeEarned `setUserId(externalUserId)` (Long→UUID) + **NotificationSend(LEVEL_UP) 재배선**(F10), 모두 UUID userId·UUID tenantId 사용 |
| `NoopGamificationEventPublisher` | 시그니처 정합 |

### 1-2. HTTP XP 경로 (있으면)
- `GamificationController`에 HTTP addXp 경로가 있으면, `CurrentUser`에 **subject(UUID) 접근자** 추가(`requireWithSubject` 또는 `subject(jwt)`) → addXp에 UUID 전달. *(선행 확인: 현재 XP는 Kafka 전용으로 보임 — 구현 착수 시 grep 재확인)*

### 1-3. tenantId
- outbound `tenantId`도 platform이 `UUID.fromString` → 소스 이벤트의 tenantId(UUID)를 그대로 전파(현재도 전파하나 값이 UUID인지 확인). 비UUID 테넌트 유입 시 방어 로깅.

## 2. 비변경 (Stage 2로 이월)
- `user_profiles_gamification.user_id` bigint **유지**(PK 전환은 Stage 2).
- `CurrentUser.resolveUserId` 해시 도출 **유지**(inbound 인증 F7 패치 그대로).

## 3. 테스트
- `GamificationKafkaProducerTests`: LevelUp/BadgeEarned/NotificationSend의 `userId`가 **전달한 UUID와 동일**한지 단언(현 `"80"` Long-문자열 단언 → UUID로 갱신).
- `GamificationKafkaAclSimulationTests`: 4번째 토픽(notification-send) + UUID userId 반영.
- 신규: handleReviewCompleted(UUID) → 레벨업 시 outbound 이벤트 userId=UUID 통합 테스트.
- 회귀: 내부 XP/레벨 계산(Long PK)·멱등성 불변.

## 4. 라이브 검증 (서비스 E2E)
- 경계유저(가입 UUID 보유) 복습 → 레벨업 → **platform notification consumer가 `UUID.fromString` 통과 + "FCM skip for user <UUID>"** 로그(F10 해소 입증). DLT 적재 0.

## 5. 전달 워크플로 (사용자 지정)
```
구현(Stage 1) → engagement dev PR → merge(dev) → dev→main PR → merge(main) → 진행(Stage 2 착수)
```
- F10 재배선이므로 engagement#34(Draft)는 본 작업으로 대체 후 close.

## 6. Stage 2 (이월, 별도 플랜)
- engagement·knowledge 내부 PK `bigint → uuid` 마이그레이션 + 해시 도출 제거(F7/F9 패치 회수). dev/staging 시드 재생성 전제. owner 합의 후 별도 플랜으로 분기.

## 7. 리스크 / 오픈 질문
- **순서 의존**: 가입(UserRegistered) 전에 복습(ReviewCompleted)으로 레벨업 시에도 UUID는 ReviewCompleted.userId에서 직접 오므로 OK(프로필 생성과 무관). 
- **비UUID tenant 유입**: 테스트/시드가 비UUID tenant면 platform이 거부 — E2E 시드를 UUID tenant로 정렬.
- HTTP addXp 경로 존재 여부 → 착수 시 확정.
