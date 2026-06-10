## 배경 / 근거 (W5 Day3 라이브 관찰)

W5 Day3(2026-06-10) D-004 Stage1 라이브 E2E 검증 중, platform **audit 컨슈머**가 `learning.card.review-completed-v1` 이벤트를 처리하지 못하고 **DLT로 전량 적재**하는 현상을 관찰했다. F10(레벨업 알림) 경로와는 **무관**하며 audit-leg 별개 사안이다.

- 관찰 맥락: 경계유저 복습→레벨업 시나리오 구동을 위해 `ReviewCompleted` Avro 이벤트 11건을 `learning.card.review-completed-v1`에 주입.
- 결과: platform **`platform-audit-group`** 컨슈머(container #3)가 11건을 `learning.card.review-completed-v1.DLT`에 적재(end offset 11). 로그는 INFO("Record in retry")/WARN(DLT partition resolver) 수준, **ERROR 없음**.
- 알림 경로(`platform-svc-group`, NotificationService)는 정상 — F10 PASS와 무관.

## ⚠️ 불확실성 (반드시 먼저 확인)

본 현상은 **합성 이벤트 직접 주입**(`kafka-avro-console-producer`)으로 발견됐다. 따라서:
- (가설 A) **실제 결함**: audit 컨슈머가 `ReviewCompleted` 스키마를 역직렬화/처리하지 못함(계약 불일치·핸들러 미지원).
- (가설 B) **주입 아티팩트**: 주입한 이벤트가 audit이 기대하는 형식(예: CloudEvent envelope/공통메타 필드)과 달라 발생한 false alarm. 실 서비스 발행 경로에서는 재현 안 될 수 있음.

→ **owner는 먼저 실 서비스 발행(engagement/learning이 정상 발행한 ReviewCompleted)으로 재현되는지 확인**할 것.

## 현재 상태 / 조사 포인트

1. platform audit 컨슈머가 **어떤 토픽을 구독**하는지 확인 — `learning.card.review-completed-v1`을 audit 대상으로 의도했는가? (전 토픽 audit인지, 화이트리스트인지)
2. `ReviewCompleted` 역직렬화 계약 — audit 컨슈머의 디시리얼라이저(Avro/JSON)와 `src/main/avro/learning/ReviewCompleted.avsc` 정합.
3. DLT 적재 직전 예외 원인 로그 — `platform-audit-group` 컨슈머의 retry/DLT 트리거 스택트레이스 확보(현재 ERROR 미출력이라 로깅 레벨 상향 필요).
4. 의도된 미지원 이벤트라면 **DLT 대신 graceful skip**(audit 비대상 이벤트는 조용히 무시)로 바꿔 DLT 오염 방지.

## 정확한 변경 지점 (조사 후)

- platform audit consumer(`audit`/`notification` 도메인의 `*KafkaConsumer`) 구독 토픽·핸들러 점검.
- audit이 ReviewCompleted를 적재 대상으로 한다면: 역직렬화/매핑 수정 → audit_logs 적재 성공.
- 대상이 아니라면: 구독 필터에서 제외 또는 핸들러에서 graceful skip(+ 메트릭).

## 검증 (DoD)

- [ ] 실 서비스 발행 ReviewCompleted로 재현 여부 확정(가설 A/B 판별)
- [ ] (A인 경우) audit_logs에 ReviewCompleted 적재 성공 또는 graceful skip 적용
- [ ] `learning.card.review-completed-v1.DLT` 신규 적재 0
- [ ] audit 컨슈머 retry 루프 없음

## 참조
- synapse-shared `docs/project-management/HANDOFF_W5_DAY3.md` §0 (신규 관찰)
- W5 Day3 라이브 검증 로그(2026-06-10): `platform-audit-group` DLT offset 11
- `src/main/avro/learning/ReviewCompleted.avsc`
