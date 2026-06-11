## 배경 / 근거 (W5 Day3 라이브 관찰)

W5 Day3(2026-06-10) D-004 Stage1 라이브 E2E 검증 중, platform **audit 컨슈머**가 `learning.card.review-completed-v1` 이벤트를 처리하지 못하고 **DLT로 전량 적재**하는 현상을 관찰했다. F10(레벨업 알림) 경로와는 **무관**하며 audit-leg 별개 사안이다.

- 관찰 맥락: 경계유저 복습→레벨업 시나리오 구동을 위해 `ReviewCompleted` Avro 이벤트 11건을 `learning.card.review-completed-v1`에 주입.
- 결과: platform **`platform-audit-group`** 컨슈머(container #3)가 11건을 `learning.card.review-completed-v1.DLT`에 적재(end offset 11). 로그는 INFO("Record in retry")/WARN(DLT partition resolver) 수준, **ERROR 없음**.
- 알림 경로(`platform-svc-group`, NotificationService)는 정상 — F10 PASS와 무관.

## ✅ 가설 A 확정 (2026-06-11, 3레포 소스 대조)

W5 Day3에는 합성 주입이라 가설 A(실제 결함)/B(주입 아티팩트) 미확정이었으나, **3개 레포 `.avsc`·발행/소비 코드를 직접 대조해 가설 A(실제 계약 분기)로 확정**한다. **platform 결함이 아니라 learning 실제 발행 스키마가 shared 정본에서 갈라진 문제**다.

| | 네임스페이스 | reviewedAt | occurredAt | 출처 |
|---|---|---|---|---|
| **shared 정본** | `com.synapse.learning` | `string`(ISO-8601) | `long`(평문) | `synapse-shared/src/main/avro/learning/ReviewCompleted.avsc` |
| **platform**(소비자) | `com.synapse.learning` ✅정본 일치 | `string` ✅ | `long` ✅ | `synapse-platform-svc/.../audit/consumer/AuditKafkaConsumer.java`(import `com.synapse.learning.ReviewCompleted`) |
| **learning**(실제 발행) | `com.synapse.event.learning` ❌ | `long`/`timestamp-millis` ❌ | `long`/`timestamp-millis` | `synapse-learning-svc/learning-card/.../CardReviewedEventPublisher.java`(import `com.synapse.event.learning.ReviewCompleted`) |

**DLT가 나는 정확한 메커니즘 (역직렬화 두 지점에서 fatal):**
1. **네임스페이스 fatal** — platform은 `specific.avro.reader: true`라 writer 스키마 full name(`com.synapse.event.learning.ReviewCompleted`)으로 reader SpecificRecord를 찾는데, platform엔 `com.synapse.learning.ReviewCompleted`만 존재 → 클래스 매핑 실패.
2. **reviewedAt 타입 fatal** — `string`↔`long`은 Avro 승격(promotion) 대상이 **아님**. 네임스페이스가 같았어도 이 필드에서 깨짐.
3. occurredAt(`long`↔`long+timestamp-millis`)은 물리타입 동일 → wire 호환, **무해**.

**왜 레지스트리 BACKWARD가 못 걸렀나**: Confluent 호환성은 subject(`learning.card.review-completed-v1-value`) **내부**에서만 검사한다. learning이 이 토픽 유일 producer라 등록 스키마=learning형이고 BACKWARD 통과 — 레지스트리는 shared 정본 `.avsc`와 대조하지 않으므로 분기는 **platform 소비 시점에만** 드러난다. (합성 주입이 아니어도 실 발행에서 동일 재현 → 가설 B 기각.)

## 현재 상태 / 조사 포인트

1. platform audit 컨슈머가 **어떤 토픽을 구독**하는지 확인 — `learning.card.review-completed-v1`을 audit 대상으로 의도했는가? (전 토픽 audit인지, 화이트리스트인지)
2. `ReviewCompleted` 역직렬화 계약 — audit 컨슈머의 디시리얼라이저(Avro/JSON)와 `src/main/avro/learning/ReviewCompleted.avsc` 정합.
3. DLT 적재 직전 예외 원인 로그 — `platform-audit-group` 컨슈머의 retry/DLT 트리거 스택트레이스 확보(현재 ERROR 미출력이라 로깅 레벨 상향 필요).
4. 의도된 미지원 이벤트라면 **DLT 대신 graceful skip**(audit 비대상 이벤트는 조용히 무시)로 바꿔 DLT 오염 방지.

## 근본 수정 (owner = learning-card) — platform은 정본 유지

**platform은 변경하지 말 것.** platform은 shared 정본(`com.synapse.learning` + `reviewedAt:string` + `occurredAt:long`)을 충실히 따르고 있어, 바꾸면 정본 준수 쪽이 깨진다.

근본 수정은 **learning 발행 스키마를 정본에 정렬**(`synapse-learning-svc/learning-card/src/main/avro/learning/ReviewCompleted.avsc`):
- namespace `com.synapse.event.learning` → **`com.synapse.learning`**
- `reviewedAt` `{long, timestamp-millis}` → **`string`(ISO-8601)**
- `occurredAt` `{long, timestamp-millis}` → **평문 `long`**
- 이는 `EVENT_CONTRACT_STANDARD §1`의 명문 위반 시정이다(§1이 `com.synapse.event.*` 네임스페이스·`logicalType:timestamp-millis`를 둘 다 폐기 대상으로 명시).

⚠️ **호환성 주의**: learning이 이 토픽 유일 producer라 정렬 시 subject에 새 버전이 등록되는데, `reviewedAt` `string`↔`long` 변경은 **BACKWARD 비호환**이다. 그냥 바꾸면 레지스트리가 거부하거나 기존 메시지를 읽던 컨슈머가 깨진다. → **신규 토픽 v2 전환** 또는 **(개발 환경) subject 리셋 + 기존 오프셋 폐기** 중 택1 필요.

(platform 측 graceful skip은 정렬 완료 전 임시 DLT 오염 차단용으로만 선택 적용 가능 — 근본 해결 아님.)

## 검증 (DoD)

- [x] 실 서비스 발행 ReviewCompleted로 재현 여부 확정 → **가설 A(계약 분기) 확정**(3레포 소스 대조, 위 표)
- [ ] (owner=learning) 발행 `.avsc`를 정본 정렬(namespace·reviewedAt·occurredAt) + v2 전환/subject 리셋
- [ ] platform audit 컨슈머가 정렬된 ReviewCompleted를 audit_logs에 적재 성공
- [ ] `learning.card.review-completed-v1.DLT` 신규 적재 0
- [ ] audit 컨슈머 retry 루프 없음

## 참조
- synapse-shared `docs/project-management/HANDOFF_W5_DAY3.md` §0 (신규 관찰)
- W5 Day3 라이브 검증 로그(2026-06-10): `platform-audit-group` DLT offset 11
- `src/main/avro/learning/ReviewCompleted.avsc`
