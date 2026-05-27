# W3 로컬 E2E harness 베이스라인

> **작성일**: 2026-05-26 (W3 Day 1)
> **목적**: 서비스 Kafka 구현 0인 상태에서 harness(토픽/전송/스크립트) 자체 동작 검증

## 환경
- docker-compose 로컬, Kafka `kafka:29092`, 토픽 5개 생성됨
- 기동 서비스: zookeeper, kafka, schema-registry (harness는 `synapse-kafka` 컨테이너의 console 도구 사용)

## 결과 (`scripts/kafka-e2e-test.sh --all`)

| 항목 | 값 |
|------|----|
| PASS | 5 |
| FAIL | 0 |
| TIME | 29s |
| RESULT | **PASSED** |

5개 토픽 모두 produce → consume 라운드트립 성공.

## 발견 사항 (정직 기록)

### D-1: kafka 기동 실패 → 클린 재생성으로 해결
- 증상: `docker compose up` 시 `synapse-kafka`가 `Exited (1)`.
- 근본 원인: Zookeeper 볼륨에 5일 전 unclean shutdown의 **stale ephemeral broker znode**(`/brokers/ids/1`) 잔존 → 신규 broker(id=1) 등록 시 `NodeExistsException` 으로 fatal 종료.
- 해결: `docker compose down -v`로 볼륨 정리 후 재기동(로컬 throwaway 스택 — 시드 데이터는 `src/test/resources/seed/`에서 재적용 가능). kafka `Healthy` 확인.
- 재발 방지: 세션 종료 시 `docker compose down -v` 권장(다음 세션 클린 시작).

### D-2: 전 토픽 CONSUME "WARN — unexpected format" (전송은 PASS)
- 증상: 5개 토픽 모두 `[CONSUME] WARN — message received but unexpected format`. 단 PASS로 집계(RESULT=PASSED).
- 근본 원인: E2E 샘플(`e2e-samples/*.json`)이 **멀티라인 pretty-print JSON**(17~19줄). `kafka-console-producer`는 **줄 단위로 메시지 분리** → 각 샘플이 ~17개 단편 메시지로 발행되고, consumer `--max-messages 1`이 첫 줄(`{`)만 읽어 `"specversion"` 미검출 → WARN.
- 영향: **전송 경로(produce→consume)는 정상 검증됨.** 다만 CloudEvent 페이로드 단위 검증은 현재 harness로는 불완전.
- 후속(W3 Day2~ 또는 W4): 샘플을 `jq -c`로 1라인 압축하거나, 스크립트가 produce 전 메시지를 compact하도록 개선. (Day1 베이스라인 범위 밖)
- **✅ 해결 (Day 2, 05-27)**: `scripts/kafka-e2e-test.sh`에 `compact_json` 헬퍼 추가 — produce 직전 `jq -c`로 1라인 압축(깨진 JSON은 `tr -d '\r\n'` fallback). 샘플 1개 = 메시지 1개로 발행되어 consumer가 온전한 CloudEvent를 읽고 `"specversion"` 검출. 클린 토픽 재검증 결과 `--all` 5/5 모두 `[CONSUME] OK — validated`(WARN 0건), `--full` 13/13 PASSED. CloudEvent 페이로드 단위 round-trip 검증이 이제 신뢰 가능.

## 해석

- 이 테스트는 **전송 경로(토픽 produce→consume)** 검증이며, 서비스의 consumer 비즈니스 로직은 검증하지 않는다.
- CloudEvent 페이로드 단위 round-trip 검증은 D-2 해결(Day 2)로 **신뢰 가능**. (단, consumer 비즈니스 로직 검증은 서비스 구현 도착 시 시나리오 테스트로 별도 확장)
- 서비스 구현 도착 시(Day 2~3) `E2E_SCENARIOS_W3.md` 시나리오로 consumer 처리까지 확장 검증.
