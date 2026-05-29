# 설계 — AI 카드 생성 알림 트리거 (A안 보강)

> **작성일**: 2026-05-29
> **작성자**: @team-lead
> **맥락**: 결정 [D-001](../guides/EVENT_FLOW_MATRIX.md)로 cards-generated Kafka 경로가 HTTP로 대체되며 **platform "AI 카드 생성 완료 알림" 트리거가 소멸**. 카드 등록은 HTTP 유지(D-001)한 채 알림만 보강한다.

---

## 1. 결론 (권장안 A1)

**learning-ai가 HTTP 카드 등록 성공 후, platform의 기존 알림 버스 `platform.notification.notification-send-v1`에 알림 요청 이벤트를 발행한다.** platform의 **기존** `NotificationKafkaConsumer`가 소비 → FCM 푸시. **platform 신규 코드 불필요.**

```
knowledge ──[note-created-v1 (Kafka)]──▶ learning-ai (LLM 카드 생성)
                                              │
                                              ├─▶ learning-card REST POST (카드 등록)   [HTTP, 기존·불변]
                                              │        └─ 2xx & cardCount>0
                                              └─▶ [notification-send-v1 (Kafka)] 발행    [신규 — 1곳]
                                                       └─▶ platform NotificationKafkaConsumer [기존]
                                                              └─▶ FcmPushService → 푸시
```

- 카드 등록 경로(HTTP)는 **전혀 건드리지 않음** → D-001 유지.
- 알림은 platform이 **이미 구현해 둔** 범용 알림 버스를 재사용 → fan-out·재시도·디커플링 확보, platform 코드 추가 없음.
- cards-generated 도메인 이벤트는 **부활하지 않음**.

## 2. 계약 — `platform.notification.notification-send-v1` (platform 코드 실측)

`NotificationService.processNotificationSend(GenericRecord envelope)`가 읽는 필드:

| 위치 | 필드 | 타입 | AI 카드 알림 값 |
|------|------|------|----------------|
| envelope | `id` | UUID | 멱등 키 (아래 §4) |
| envelope | `tenantid` | UUID | 사용자 테넌트 |
| envelope | (CloudEvent 8필드) | | specversion/source/type/time/... |
| payload | `userId` | UUID | 알림 수신자 |
| payload | `notificationType` | string | `AI_CARDS_READY` |
| payload | `title` | string | "새 플래시카드가 준비됐어요" |
| payload | `body` | string | "노트 '{noteTitle}'에서 카드 {n}개가 자동 생성됐어요." |
| payload | `emailSubject` | string? | (생략) |
| payload | `emailHtmlBody` | string? | (생략) |
| payload | `channels` | array | `["FCM"]` (이메일 불요) |

> payload는 `PlatformAvroEvents.decodeNotificationSend(envelope)`로 디코딩되는 Avro 레코드.

### 2.1 실측 스키마 (platform `PlatformAvroEvents` 미러링 — 초안 작성 완료)

**payload `NotificationSend`** (`com.synapse.event.platform`): userId, tenantId, notificationType, channels(array<string>), title, body, emailSubject(null|string), emailHtmlBody(null|string), data(map<string,string>).
→ 초안 파일 **작성·컴파일 완료**: `src/main/avro/platform/NotificationSend.avsc` (generateAvroJava EXIT 0).

**봉투(중첩 인코딩)**: platform은 `CloudEvent.data: bytes` 안에 **Avro-인코딩된 NotificationSend 바이트**를 넣음.
```
CloudEventEnvelope(com.synapse.event.shared) {
  type = "com.synapse.event.platform.NotificationSend", source = "learning-service",
  time = long(ms), tenantid, ..., data = bytes( Avro(NotificationSend) )
}
```
> 🔎 **platform에 `notificationSendEnvelope(userId, tenantId, notificationType, channels, title, body, emailSubject, emailHtmlBody)` 빌더가 이미 존재**하며 `source="learning-service"`로 세팅 — platform이 **learning 발행을 이미 상정**해 둠. 즉 계약 내용은 사실상 합의된 상태, 남은 건 위치(공유)와 Python 직렬화.

### ⚠️ 2.2 스키마 패밀리 분기 (중대 발견)

platform은 **synapse-shared의 Avro를 쓰지 않고** 자체 패밀리를 사용 중:

| 구분 | synapse-shared | platform (PlatformAvroEvents) |
|------|----------------|-------------------------------|
| 네임스페이스 | `com.synapse.shared` / `com.synapse.platform` | `com.synapse.event.shared` / `com.synapse.event.platform` |
| CloudEvent `time` | string (ISO-8601) | long (timestamp-millis) |
| CloudEvent `data` | 없음 (+ `subject` 있음) | `bytes` (payload 중첩) |
| 페이로드 래핑 | (미정/평면) | 봉투.data에 Avro 바이트 |

→ NotificationSend만 공유한다고 끝이 아니며, **봉투 계약 자체가 다름**. 본 트리거 구현 전 패밀리 정합(§8.1) 결정 필요.

## 3. 트리거 조건

- HTTP 카드 등록 응답 **2xx** AND **cardCount > 0** 일 때만 발행.
- 등록 실패/0건 → 미발행 (알림 없음).
- 발행 실패는 카드 등록을 **롤백하지 않음** (카드는 이미 HTTP로 영속). learning-ai는 fire-and-forget + 기존 DLQ로 처리.

## 4. 멱등성 / 중복 방지

- `envelope.id` = **결정적 UUID** (예: `uuidv5(noteId + userId + "ai-cards")`) → learning-ai 재시도 시 동일 id.
- platform이 `eventId(=envelope.id)` 기준 dedupe 하는지 **확인 필요** (현재 `processNotificationSend`는 eventId를 읽지만 중복 억제 로직 유무 미확인 → platform owner 확인 항목).

## 5. 책임 분담 / 액션

| 주체 | 액션 | 비고 |
|------|------|------|
| **shared / @team-lead** | `NotificationSend.avsc` **초안 작성·컴파일 완료**(src/main/avro/platform/). 단 §2.2 스키마 패밀리 분기 해소가 선행 — 봉투/네임스페이스 정합 결정 후 확정 | platform owner와 **소유권 + 패밀리 정합** 합의 필수 |
| shared / @team-lead | EVENT_FLOW_MATRIX에 `notification-send-v1` 행 추가 (producer: learning-ai 등 다수, consumer: platform) | 본 설계 반영 (완료) |
| **@learning-ai-owner** | HTTP 등록 2xx 후 `notification-send-v1` 발행 추가 | 기존 Avro CloudEvent 직렬화 도구(consumer.py/schemas.py) 재사용. 1개 이벤트 타입 |
| **@platform-owner** | ① `notificationType=AI_CARDS_READY` 수용 확인(현재 title/body/channels generic 처리 → 거의 무변경) ② eventId dedupe 확인 | 신규 Consumer 불필요 |

## 6. 대안 비교 (택1 — A1 권장)

| 안 | 발행 주체 | 장점 | 단점 |
|----|----------|------|------|
| **A1 (권장)** | learning-ai → notification-send-v1 | platform 기존 버스/consumer 재사용, 의미상 발행 출처 정확, learning-ai 이미 Avro CloudEvent 처리 | NotificationSend 스키마 공유 필요(platform 합의) |
| A2 | learning-card → notification-send-v1 | Java Avro 친화(기존 publisher 패턴) | HTTP 요청에 source/noteTitle 전달 필요, "완료" 서비스 재개봉 |
| A3 | learning-ai → platform `POST /api/v1/notifications` (HTTP) | 순수 HTTP, 스키마 공유 불요 | platform 알림 **REST 엔드포인트 신규** 필요(현재 Kafka consumer만 존재) → 버스 재사용보다 비효율 |

## 7. 검증 (서비스 구현 후)

- learning-ai 단위: HTTP 2xx mock → notification-send 발행 검증.
- platform: notification-send-v1 소비 → FcmPushService 호출 검증(기존 테스트 확장).
- E2E (S3 확장): note-created → (HTTP 등록) → notification-send → 푸시 로그. → `E2E_SCENARIOS_W3.md` S3 성공기준의 "AI 카드 알림" 항목을 본 트리거로 확정.

## 8. 오픈 이슈

1. **🚨 스키마 패밀리 분기 (§2.2)** — platform은 `com.synapse.event.*` + 봉투 변종(time:long, data:bytes)을 사용, synapse-shared(`com.synapse.*`)와 불일치. **이 트리거뿐 아니라 모든 이벤트에 영향**. 결정 필요: (a) shared가 platform 패밀리 채택 / (b) platform이 shared로 마이그레이션 / (c) 두 패밀리 공존 + 경계 문서화. **가장 큰 선결 — W4 아키텍처 논의.**
2. **NotificationSend 스키마 소유권/공유** — 초안은 작성됨(src/main/avro/platform/). 1번 결정에 종속하여 확정.
3. **learning-ai(Python) Avro 직렬화** — 중첩 봉투(data:bytes) + NotificationSend 직렬화를 Python에서 생성(fastavro 등). 기존 consumer.py 역직렬화 도구의 대칭.
4. platform eventId dedupe 유무 확인.
5. 알림 문구(i18n/템플릿) 확정 — 현재 title/body 평문.
