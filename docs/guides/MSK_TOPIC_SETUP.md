# MSK 토픽 생성 가이드

## 사전 조건

1. **AWS 인증**: `aws sts get-caller-identity`로 확인
2. **네트워크 접근**: VPN 또는 SSM Bastion을 통해 MSK 보안그룹 내부 접근 필요
3. **Kafka CLI**: `kafka-topics.sh` 사용 가능 (MSK Bastion에 설치됨)
4. **브로커 주소**: 환경별 bootstrap server 확인

## 환경별 브로커 주소

| 환경 | Bootstrap Servers |
|------|------------------|
| dev | `b-1.synapsedevkafka.fark5c.c2.kafka.ap-northeast-2.amazonaws.com:9094,b-2.synapsedevkafka.fark5c.c2.kafka.ap-northeast-2.amazonaws.com:9094` |
| staging | TBD (인프라 프로비저닝 후 업데이트) |
| prod | TBD (인프라 프로비저닝 후 업데이트) |

## 실행 방법

### Step 1: Bastion 접속

```bash
aws ssm start-session --target <bastion-instance-id> --region ap-northeast-2
```

### Step 2: 스크립트 실행

**Dev 환경 (replication-factor=3, min.insync.replicas=2):**
```bash
KAFKA_BROKERS="b-1.synapsedevkafka.fark5c.c2.kafka.ap-northeast-2.amazonaws.com:9094,b-2.synapsedevkafka.fark5c.c2.kafka.ap-northeast-2.amazonaws.com:9094" \
  bash scripts/create-kafka-topics.sh
```

**로컬 Docker Compose (replication-factor=1):**
```bash
KAFKA_BROKERS="localhost:9092" REPLICATION_FACTOR=1 MIN_INSYNC_REPLICAS=1 \
  bash scripts/create-kafka-topics.sh
```

### Step 3: 생성 확인

```bash
kafka-topics.sh --bootstrap-server "$KAFKA_BROKERS" --describe --topic platform.auth.user-registered-v1
```

Expected:
- Partitions: 3
- ReplicationFactor: 3 (dev/staging/prod) or 1 (local)
- Configs: retention.ms=604800000, cleanup.policy=delete, min.insync.replicas=2

## 생성되는 토픽 목록

| 토픽 | 도메인 | 설명 |
|------|--------|------|
| `platform.auth.user-registered-v1` | Platform | 회원가입 이벤트 |
| `knowledge.note.note-created-v1` | Knowledge | 노트 생성 이벤트 |
| `knowledge.note.note-updated-v1` | Knowledge | 노트 수정 이벤트 |
| `learning.card.review-completed-v1` | Learning | 카드 복습 완료 이벤트 |
| `learning.ai.cards-generated-v1` | Learning | AI 카드 생성 완료 이벤트 |

## 롤백 (토픽 삭제)

> **주의**: 토픽 삭제는 데이터 손실을 수반합니다. dev 환경에서만 사용하세요.

```bash
kafka-topics.sh --bootstrap-server "$KAFKA_BROKERS" \
  --delete --topic platform.auth.user-registered-v1
```

전체 삭제:
```bash
for topic in platform.auth.user-registered-v1 knowledge.note.note-created-v1 knowledge.note.note-updated-v1 learning.card.review-completed-v1 learning.ai.cards-generated-v1; do
  kafka-topics.sh --bootstrap-server "$KAFKA_BROKERS" --delete --topic "$topic"
done
```

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| Connection refused | 보안그룹 미허용 또는 VPN 미연결 | SG inbound 9094 확인, VPN/Bastion 연결 확인 |
| TopicExistsException | 토픽 이미 존재 | 정상 — 스크립트가 자동 스킵 |
| InvalidReplicationFactorException | RF > broker 수 | `REPLICATION_FACTOR` 값을 broker 수 이하로 설정 |
