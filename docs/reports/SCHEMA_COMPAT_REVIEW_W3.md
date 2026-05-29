# W3 크로스서비스 스키마 호환성 리뷰

> **작성일**: 2026-05-29 (W3 Day 4)
> **WORKFLOW**: Step 7.9 (크로스 서비스 영향도 — 스키마 호환성)
> **작성자**: @team-lead
> **참조**: [EVENT_FLOW_MATRIX.md](../guides/EVENT_FLOW_MATRIX.md) · [HANDOFF_SHARED.md](../project-management/HANDOFF_SHARED.md)

---

## 1. 검증 범위 / 방법

| 항목 | 내용 |
|------|------|
| 대상 | `src/main/avro/**/*.avsc` 8종 + 호환성 테스트 샘플 2종 |
| 로컬 검증 | ① JSON 형식(`jq`) ② `./gradlew :generateAvroJava` 컴파일 |
| 미실행(차단) | Schema Registry BACKWARD 등록 검증 — `SCHEMA_REGISTRY_URL` 미설정 / EKS destroy. 로컬 docker-compose `schema-registry` 기동 시 가능 |

> CI(`schema-check.yml`)도 `SCHEMA_REGISTRY_URL` 미설정 시 **local compile-only 모드**로 동작 — 오늘 검증은 CI 기본 경로와 동일.

## 2. 결과 — 형식 + 컴파일

| # | 스키마 | 네임스페이스 | JSON | 컴파일 |
|---|--------|------------|:----:|:------:|
| 1 | CloudEventEnvelope | com.synapse.shared | ✅ | ✅ |
| 2 | UserRegistered | com.synapse.platform | ✅ | ✅ |
| 3 | NoteCreated | com.synapse.knowledge | ✅ | ✅ |
| 4 | NoteUpdated | com.synapse.knowledge | ✅ | ✅ |
| 5 | ReviewCompleted | com.synapse.learning | ✅ | ✅ |
| 6 | CardsGenerated | com.synapse.learning | ✅ | ✅ |
| 7 | TenantId | com.synapse.shared | ✅ | ✅ |
| 8 | UserId | com.synapse.shared | ✅ | ✅ |

- `:generateAvroJava` → **EXIT 0**, 생성 클래스 9개(레코드 8 + `Rating` enum) `build/generated-main-avro-java/`.
- 호환성 테스트 샘플: `note-created-v2-compatible.avsc` / `note-created-v2-incompatible.avsc` 양쪽 모두 형식 정상 — BACKWARD 정책 검증 픽스처 존재 확인.

## 3. CloudEvent 래핑 — 코드 리뷰 기준 점검

CloudEventEnvelope 필드 vs TASK Step 7 코드 리뷰 승인 기준(8 필드):

| 요구 필드 | 존재 | 비고 |
|----------|:----:|------|
| specversion | ✅ | default `"1.0"` |
| id | ✅ | |
| source | ✅ | |
| type | ✅ | |
| subject | ✅ | `["null","string"]` default null |
| time | ✅ | ISO-8601 |
| tenantid | ✅ | |
| traceparent | ✅ | W3C Trace Context, default null |

> 추가 필드 `datacontenttype`(default `application/json`) 포함 — 8개 필수 필드 전부 충족.

## 4. 크로스서비스 영향도 (Producer ↔ Consumer 정합)

EVENT_FLOW_MATRIX 기준 발행/소비 계약과 스키마 네임스페이스 일치 확인:

| 토픽 | Producer | Consumer | 스키마 | 정합 |
|------|----------|----------|--------|:----:|
| user-registered-v1 | platform-svc | engagement-svc | UserRegistered | ✅ |
| note-created-v1 | knowledge-svc | learning-ai | NoteCreated | ✅ |
| note-updated-v1 | knowledge-svc | learning-ai, opensearch | NoteUpdated | ✅ |
| review-completed-v1 | learning-card | engagement-svc | ReviewCompleted | ✅ |
| cards-generated-v1 | learning-ai | learning-card, platform-svc | CardsGenerated | ✅ |

## 5. 결론 / 후속

- **스키마 계약 자체는 오늘 검증 기준(형식·컴파일·CloudEvent 필드·발행소비 정합) 모두 통과.** W3 종료 게이트 기준 ①의 "BACKWARD 호환 등록"은 레지스트리 실등록 검증이 남아 **조건부 충족**.
- **후속(W4 / 인프라 재기동 시)**: 로컬 `schema-registry` 또는 dev MSK 레지스트리에 8종 등록 → `./gradlew testSchemasTask`로 BACKWARD 실검증.
- 서비스 Producer/Consumer 구현 PR 도착 시, 본 계약 대비 실제 직렬화 페이로드 일치 여부를 E2E 시나리오(S1~S4)로 확장 검증.
