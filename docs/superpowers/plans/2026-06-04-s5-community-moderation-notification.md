# S5 — 커뮤니티 모더레이션 알림 발행 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development 또는 superpowers:executing-plans. Steps use checkbox (`- [ ]`).
> **Target repo:** `synapse-engagement-svc` (브랜치: 신규 `feat/community-moderation-notification`, base=dev). 본 플랜 파일은 shared에 위치하나 **구현은 engagement-svc 레포**에서 수행.

**Goal:** engagement 커뮤니티 신고 모더레이션 결정 시 `platform.notification.notification-send-v1`로 `NotificationSend`를 발행해 신고자·피신고자에게 알림이 가도록 한다.

**Architecture:** 기존 gamification 발행 패턴(인터페이스 + `@ConditionalOnProperty` Kafka 구현 + Noop)을 미러링. `ModerationService.moderate()` 커밋 후 best-effort 발행. 계약 = shared `NotificationSend.avsc`(plain SpecificRecord, KafkaAvroSerializer).

**Tech Stack:** Spring Boot, Spring Kafka, Avro(`com.github.davidmc24.gradle.plugin.avro`), Confluent KafkaAvroSerializer, JUnit5/Mockito.

**설계 근거:** `synapse-shared/docs/superpowers/specs/2026-06-04-w4-community-audit-events-design.md` §3.

**선행 사실(2026-06-04 실측):**
- engagement userId = `Long`(gamification은 `String.valueOf(userId)`로 발행). `Report`에 tenantId 없음 → CurrentTenant에서 전달.
- `Report`: reporterId(Long), targetType(USER/SHARED_DECK/SHARED_NOTE/STUDY_GROUP), targetId(Long). **USER 타입은 targetId가 곧 피신고자 userId**. 그 외는 owner 조회 필요.
- `ModerationService.moderate(reportId, request)`: APPROVED(hideTarget+approve) / REJECTED(reject). `synapse.kafka.enabled=${KAFKA_ENABLED:false}`, topics `synapse.kafka.topics.{level-up,badge-earned}`.

---

## ⚠️ Task 0: 계약 검증 (R1 — 코드 작성 전 필수)

**Files:** 읽기만 — `synapse-platform-svc` `.../notification` consumer

- [ ] **Step 1: platform NotificationKafkaConsumer 기대 타입·토픽 확인**

Run(platform 레포): `grep -rn '@KafkaListener\|NotificationSend\|notification-send\|consume(' synapse-platform-svc/src/main/java/com/synapse/platform/notification/`
Expected: 소비자가 **plain `NotificationSend` SpecificRecord**를 구독하는 토픽명 확인. 봉투 래핑(CloudEvent bytes)이면 발행도 동일 래핑 필요 — 발견 시 Task 3 구현을 그 형식에 맞춤. 토픽명을 메모(보통 `platform.notification.notification-send-v1`).
- [ ] **Step 2: NotificationSend.avsc 필드 확정** — `synapse-shared/src/main/avro/platform/NotificationSend.avsc`(userId,tenantId,notificationType,channels[],title,body,emailSubject?,emailHtmlBody?,data{map}). platform 소비자가 같은 스키마를 쓰는지 대조.

---

## Task 1: NotificationSend Avro 스키마 편입

**Files:**
- Create: `src/main/avro/platform/NotificationSend.avsc` (shared에서 복사)

- [ ] **Step 1: 스키마 복사** — shared `src/main/avro/platform/NotificationSend.avsc`를 engagement `src/main/avro/platform/NotificationSend.avsc`로 동일 복사(namespace `com.synapse.event.platform` 유지).
- [ ] **Step 2: Avro 생성 확인**

Run: `./gradlew generateAvroJava`
Expected: BUILD SUCCESSFUL. `build/generated-main-avro-java/com/synapse/event/platform/NotificationSend.java` 생성.
- [ ] **Step 3: 커밋** `git add src/main/avro/platform/NotificationSend.avsc && git commit -m "feat(community): NotificationSend Avro 스키마 편입 (S5)"`

## Task 2: notification-send 토픽 설정

**Files:** Modify `src/main/resources/application.yml`

- [ ] **Step 1: topics에 notification-send 추가** — `synapse.kafka.topics` 블록(level-up/badge-earned 아래)에:
```yaml
      notification-send: ${KAFKA_TOPIC_NOTIFICATION_SEND:platform.notification.notification-send-v1}
```
- [ ] **Step 2: 커밋** `git commit -am "feat(community): notification-send 토픽 설정 (S5)"`

## Task 3: 발행 컴포넌트 (gamification 패턴)

**Files:**
- Create: `src/main/java/com/synapse/engagement/community/application/event/CommunityNotificationPublisher.java`
- Create: `.../event/NoopCommunityNotificationPublisher.java`
- Create: `.../event/CommunityNotificationKafkaProducer.java`
- Test: `src/test/java/com/synapse/engagement/community/application/event/CommunityNotificationKafkaProducerTests.java`

- [ ] **Step 1: 인터페이스 작성** (`CommunityNotificationPublisher.java`)
```java
package com.synapse.engagement.community.application.event;

public interface CommunityNotificationPublisher {
    /** 모더레이션 결과 알림 1건 발행. recipientUserId/tenantId/유형/제목/본문. */
    void publishModerationNotification(
            Long recipientUserId, String tenantId, String notificationType,
            String title, String body, java.util.Map<String, String> data);
}
```
- [ ] **Step 2: Noop 작성** (Kafka off 기본값)
```java
package com.synapse.engagement.community.application.event;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import java.util.Map;

@Component
@ConditionalOnProperty(prefix = "synapse.kafka", name = "enabled", havingValue = "false", matchIfMissing = true)
class NoopCommunityNotificationPublisher implements CommunityNotificationPublisher {
    @Override
    public void publishModerationNotification(Long recipientUserId, String tenantId, String notificationType,
                                             String title, String body, Map<String, String> data) {
        // Kafka 비활성(dev/test 기본값) 시 비즈니스 로직만 수행한다.
    }
}
```
- [ ] **Step 3: 실패 테스트** (`CommunityNotificationKafkaProducerTests.java`) — producer가 올바른 토픽·키(tenantId)·NotificationSend 필드로 send 하는지(Mockito mock KafkaTemplate)
```java
package com.synapse.engagement.community.application.event;

import com.synapse.event.platform.NotificationSend;
import org.apache.avro.specific.SpecificRecord;
import org.junit.jupiter.api.Test;
import org.springframework.kafka.core.KafkaTemplate;
import java.util.Map;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class CommunityNotificationKafkaProducerTests {
    @Test
    void publishesNotificationSendWithTenantKey() {
        @SuppressWarnings("unchecked")
        KafkaTemplate<String, SpecificRecord> template = mock(KafkaTemplate.class);
        var producer = new CommunityNotificationKafkaProducer(template, "platform.notification.notification-send-v1");

        producer.publishModerationNotification(42L, "tenant-1", "REPORT_RESOLVED",
                "신고가 처리되었습니다", "본문", Map.of("reportId", "7"));

        var captor = org.mockito.ArgumentCaptor.forClass(SpecificRecord.class);
        verify(template).send(eq("platform.notification.notification-send-v1"), eq("tenant-1"), captor.capture());
        NotificationSend sent = (NotificationSend) captor.getValue();
        assertThat(sent.getUserId()).isEqualTo("42");
        assertThat(sent.getNotificationType()).isEqualTo("REPORT_RESOLVED");
        assertThat(sent.getChannels()).contains("FCM");
    }
}
```
- [ ] **Step 4: 테스트 실패 확인** `./gradlew test --tests '*CommunityNotificationKafkaProducerTests*'` → FAIL(컴파일 에러: producer 없음).
- [ ] **Step 5: producer 구현** (`CommunityNotificationKafkaProducer.java`)
```java
package com.synapse.engagement.community.application.event;

import com.synapse.event.platform.NotificationSend;
import org.apache.avro.specific.SpecificRecord;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;
import java.util.List;
import java.util.Map;

@Component
@ConditionalOnProperty(prefix = "synapse.kafka", name = "enabled", havingValue = "true")
public class CommunityNotificationKafkaProducer implements CommunityNotificationPublisher {
    private final KafkaTemplate<String, SpecificRecord> kafkaTemplate;
    private final String notificationSendTopic;

    public CommunityNotificationKafkaProducer(
            KafkaTemplate<String, SpecificRecord> kafkaTemplate,
            @Value("${synapse.kafka.topics.notification-send}") String notificationSendTopic) {
        this.kafkaTemplate = kafkaTemplate;
        this.notificationSendTopic = notificationSendTopic;
    }

    @Override
    public void publishModerationNotification(Long recipientUserId, String tenantId, String notificationType,
                                             String title, String body, Map<String, String> data) {
        // 필드명/타입은 src/main/avro/platform/NotificationSend.avsc와 반드시 맞춘다. userId는 gamification과 동일하게 Long을 문자열화.
        var event = NotificationSend.newBuilder()
                .setUserId(String.valueOf(recipientUserId))
                .setTenantId(tenantId)
                .setNotificationType(notificationType)
                .setChannels(List.of("FCM"))
                .setTitle(title)
                .setBody(body)
                .setData(data)
                .build();
        // EVENT_CONTRACT_STANDARD: tenant 순서 보장을 위해 tenantId를 partition key로.
        kafkaTemplate.send(notificationSendTopic, tenantId, event);
    }
}
```
- [ ] **Step 6: 테스트 통과 확인** `./gradlew test --tests '*CommunityNotificationKafkaProducerTests*'` → PASS.
- [ ] **Step 7: 커밋** `git add src/main/java/com/synapse/engagement/community/application/event src/test/... && git commit -m "feat(community): 모더레이션 알림 Publisher(Kafka/Noop) (S5)"`

## Task 4: 피신고자 owner 조회 확장

**Files:**
- Modify `src/main/java/com/synapse/engagement/community/application/SharedContentService.java`
- Modify `.../application/GroupService.java`
- Test: 각 서비스 테스트에 owner 조회 케이스

- [ ] **Step 1: 실패 테스트** — `SharedContentService.findOwnerId(targetType, targetId)`가 콘텐츠 소유자 Long을 반환하는지(기존 테스트 클래스에 추가, 저장된 SharedContent fixture의 ownerId 단언).
- [ ] **Step 2: SharedContentService에 메서드 추가**
```java
@Transactional(readOnly = true)
public Long findOwnerId(ReportTargetType targetType, Long sharedContentId) {
    var content = sharedContentRepository.findById(sharedContentId)
            .orElseThrow(() -> new NotFoundException("Shared content not found: id=" + sharedContentId));
    return content.getOwnerId();
}
```
(`SharedContent`에 `getOwnerId()` 없으면 추가 — 엔티티의 ownerId 필드 노출.)
- [ ] **Step 3: GroupService에 메서드 추가**
```java
@Transactional(readOnly = true)
public Long findOwnerId(Long groupId) {
    var group = groupRepository.findById(groupId)
            .orElseThrow(() -> new NotFoundException("Group not found: id=" + groupId));
    return group.getOwnerId();
}
```
- [ ] **Step 4: 테스트 통과 + 커밋** `./gradlew test --tests '*SharedContentService*' --tests '*GroupService*'` → PASS. commit `feat(community): 신고 대상 owner 조회 메서드 (S5)`.

## Task 5: ModerationService 발행 훅 + tenantId 전달

**Files:**
- Modify `.../application/ModerationService.java`
- Modify `.../api/ReportController.java` (tenantId 전달)
- Test: `src/test/java/com/synapse/engagement/community/application/ModerationServiceTests.java`

- [ ] **Step 1: 실패 테스트** — moderate(APPROVED) 시 신고자+피신고자 2건, moderate(REJECTED) 시 신고자 1건 발행(mock `CommunityNotificationPublisher` + mock owner 조회) 검증
```java
package com.synapse.engagement.community.application;

import com.synapse.engagement.community.application.event.CommunityNotificationPublisher;
// ... (Report fixture: reporterId=10, targetType=SHARED_NOTE, targetId=99)
import org.junit.jupiter.api.Test;
import static org.mockito.Mockito.*;

class ModerationServiceTests {
    @Test
    void approvedNotifiesReporterAndOwner() {
        // given: report(reporterId=10, SHARED_NOTE, targetId=99), sharedContentService.findOwnerId(...)=20
        // when: moderate(reportId, ReportModerateRequest(APPROVED, note), "tenant-1")
        // then:
        verify(publisher).publishModerationNotification(eq(10L), eq("tenant-1"), eq("REPORT_RESOLVED"), any(), any(), anyMap());
        verify(publisher).publishModerationNotification(eq(20L), eq("tenant-1"), eq("CONTENT_REMOVED"), any(), any(), anyMap());
    }
    @Test
    void rejectedNotifiesReporterOnly() {
        // when: moderate(REJECTED, ...) ; then:
        verify(publisher).publishModerationNotification(eq(10L), eq("tenant-1"), eq("REPORT_REJECTED"), any(), any(), anyMap());
        verifyNoMoreInteractions(publisher);
    }
}
```
- [ ] **Step 2: 실패 확인** `./gradlew test --tests '*ModerationServiceTests*'` → FAIL.
- [ ] **Step 3: ModerationService에 publisher 주입 + 훅 추가** — 생성자에 `CommunityNotificationPublisher` 추가. moderate 시그니처에 `String tenantId` 추가. 발행 헬퍼:
```java
// APPROVED 분기 (hideTarget+approve 후, 커밋과 같은 메서드 끝부분):
notifyReporter(report, tenantId, "REPORT_RESOLVED", "신고가 처리되었습니다", "신고하신 콘텐츠가 제재되었습니다.");
resolveReportedUserId(report).ifPresent(ownerId ->
    publisher.publishModerationNotification(ownerId, tenantId, "CONTENT_REMOVED",
        "콘텐츠가 제재되었습니다", "신고 검토 결과 회원님의 콘텐츠가 제재되었습니다.", Map.of("reportId", String.valueOf(report.getId()))));
// REJECTED 분기:
notifyReporter(report, tenantId, "REPORT_REJECTED", "신고가 기각되었습니다", "신고 검토 결과 조치가 이루어지지 않았습니다.");
```
헬퍼:
```java
private void notifyReporter(Report report, String tenantId, String type, String title, String body) {
    publisher.publishModerationNotification(report.getReporterId(), tenantId, type, title, body,
            Map.of("reportId", String.valueOf(report.getId()), "targetType", report.getTargetType().name()));
}
private java.util.Optional<Long> resolveReportedUserId(Report report) {
    return switch (report.getTargetType()) {
        case USER -> java.util.Optional.of(report.getTargetId()); // targetId == 피신고자
        case SHARED_DECK, SHARED_NOTE -> java.util.Optional.ofNullable(sharedContentService.findOwnerId(report.getTargetType(), report.getTargetId()));
        case STUDY_GROUP -> java.util.Optional.ofNullable(groupService.findOwnerId(report.getTargetId()));
    };
}
```
> 발행은 모더레이션 트랜잭션 커밋을 깨지 않도록 best-effort — `try { ... } catch (Exception e) { log.warn(...) }`로 감싼다(발행 실패가 API 실패로 번지지 않게).
- [ ] **Step 4: ReportController가 tenantId 전달** — 컨트롤러 moderate 핸들러에 `@CurrentTenant String tenantId`(engagement CurrentTenant) 추가해 `moderationService.moderate(reportId, request, tenantId)` 호출. (CurrentTenant 사용법은 기존 컨트롤러 참조.)
- [ ] **Step 5: 테스트 통과** `./gradlew test --tests '*ModerationServiceTests*'` → PASS.
- [ ] **Step 6: 커밋** `git commit -am "feat(community): 모더레이션 결정 시 알림 발행 훅 + tenantId 전달 (S5)"`

## Task 6: 통합 검증 + PR

- [ ] **Step 1: 전체 빌드/테스트** `./gradlew clean build` → BUILD SUCCESSFUL.
- [ ] **Step 2: 푸시 + dev PR**
```bash
git push -u origin feat/community-moderation-notification
gh pr create --repo team-project-final/synapse-engagement-svc --base dev --head feat/community-moderation-notification \
  --title "feat(community): 모더레이션 → 알림 발행 (S5)" --body "설계 spec 2026-06-04-w4-community-audit-events-design §3. NotificationSend 발행(신고자+피신고자), gamification Producer 패턴. Task 0에서 platform 소비자 계약 검증."
```

## Self-Review (작성자 체크)
- Spec §3 커버: 컴포넌트(Task3)·훅 표(Task5)·피신고자 해결(Task4/5 resolveReportedUserId, USER=targetId)·계약(Task0/1) ✓.
- 미해결: platform 소비자 정확 타입(Task0에서 확정), `SharedContent.getOwnerId()`/`Group.getOwnerId()` 존재 여부(Task4 Step2/3에서 없으면 추가). CurrentTenant 시그니처(Task5 Step4 기존 컨트롤러 대조).
