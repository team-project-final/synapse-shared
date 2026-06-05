# W4 통합 E2E 결과 리포트 (전송/계약 레벨)

> **실행**: 2026-06-05 (W4 Day 4) · **환경**: 로컬 docker-compose (kafka 7.7.0 + schema-registry + zookeeper) · **하니스**: `scripts/kafka-e2e-test.sh`
> **범위**: Kafka 전송 경로 + CloudEvent 단위 round-trip + Avro/Registry 계약 round-trip. **서비스 비즈니스 로직 E2E는 미포함**(아래 §주의).

## 결과 요약 — 전부 PASS

| 모드 | 내용 | 결과 | 시간 |
|---|---|---|---|
| `--avro` | 8토픽 Avro+Registry 라운드트립(subject 등록+발행+역직렬화) = **계약 게이트 §1** | **8/8 PASS** | 57s |
| `--all` | 핵심 전송 경로 produce/consume | **5/5 PASS** | 29s |
| `--full` | 전 토픽 전송 + CloudEvent 필드 검증 | **13/13 PASS** | 70s |
| `--scenarios` | S1~S4 의존성 순서 produce/consume | **5/5 PASS** | 29s |

- 토픽 11종 생성(kafka-init), schema-registry `/subjects` 200 확인.
- `--scenarios` S3-2는 D-001(cards-generated HTTP)로 전송만 검증, 서비스 트리거는 재설계 open.

## ⚠️ 범위 주의 — 서비스 비즈니스 로직 E2E는 별도
synapse-shared `docker-compose.yml`의 app 컨테이너(platform/engagement/knowledge/learning)는 **스텁**(`sleep infinity`)이다. 따라서 본 리포트는 **전송·계약 레벨**만 입증하며, PRD_W4 §5의 소비자 비즈니스 로직(FCM 발송·audit_logs 적재·XP/레벨업·검색 정확도·AI 카드)은 **검증 대상이 아니다**. 각 `[SERVICE-CHECK]` 단계는 "서비스 구현 후 수행"으로 표시됨.

**서비스 단위 E2E를 하려면**: 각 서비스 레포의 실제 스택(자체 compose/Testcontainers) 또는 EKS staging에서 4서비스 origin/main 빌드를 기동해 consumer 동작을 확인해야 한다. 4서비스 Kafka는 전원 origin/main 머지 완료([W4_EXIT_GATE](./W4_EXIT_GATE.md))라 머지 차단은 없음 — 잔여는 "실행"뿐.

## 판정
- ✅ **계약·전송 베이스라인 06-05 재검증 완료** — W3 베이스라인(--all 5/5, --full 13/13) + 계약 게이트 §1(--avro 8/8) 유지.
- 🟡 PRD_W4 §5 소비자 비즈니스 로직 E2E = **W5 서비스 스택/ staging에서 실행 잔여**.
