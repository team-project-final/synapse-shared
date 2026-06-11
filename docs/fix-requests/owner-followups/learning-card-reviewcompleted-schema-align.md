## 배경 / 근거

learning-card가 `learning.card.review-completed-v1`에 발행하는 `ReviewCompleted` Avro 스키마가 **synapse-shared 정본에서 갈라져**, 정본을 준수하는 platform audit 컨슈머가 역직렬화에 실패하고 이벤트를 **DLT로 전량 적재**한다(W5 Day3 라이브 관찰, platform#87). 3개 레포 `.avsc`·발행/소비 코드 대조로 **계약 분기(가설 A)** 확정.

- 출처: synapse-shared `docs/fix-requests/owner-followups/platform-audit-reviewcompleted-dlt.md`(가설 A 확정) · `docs/guides/EVENT_CONTRACT_STANDARD.md §1`
- 연관: platform#87(audit DLT — platform 측은 정본 유지, 본 건이 근본 원인)

## 현재 상태 (실측 2026-06-11, 3레포 소스 대조)

| | 네임스페이스 | reviewedAt | occurredAt | 출처 |
|---|---|---|---|---|
| **shared 정본** | `com.synapse.learning` | `string`(ISO-8601) | `long`(평문) | synapse-shared `src/main/avro/learning/ReviewCompleted.avsc` |
| **platform**(소비자) | `com.synapse.learning` ✅ | `string` ✅ | `long` ✅ | platform-svc `.../audit/consumer/AuditKafkaConsumer.java` |
| **learning-card**(실제 발행) | `com.synapse.event.learning` ❌ | `{long, timestamp-millis}` ❌ | `{long, timestamp-millis}` | learning-card `src/main/avro/learning/ReviewCompleted.avsc` + `.../srs/adapter/out/event/CardReviewedEventPublisher.java`(import `com.synapse.event.learning.ReviewCompleted`) |

**DLT가 나는 정확한 메커니즘 (platform 소비 시 역직렬화 두 지점에서 fatal):**
1. **네임스페이스 fatal** — platform은 `specific.avro.reader: true`라 writer 스키마 full name(`com.synapse.event.learning.ReviewCompleted`)으로 reader SpecificRecord를 찾는데, platform엔 `com.synapse.learning.ReviewCompleted`만 존재 → 클래스 매핑 실패.
2. **reviewedAt 타입 fatal** — `string`↔`long`은 Avro 승격(promotion) 대상이 **아님**. 네임스페이스가 같았어도 이 필드에서 깨짐.
3. occurredAt(`long`↔`long+timestamp-millis`)은 물리타입 동일 → wire 호환, 무해.

**왜 레지스트리 BACKWARD가 못 걸렀나**: Confluent 호환성은 subject(`learning.card.review-completed-v1-value`) **내부**에서만 검사한다. learning-card가 이 토픽 유일 producer라 등록 스키마=learning형이고 BACKWARD 통과 — 레지스트리는 shared 정본 `.avsc`와 대조하지 않으므로 분기는 platform 소비 시점에만 드러난다.

## 정확한 변경 지점

learning-card `src/main/avro/learning/ReviewCompleted.avsc`를 **shared 정본에 정렬**(`EVENT_CONTRACT_STANDARD §1` 명문 위반 시정 — §1이 `com.synapse.event.*` 네임스페이스·`logicalType:timestamp-millis`를 둘 다 폐기 대상으로 명시):

1. `"namespace": "com.synapse.event.learning"` → **`"com.synapse.learning"`**
2. `reviewedAt` `{"type":"long","logicalType":"timestamp-millis"}` → **`"string"`**(ISO-8601). 발행부(`CardReviewedEventPublisher`)에서 epoch millis가 아닌 **ISO-8601 문자열**로 세팅하도록 변경.
3. `occurredAt` `{"type":"long","logicalType":"timestamp-millis"}` → **평문 `"long"`**(epoch millis, default 0). 물리타입 동일이라 값 세팅 로직은 그대로.
4. import 정정: `com.synapse.event.learning.ReviewCompleted` → `com.synapse.learning.ReviewCompleted`(`KafkaConfig.java`·`CardReviewedEventPublisher.java`). 정본 정렬 후엔 **shared 벤더링 `.avsc` 그대로 사용**(임의 수정 금지, 변경은 shared PR).

> 권고: 직접 작성 대신 **synapse-shared `src/main/avro/learning/ReviewCompleted.avsc`를 그대로 벤더링**해 codegen하면 정본과 100% 일치(`EVENT_CONTRACT_STANDARD §3`).

## ⚠️ 호환성 주의 (BACKWARD 비호환 변경)

`reviewedAt` `string`↔`long`은 **BACKWARD 비호환**이다. learning-card가 유일 producer지만, 정렬 시 subject(`learning.card.review-completed-v1-value`)에 비호환 새 버전을 등록하려 하면 **레지스트리가 거부**하거나 기존 메시지를 읽던 컨슈머가 깨진다. 둘 중 택1:

- **(권장) 신규 토픽 v2 전환** — `learning.card.review-completed-v2`로 발행, platform 컨슈머도 v2 구독으로 전환. 기존 v1은 폐기.
- **(개발 환경 한정) subject 리셋** — 레지스트리에서 해당 subject 삭제 + 기존 토픽 데이터/오프셋 폐기 후 정렬 스키마 재등록. 운영 데이터 없을 때만.

→ 토픽 전략은 **learning-card·platform 합의** 필요(소비자 전환 동반).

## 검증 (DoD)

- [ ] learning-card 발행 `ReviewCompleted` `.avsc`가 shared 정본과 필드 단위 동일(namespace·reviewedAt:string·occurredAt:long)
- [ ] 발행부가 `reviewedAt`을 ISO-8601 문자열로 세팅
- [ ] v2 전환 또는 subject 리셋으로 레지스트리 등록 성공(BACKWARD 충돌 해소)
- [ ] 실 서비스 발행(복습 완료) → platform audit 컨슈머가 `audit_logs`에 적재 성공
- [ ] `learning.card.review-completed-v1.DLT`(또는 v2) 신규 적재 0, audit retry 루프 없음

## 참조
- synapse-shared `docs/fix-requests/owner-followups/platform-audit-reviewcompleted-dlt.md`(platform 관점·가설 A 확정)
- synapse-shared `docs/guides/EVENT_CONTRACT_STANDARD.md §1, §3`
- synapse-shared `src/main/avro/learning/ReviewCompleted.avsc`(정본)
- platform-svc #87(audit DLT)
- synapse-shared `docs/project-management/HANDOFF_W5_DAY3_CLOSEOUT.md §4`(owner 이슈 레지스터)
