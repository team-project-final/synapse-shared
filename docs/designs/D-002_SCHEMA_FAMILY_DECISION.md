# D-002 — 이벤트 스키마/직렬화 패밀리 정합 (분석 + 권고)

> **작성일**: 2026-05-29
> **작성자**: @team-lead
> **상태**: ✅ **결정 — Option 1(Avro + Schema Registry 사수) 채택** (2026-05-29, 팀장). PRD "Registry BACKWARD 등록" 준수. 표준: [EVENT_CONTRACT_STANDARD](../guides/EVENT_CONTRACT_STANDARD.md). 배포 메커니즘(§7)은 선결 과제로 진행.
> **관련**: [NOTIFICATION_TRIGGER_AI_CARDS](./NOTIFICATION_TRIGGER_AI_CARDS.md) · [EVENT_FLOW_MATRIX](../guides/EVENT_FLOW_MATRIX.md) · [W4_KAFKA_WORKORDER](../work-orders/W4_KAFKA_WORKORDER.md)

---

## 1. 문제

서비스 간 Kafka 이벤트 계약이 **5개 서비스에서 4가지 비호환 방식**으로 갈렸다. **synapse-shared의 Avro 8종을 의존하는 서비스는 하나도 없다**(고아). 현 상태로는 어떤 producer–consumer 쌍도 wire 호환을 보장할 수 없다.

## 2. 실측 (origin 코드 직접 확인, 05-29)

| 서비스 | 직렬화 | 네임스페이스 | 봉투 | Registry | shared 의존 |
|--------|--------|-------------|------|:--------:|:-----------:|
| **synapse-shared** (정의만) | Avro | `com.synapse.*` | CloudEvent (`time:string`, data 없음, `subject` 있음) | BACKWARD 정책 | (라이브러리 본체) |
| **learning-card** | **Confluent `KafkaAvroSerializer`** | `com.synapse.learning.event` (`CardReviewed`, `CardReviewDue`) | **없음 (bare record)** | ✅ 사용 | ❌ |
| **platform** | **`ByteArraySerializer`** (수동 Avro 인코딩) + 일부 KafkaAvroSerializer 혼재 | `com.synapse.event.*` | CloudEvent (`time:long`, **`data:bytes`** 중첩) | url만, 수동 | ❌ |
| **engagement** | **`StringSerializer`** (JSON 문자열) | `com.synapse.event.engagement` | (평면 JSON) | ❌ | ❌ |
| **learning-ai** | **JSON** (`json.dumps`, Pydantic, **snake_case**) | — | (평면 JSON) | ❌ | ❌ |
| **knowledge** | (Producer 미구현) | — | — | — | ❌ |

### 불일치 차원
1. **인코딩**: Confluent-Avro(registry) ↔ 수동-Avro-bytes ↔ JSON-string ↔ JSON-pydantic — **상호 역직렬화 불가**.
2. **봉투**: 없음 / CloudEvent(data:bytes) / 평면 — 제각각.
3. **네임스페이스/이벤트명**: shared `ReviewCompleted` vs learning-card `CardReviewed`; shared `CardsGenerated`(미사용). `com.synapse.*` vs `com.synapse.event.*` vs `com.synapse.learning.event`.
4. **필드 표기**: camelCase(Java/Avro) vs snake_case(learning-ai JSON).
5. **time 타입**: string(shared, CloudEvents 표준) vs long(platform).

### 근본 원인 — shared가 "소비 가능한" 라이브러리였던 적이 없음
- synapse-shared는 `maven-publish`·`group=com.synapse`·`version=0.1.0`로 **발행 의도**는 있으나 `publishing{}`에 **발행 대상 repository 미설정** → mavenLocal 외 실제 배포 경로 없음.
- **어떤 서비스도 의존 선언 없음**(platform/engagement/knowledge/learning 전 브랜치 build·settings·toml에서 `synapse-shared`/`com.synapse:`/jitpack/github-packages **0건, 주석조차 없음**).
- **svc-template(스켈레톤)도 shared 미배선**, shared README/온보딩에 **소비 방법 가이드 부재**.
- ⇒ 공통 라이브러리로 **의도**됐으나 배포·가이드·배선이 전무 → 각 팀이 자체 스키마를 만든 것이 자연스러운 귀결. **분기는 증상, 배포 메커니즘 부재가 원인.**

## 3. 영향 (PRD 체인이 실제로 깨지는 지점)

| 체인 | Producer | Consumer | 호환? |
|------|----------|----------|:-----:|
| user-registered | platform (수동 Avro/event.*) | engagement (StringSerializer/JSON) | ❌ Avro↔JSON |
| review-completed | learning-card (Confluent Avro/learning.event) | engagement (JSON) | ❌ Avro↔JSON + 이벤트명 상이 |
| note-created | knowledge (미구현) | learning-ai (JSON/pydantic) | ⚠️ producer가 JSON로 맞춰야 가능 |
| notification-send | learning-ai (예정) | platform (수동 Avro/event.*) | ❌ JSON↔Avro-bytes |

→ **현재 어떤 크로스서비스 체인도 wire 호환이 성립하지 않음.** ([W3_EXIT_GATE](../reports/W3_EXIT_GATE.md) "어떤 체인도 양끝 충족 안 됨"의 근본 원인.)

## 4. 선택지

### Option 1 — Confluent Avro + Schema Registry로 통일 (Avro 사수)
- 단일 스키마셋(shared로 일원화), topic당 typed record(learning-card 방식), Confluent `KafkaAvroSerializer`, CloudEvent는 헤더/메타로.
- **장점**: PRD 성공기준("모든 producer 토픽 Registry BACKWARD 등록") 충족, 강한 계약·자동 호환검사, learning-card는 거의 그대로.
- **단점**: platform(수동→Confluent), engagement(JSON→Avro), **learning-ai(Python JSON→confluent-kafka Avro, 마찰 최대)** 전면 개편. shared 스키마/이벤트명 재정렬(`CardReviewed`↔`ReviewCompleted`). 마감 2주 내 4레포 변경.

### Option 2 — JSON CloudEvent로 통일 (실용·권장)
- **CloudEvents 1.0 JSON** 봉투(`specversion,id,source,type,subject,time(RFC3339),datacontenttype,data{}`), `data`는 typed JSON. **필드 계약은 synapse-shared가 소유**(기존 .avsc를 *필드 명세*로 유지 + JSON Schema 병행, wire는 JSON).
- **장점**: engagement·learning-ai 이미 JSON → 마찰 최소. Python-Avro-registry 마찰 제거. 폴리글랏·디버깅 용이. greenfield(knowledge producer·engagement consumer)는 JSON CloudEvent만 따르면 됨. **변경 최소 = learning-card/platform의 직렬화기 1방향 교체**.
- **단점**: Confluent **바이너리 Avro + Registry 자동 BACKWARD 강제**를 포기(W1/W2 투자·PRD 기준 일부 반납). → 완화: 버전드 JSON CloudEvent + shared의 JSON Schema를 `schema-check`로 호환검사(거버넌스는 유지, wire만 JSON).

### Option 3 — 현상 유지 + 엣지별 어댑터
- **기각**: N×M 변환 유지비, 디버깅 지옥, 마감 내 위험.

## 5. 권고 (분석 시점) → ✅ 최종 결정: Option 1

> **최종 결정(2026-05-29, 팀장): Option 1 (Avro + Schema Registry 사수) 채택.** 아래 분석은 마감 리스크 기준으로 Option 2를 권고했으나, **PRD "모든 producer 토픽 Registry BACKWARD 등록" 준수**를 우선해 Option 1로 확정. 이에 따라 §6 마이그레이션(Option 2용)은 **무효**이며, 실제 적용은 [EVENT_CONTRACT_STANDARD §3·§4](../guides/EVENT_CONTRACT_STANDARD.md)(Avro 사용법) + 각 서비스 이슈(#43/#13/#26/#32)를 따른다. learning-ai의 Python Avro 전환 마찰은 감수하며, 배포 메커니즘(§7)을 선결로 해소.

### 🥈 (참고·분석 시점 권고) Option 2 (JSON CloudEvent)

근거:
1. **마감(06-15) 현실**: 2주·4레포·다팀. Option 2는 변경 표면이 가장 작다(learning-card·platform만 직렬화기 교체; engagement·learning-ai 거의 유지; greenfield는 신규라 비용 동일).
2. **Python 마찰 제거**: learning-ai를 Avro로 끌고 가는 것이 최대 리스크인데 Option 2는 이를 없앤다.
3. **거버넌스 보존**: shared가 *필드 계약*(.avsc→JSON Schema)을 계속 소유하고 `schema-check`로 호환을 검사 → "스키마 중앙관리 + 호환성"이라는 PRD 정신은 유지, *바이너리 Avro/Registry*만 양보.
4. shared의 CloudEventEnvelope는 이미 `time:string`(CloudEvents 표준 준수) → JSON CloudEvent의 기준 봉투로 그대로 승격 가능. platform의 `time:long`/`data:bytes`가 비표준.

> **트레이드오프(명시)**: PRD "Schema Registry BACKWARD 등록"을 *바이너리 Avro* 기준으로는 미충족하게 된다. 이를 JSON Schema 호환검사로 대체 정의할지 **팀장/팀 비준 필요**. 이 한 줄이 본 결정의 핵심이며, 내가 단독 확정하지 않는다.

### 🥈 대안: **Option 1 (Confluent Avro)** — "Registry 사수가 비협상"일 때
PRD의 Registry 요건을 글자 그대로 지켜야 한다면 Option 1. 단 learning-ai Python Avro + 3레포 개편 비용을 마감 내 감수해야 함.

## 6. (무효 — Option 1 채택으로 대체) Option 2 채택 시 마이그레이션

> ⚠️ Option 1 확정으로 본 절은 적용 안 함. Avro 마이그레이션은 [EVENT_CONTRACT_STANDARD](../guides/EVENT_CONTRACT_STANDARD.md) + 이슈 참조. (분석 보존용으로만 남김.)

| 서비스 | 변경 | 규모 |
|--------|------|:----:|
| **synapse-shared** | CloudEvent JSON 봉투 표준 문서화 + 8종 .avsc를 JSON Schema로 병행 발행 + `schema-check`를 JSON Schema 호환검사로 확장. 이벤트명 정합(`CardReviewed`→`ReviewCompleted` 등) 합의 | 중 |
| learning-card | `KafkaAvroSerializer`→`StringSerializer`(Jackson JSON CloudEvent). 도메인 로직 불변 | 소 |
| platform | 수동 Avro-bytes→JSON CloudEvent(Jackson). NotificationSend도 JSON | 중 |
| engagement | 이미 StringSerializer → CloudEvent 봉투/필드 표준만 정렬 | 소 |
| learning-ai | JSON 유지. CloudEvent 봉투로 감싸기 + 필드 표기(snake↔camel) 합의 | 소 |
| knowledge | (greenfield) note-created/updated를 JSON CloudEvent로 신규 발행 | 소(어차피 신규) |

> [NOTIFICATION_TRIGGER_AI_CARDS](./NOTIFICATION_TRIGGER_AI_CARDS.md)의 NotificationSend도 Option 2 채택 시 JSON CloudEvent payload로 단순화(중첩 bytes 불요) → learning-ai 발행이 훨씬 쉬워짐.

## 7. 다음 단계
1. ✅ **결정 완료**: Option 1(Avro + Schema Registry 사수) — §5 상단.
2. ✅ **배포 메커니즘 구현(근본 원인 해소)**: 런타임=Schema Registry(BACKWARD), 컴파일=shared Avro(벤더링 또는 라이브러리). shared **GitHub Packages 발행 구현**(`build.gradle.kts` + `publish.yml`), `synapse-shared-0.1.0.jar`에 생성 Avro 클래스 포함 검증. → [EVENT_CONTRACT_STANDARD §6](../guides/EVENT_CONTRACT_STANDARD.md).
3. ✅ shared: 표준 + 이벤트 카탈로그 확정 — [EVENT_CONTRACT_STANDARD §2](../guides/EVENT_CONTRACT_STANDARD.md). 스키마 8+3종 마련(공통메타 포함).
4. ✅ 각 서비스 work-order/이슈에 마이그레이션 반영 — 이슈 #43/#13/#26/#32.
5. 잔여: org GitHub Packages 활성화 + 최초 태그 발행(v0.1.0), svc-template 배선, owner 필드 확정(LevelUp/BadgeEarned), `kafka-e2e-test.sh` Avro 검증 강화.

## 8. 오픈
- **비준 필요**: Option 선택 + PRD Registry 기준 재정의(Option 2 시).
- 이벤트 카탈로그 단일화(이름·필드·토픽·표기) — shared 소유.
- learning-ai 필드 표기(snake_case) 전역 합의 여부.
