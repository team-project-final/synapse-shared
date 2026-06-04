# S6 — 감사 로그 다중 토픽 적재 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development 또는 superpowers:executing-plans. Steps use checkbox (`- [ ]`).
> **Target repo:** `synapse-platform-svc` (브랜치: 신규 `feat/audit-multi-topic`, base=dev). 구현은 platform-svc 레포에서 수행.

**Goal:** platform 감사 소비자를 `user-registered` 단일 토픽에서 전 도메인 상태변경 토픽으로 확장해 `audit_logs`에 적재한다.

**Architecture:** 기존 타입별 `@KafkaListener` 패턴(`AuditKafkaConsumer` + `AuditLogService.processEvent`) 확장. 이벤트별 `processEvent` 오버로드 + audit_logs 매핑. 단일 `auditKafkaListenerContainerFactory`(SpecificRecord) 재사용, 전용 그룹 `platform-audit-group`.

**Tech Stack:** Spring Boot, Spring Kafka, Avro, Confluent KafkaAvroDeserializer(specific.avro.reader), JPA, JUnit5.

**설계 근거:** `synapse-shared/docs/superpowers/specs/2026-06-04-w4-community-audit-events-design.md` §4.

**선행 사실(2026-06-04 실측):**
- `AuditLog.of(eventId:UUID, action:String, userId:UUID, resourceType:String, resourceId:String, value:String)` — 6인자. `audit_logs.event_id` **UNIQUE 이미 존재** + `processEvent`가 `DataIntegrityViolationException` catch → **멱등성 구현 완료**(추가 마이그레이션 불필요).
- `auditKafkaListenerContainerFactory` = `ConcurrentKafkaListenerContainerFactory<String,Object>` + `specific.avro.reader=true` → 모든 SpecificRecord 타입 한 팩토리로 처리.
- **userId 타입 불일치**: platform/knowledge/learning userId=UUID, **engagement(BadgeEarned/LevelUp) userId=Long 문자열** → `UUID.fromString` 불가 → 분기 처리 필요.
- 기존 listener는 `com.synapse.platform.UserRegistered`(platform 자체 namespace), group `platform-svc-group`.

---

## ⚠️ Task 0: 토픽명·스키마 확정 (R3 — 코드 전 필수)

**Files:** 읽기만 — 각 producer 레포

- [ ] **Step 1: 토픽명 확정** — EVENT_FLOW_MATRIX + 각 producer `synapse.kafka.topics`/`app.kafka.topics` 설정에서 실제 토픽명 확인:
  - note-created/updated (knowledge-svc), review-completed (learning-card), badge-earned/level-up (engagement).
  Run: `grep -rn 'topics:' synapse-knowledge-svc/src/main/resources synapse-learning-svc/learning-card/src/main/resources synapse-engagement-svc/src/main/resources`
- [ ] **Step 2: 스키마 위치 확정** — shared `src/main/avro/{knowledge,learning,engagement}/*.avsc`에서 NoteCreated/NoteUpdated/ReviewCompleted/BadgeEarned/LevelUp 파일·namespace·필드명(noteId/cardId/badgeId/userId) 확인. 매핑 표(아래 Task 3)와 대조.

---

## Task 1: cross-namespace Avro 스키마 편입

**Files:** Create `src/main/avro/{knowledge,learning,engagement}/*.avsc` (shared에서 복사)

- [ ] **Step 1: 5개 스키마 복사** — shared에서 platform `src/main/avro/`로 namespace 디렉터리 유지 복사:
  - `knowledge/NoteCreated.avsc`, `knowledge/NoteUpdated.avsc`, `learning/ReviewCompleted.avsc`, `engagement/BadgeEarned.avsc`, `engagement/LevelUp.avsc`.
  (의존 공통 타입/봉투가 있으면 함께 복사.)
- [ ] **Step 2: Avro 생성 확인** `./gradlew generateAvroJava` → BUILD SUCCESSFUL, `build/generated-main-avro-java/com/synapse/event/{knowledge,learning,engagement}/*.java` 생성.
- [ ] **Step 3: 커밋** `git add src/main/avro && git commit -m "feat(audit): 도메인 이벤트 Avro 스키마 5종 편입 (S6)"`

## Task 2: 토픽 설정

**Files:** Modify `src/main/resources/application.yml`

- [ ] **Step 1: app.kafka.topics에 추가** (Task 0에서 확정한 실제 토픽명으로):
```yaml
app:
  kafka:
    topics:
      user-registered: ${KAFKA_TOPIC_USER_REGISTERED:platform.auth.user-registered-v1}
      note-created: ${KAFKA_TOPIC_NOTE_CREATED:knowledge.note.note-created-v1}
      note-updated: ${KAFKA_TOPIC_NOTE_UPDATED:knowledge.note.note-updated-v1}
      review-completed: ${KAFKA_TOPIC_REVIEW_COMPLETED:learning.card.review-completed-v1}
      badge-earned: ${KAFKA_TOPIC_BADGE_EARNED:engagement.gamification.badge-earned-v1}
      level-up: ${KAFKA_TOPIC_LEVEL_UP:engagement.gamification.level-up-v1}
```
- [ ] **Step 2: 커밋** `git commit -am "feat(audit): 감사 대상 토픽 설정 추가 (S6)"`

## Task 3: AuditLogService 매핑 (이벤트별 processEvent)

**Files:**
- Modify `src/main/java/com/synapse/platform/audit/service/AuditLogService.java`
- Test: `src/test/java/com/synapse/platform/audit/service/AuditLogServiceTests.java`

**매핑 표**:
| 이벤트 | action | resource_type | resource_id | user_id |
|---|---|---|---|---|
| NoteCreated | NOTE_CREATED | NOTE | noteId | userId(UUID) |
| NoteUpdated | NOTE_UPDATED | NOTE | noteId | userId(UUID) |
| ReviewCompleted | REVIEW_COMPLETED | CARD | cardId | userId(UUID) |
| BadgeEarned | BADGE_EARNED | BADGE | badgeId | **null**(userId=Long→user_id 비움) |
| LevelUp | LEVEL_UP | USER | userId(Long 문자열) | **null** |

- [ ] **Step 1: 실패 테스트** — 각 이벤트 → 올바른 AuditLog 필드 매핑(repository mock, 캡처해 단언). 예:
```java
@Test
void mapsNoteCreated() {
    var event = NoteCreated.newBuilder()./*eventId,userId(UUID),noteId,...*/.build();
    service.processEvent(event);
    var captor = ArgumentCaptor.forClass(AuditLog.class);
    verify(repository).save(captor.capture());
    assertThat(captor.getValue().getAction()).isEqualTo("NOTE_CREATED");
    assertThat(captor.getValue().getResourceType()).isEqualTo("NOTE");
}
@Test
void badgeEarnedHasNullUserIdWhenNonUuid() {
    var event = BadgeEarned.newBuilder()./*userId="42"(Long 문자열)*/.build();
    service.processEvent(event);
    var captor = ArgumentCaptor.forClass(AuditLog.class);
    verify(repository).save(captor.capture());
    assertThat(captor.getValue().getUserId()).isNull();
    assertThat(captor.getValue().getResourceId()).isEqualTo("42");
}
```
- [ ] **Step 2: 실패 확인** `./gradlew test --tests '*AuditLogServiceTests*'` → FAIL.
- [ ] **Step 3: processEvent 오버로드 + UUID 안전 헬퍼 구현**
```java
// 비-UUID(engagement Long 문자열)면 null 반환 — audit_logs.user_id는 nullable UUID.
private UUID parseUuidOrNull(Object raw) {
    if (raw == null) return null;
    try { return UUID.fromString(raw.toString()); } catch (IllegalArgumentException e) { return null; }
}

public void processEvent(com.synapse.event.knowledge.NoteCreated e) {
    save(AuditLog.of(UUID.fromString(e.getEventId().toString()), "NOTE_CREATED",
        parseUuidOrNull(e.getUserId()), "NOTE", e.getNoteId().toString(), e.toString()));
}
public void processEvent(com.synapse.event.knowledge.NoteUpdated e) {
    save(AuditLog.of(UUID.fromString(e.getEventId().toString()), "NOTE_UPDATED",
        parseUuidOrNull(e.getUserId()), "NOTE", e.getNoteId().toString(), e.toString()));
}
public void processEvent(com.synapse.event.learning.ReviewCompleted e) {
    save(AuditLog.of(UUID.fromString(e.getEventId().toString()), "REVIEW_COMPLETED",
        parseUuidOrNull(e.getUserId()), "CARD", e.getCardId().toString(), e.toString()));
}
public void processEvent(com.synapse.event.engagement.BadgeEarned e) {
    save(AuditLog.of(UUID.fromString(e.getEventId().toString()), "BADGE_EARNED",
        parseUuidOrNull(e.getUserId()), "BADGE", e.getBadgeId().toString(), e.toString()));
}
public void processEvent(com.synapse.event.engagement.LevelUp e) {
    save(AuditLog.of(UUID.fromString(e.getEventId().toString()), "LEVEL_UP",
        parseUuidOrNull(e.getUserId()), "USER", e.getUserId().toString(), e.toString()));
}

private void save(AuditLog auditLog) {
    try { repository.save(auditLog); }
    catch (DataIntegrityViolationException ex) { log.info("Duplicate event skipped"); } // 멱등(event_id UNIQUE)
}
```
> 필드 접근자(getNoteId/getCardId/getBadgeId/getUserId)는 Task 0/1의 실제 .avsc 필드명에 맞춘다. 기존 `processEvent(UserRegistered)`도 `save(...)` 헬퍼로 정리(중복 catch 제거).
- [ ] **Step 4: 테스트 통과** `./gradlew test --tests '*AuditLogServiceTests*'` → PASS.
- [ ] **Step 5: 커밋** `git commit -am "feat(audit): 도메인 이벤트별 audit_logs 매핑 + UUID 안전 처리 (S6)"`

## Task 4: AuditKafkaConsumer 리스너 추가

**Files:** Modify `src/main/java/com/synapse/platform/audit/consumer/AuditKafkaConsumer.java`

- [ ] **Step 1: 토픽별 @KafkaListener 추가** (전용 그룹 `platform-audit-group`, 기존 팩토리 재사용)
```java
@KafkaListener(topics = "${app.kafka.topics.note-created}", groupId = "platform-audit-group",
        containerFactory = "auditKafkaListenerContainerFactory")
public void consumeNoteCreated(com.synapse.event.knowledge.NoteCreated event) { auditLogService.processEvent(event); }

@KafkaListener(topics = "${app.kafka.topics.note-updated}", groupId = "platform-audit-group",
        containerFactory = "auditKafkaListenerContainerFactory")
public void consumeNoteUpdated(com.synapse.event.knowledge.NoteUpdated event) { auditLogService.processEvent(event); }

@KafkaListener(topics = "${app.kafka.topics.review-completed}", groupId = "platform-audit-group",
        containerFactory = "auditKafkaListenerContainerFactory")
public void consumeReviewCompleted(com.synapse.event.learning.ReviewCompleted event) { auditLogService.processEvent(event); }

@KafkaListener(topics = "${app.kafka.topics.badge-earned}", groupId = "platform-audit-group",
        containerFactory = "auditKafkaListenerContainerFactory")
public void consumeBadgeEarned(com.synapse.event.engagement.BadgeEarned event) { auditLogService.processEvent(event); }

@KafkaListener(topics = "${app.kafka.topics.level-up}", groupId = "platform-audit-group",
        containerFactory = "auditKafkaListenerContainerFactory")
public void consumeLevelUp(com.synapse.event.engagement.LevelUp event) { auditLogService.processEvent(event); }
```
> 기존 `consume(UserRegistered)`는 그대로 유지(group `platform-svc-group`). 일관성을 원하면 `platform-audit-group`으로 통일 가능하나 offset 리셋 고려 — 본 작업 범위 밖(선택).
- [ ] **Step 2: 커밋** `git commit -am "feat(audit): 도메인 토픽 5종 @KafkaListener 추가 (platform-audit-group) (S6)"`

## Task 5: 소비자 통합 테스트 (Testcontainers)

**Files:** Test `src/test/java/com/synapse/platform/audit/AuditConsumerIntegrationTest.java`

- [ ] **Step 1: 통합 테스트** — 기존 Kafka+SR Testcontainers 테스트 패턴이 있으면 재사용. 각 토픽으로 이벤트 produce → `audit_logs` 행 1건 적재 확인. 멱등성: 동일 event_id 2회 produce → 1행.
```java
// 예: note-created produce → await → repository.findByAction("NOTE_CREATED") size 1; 재produce(같은 eventId) → 여전히 1
```
- [ ] **Step 2: 통과 + 커밋** `./gradlew test --tests '*AuditConsumerIntegrationTest*'` → PASS. (Testcontainers 환경 부재 시 단위 매핑 테스트로 대체하고 통합은 로컬/CI에 위임 — 이유 기록.)

## Task 6: 빌드 + PR

- [ ] **Step 1: 전체 빌드** `./gradlew clean build` → BUILD SUCCESSFUL.
- [ ] **Step 2: 푸시 + dev PR**
```bash
git push -u origin feat/audit-multi-topic
gh pr create --repo team-project-final/synapse-platform-svc --base dev --head feat/audit-multi-topic \
  --title "feat(audit): 도메인 이벤트 다중 토픽 → audit_logs (S6)" --body "설계 spec 2026-06-04-w4-community-audit-events-design §4. 타입별 리스너 5종 + 매핑, platform-audit-group, UUID 안전 처리. 멱등성은 기존 event_id UNIQUE 재사용. 전송/스케줄 토픽 제외."
```

## Self-Review (작성자 체크)
- Spec §4 커버: 매핑 표(Task3)·타입별 리스너(Task4)·Avro 의존(Task1)·전용 그룹(Task4)·멱등(기존 재사용, Task3 save 헬퍼) ✓. 제외 토픽(notification-send/card-review-due) 미구독 ✓.
- 미해결: 토픽명·필드 접근자명(Task0/1에서 실제 .avsc 대조 확정). engagement userId=Long → user_id=null 매핑(Task3 parseUuidOrNull). 기존 user-registered 그룹 통일은 선택(offset 고려).
