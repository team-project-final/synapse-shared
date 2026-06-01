# MSK 토픽 생성 가이드

## 사전 조건

1. **AWS 인증**: `aws sts get-caller-identity`로 확인
2. **네트워크 접근**: VPN 또는 SSM Bastion을 통해 MSK 보안그룹 내부 접근 필요
3. **Kafka CLI**: ⚠️ **bastion에 기본 미설치**(06-01 실측 — Java·Kafka 둘 다 없음). 별도 준비 필요: (a) Java+Kafka tarball 다운로드(NAT 필요) 또는 (b) **EKS 내부 kafka 파드**(aws-auth 매핑 선결, 권장)
4. **브로커 주소**: 환경별 bootstrap server 확인

## 환경별 브로커 주소

> ⚠️ **브로커 주소는 재apply(클러스터 재생성)마다 변경**(`fark5c`→`v2grm6` 06-01 확인). **하드코딩 금지 — 매 window마다 fetch**:
> `aws kafka get-bootstrap-brokers --cluster-arn $(aws kafka list-clusters-v2 --region ap-northeast-2 --query 'ClusterInfoList[0].ClusterArn' --output text) --region ap-northeast-2 --query BootstrapBrokerStringTls --output text`
> 변경 시 **gitops ConfigMap `KAFKA_BROKERS` 갱신** 필요.

| 환경 | Bootstrap Servers (TLS, 9094) — *재apply마다 변경, 위 명령으로 확인* |
|------|------------------|
| dev (06-01 현재) | `b-1.synapsedevkafka.v2grm6.c2.kafka.ap-northeast-2.amazonaws.com:9094,b-2.synapsedevkafka.v2grm6.c2.kafka.ap-northeast-2.amazonaws.com:9094` |
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
KAFKA_BROKERS="b-1.synapsedevkafka.v2grm6.c2.kafka.ap-northeast-2.amazonaws.com:9094,b-2.synapsedevkafka.v2grm6.c2.kafka.ap-northeast-2.amazonaws.com:9094" \
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

> 단일 출처: [EVENT_CONTRACT_STANDARD §2](./EVENT_CONTRACT_STANDARD.md). `create-kafka-topics.sh`는 **9개 엔트리 = 8 active + cards-generated(잔존)** 를 생성한다.

| 토픽 | 도메인 | 설명 |
|------|--------|------|
| `platform.auth.user-registered-v1` | Platform | 회원가입 이벤트 |
| `knowledge.note.note-created-v1` | Knowledge | 노트 생성 이벤트 |
| `knowledge.note.note-updated-v1` | Knowledge | 노트 수정 이벤트 |
| `learning.card.review-completed-v1` | Learning | 카드 복습 완료 이벤트 |
| `learning.card.review-due-v1` | Learning | 복습 예정 알림 이벤트 (W4 신규) |
| `engagement.gamification.level-up-v1` | Engagement | 레벨업 이벤트 (W4 신규) |
| `engagement.gamification.badge-earned-v1` | Engagement | 배지 획득 이벤트 (W4 신규) |
| `platform.notification.notification-send-v1` | Platform | 알림 발송 이벤트 (W4 신규) |
| ~~`learning.ai.cards-generated-v1`~~ | Learning | **deprecated (D-001: 카드 등록 HTTP)** — 발행자 없음, 호환 위해 잔존 |

## 롤백 (토픽 삭제)

> **주의**: 토픽 삭제는 데이터 손실을 수반합니다. dev 환경에서만 사용하세요.

```bash
kafka-topics.sh --bootstrap-server "$KAFKA_BROKERS" \
  --delete --topic platform.auth.user-registered-v1
```

전체 삭제 (생성 스크립트와 동일 9종):
```bash
for topic in \
  platform.auth.user-registered-v1 \
  knowledge.note.note-created-v1 \
  knowledge.note.note-updated-v1 \
  learning.card.review-completed-v1 \
  learning.card.review-due-v1 \
  engagement.gamification.level-up-v1 \
  engagement.gamification.badge-earned-v1 \
  platform.notification.notification-send-v1 \
  learning.ai.cards-generated-v1; do
  kafka-topics.sh --bootstrap-server "$KAFKA_BROKERS" --delete --topic "$topic"
done
```

## MSK 보안 설정

### TLS 통신 확인

MSK 브로커가 TLS(포트 9094)로 통신하는지 확인:

```bash
# bastion에서 실행
openssl s_client -connect <broker-host>:9094 -brief 2>&1 | head -5
```

Expected: `CONNECTION ESTABLISHED`, `Protocol: TLSv1.2` 또는 `TLSv1.3`

서비스 application.yml에서 TLS 설정:

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BROKERS}
    properties:
      security.protocol: SSL
      ssl.truststore.type: JKS
```

> MSK Serverless/Provisioned는 기본적으로 TLS를 제공합니다. PLAINTEXT(9092)는 비활성화 권장.

### SASL/IAM 인증 (선택)

MSK가 IAM 인증을 사용하는 경우:

```yaml
spring:
  kafka:
    properties:
      security.protocol: SASL_SSL
      sasl.mechanism: AWS_MSK_IAM
      sasl.jaas.config: >
        software.amazon.msk.auth.iam.IAMLoginModule required;
      sasl.client.callback.handler.class: software.amazon.msk.auth.iam.IAMClientCallbackHandler
```

Python (learning-ai):
```python
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

tp = MSKAuthTokenProvider(region='ap-northeast-2')
producer = KafkaProducer(
    bootstrap_servers=brokers,
    security_protocol='SASL_SSL',
    sasl_mechanism='OAUTHBEARER',
    sasl_oauth_token_provider=tp,
)
```

### Kafka ACL 설정 (SASL 비사용 시)

> ⚠️ **아래 ACL 예시는 W2 원본 5토픽 기준** — W4 신규 4종(review-due/level-up/badge-earned/notification-send) 및 D-001(cards-generated HTTP, platform consume 소멸)을 미반영. 실제 권한은 [EVENT_CONTRACT_STANDARD §2](./EVENT_CONTRACT_STANDARD.md)의 producer/consumer를 따를 것. **MSK IAM 인증 사용 시 ACL 대신 IAM Policy로 제어 → 이 섹션 불필요**(권장).

서비스별 최소 권한 ACL (참고용, 갱신 필요):

```bash
BROKER="$KAFKA_BROKERS"

# platform-svc: produce user-registered, consume cards-generated
kafka-acls.sh --bootstrap-server "$BROKER" --add \
  --allow-principal "User:platform-svc" \
  --producer --topic "platform.auth.user-registered-v1"
kafka-acls.sh --bootstrap-server "$BROKER" --add \
  --allow-principal "User:platform-svc" \
  --consumer --topic "learning.ai.cards-generated-v1" \
  --group "platform-svc-group"

# knowledge-svc: produce note-created, note-updated
kafka-acls.sh --bootstrap-server "$BROKER" --add \
  --allow-principal "User:knowledge-svc" \
  --producer --topic "knowledge.note.note-created-v1"
kafka-acls.sh --bootstrap-server "$BROKER" --add \
  --allow-principal "User:knowledge-svc" \
  --producer --topic "knowledge.note.note-updated-v1"

# learning-card: produce review-completed
kafka-acls.sh --bootstrap-server "$BROKER" --add \
  --allow-principal "User:learning-card" \
  --producer --topic "learning.card.review-completed-v1"

# learning-ai: produce cards-generated, consume note-created
kafka-acls.sh --bootstrap-server "$BROKER" --add \
  --allow-principal "User:learning-ai" \
  --producer --topic "learning.ai.cards-generated-v1"
kafka-acls.sh --bootstrap-server "$BROKER" --add \
  --allow-principal "User:learning-ai" \
  --consumer --topic "knowledge.note.note-created-v1" \
  --group "learning-ai-svc-group"

# engagement-svc: consume user-registered, review-completed
kafka-acls.sh --bootstrap-server "$BROKER" --add \
  --allow-principal "User:engagement-svc" \
  --consumer --topic "platform.auth.user-registered-v1" \
  --group "engagement-svc-group"
kafka-acls.sh --bootstrap-server "$BROKER" --add \
  --allow-principal "User:engagement-svc" \
  --consumer --topic "learning.card.review-completed-v1" \
  --group "engagement-svc-group"

# ACL 확인
kafka-acls.sh --bootstrap-server "$BROKER" --list
```

> **Note**: MSK IAM 인증 사용 시 ACL 대신 IAM Policy로 토픽 접근을 제어합니다. 이 경우 위 ACL 설정은 불필요합니다.

---

## 다음 세션 실행 절차 (terraform apply 후)

인프라 재기동 후 아래 순서대로 한 번에 실행:

```bash
# 1. terraform apply (gitops 레포에서)
cd synapse-gitops && terraform apply

# 2. EKS kubeconfig 갱신
aws eks update-kubeconfig --name synapse-dev --region ap-northeast-2

# 3. MSK 브로커 주소 확인 (terraform apply 후 변경될 수 있음)
aws kafka get-bootstrap-brokers --cluster-arn <cluster-arn> --region ap-northeast-2

# 4. bastion SSM 접속
aws ssm start-session --target <bastion-instance-id> --region ap-northeast-2

# 5. MSK 토픽 생성
KAFKA_BROKERS="<new-broker-address>" bash scripts/create-kafka-topics.sh

# 6. TLS 통신 확인
openssl s_client -connect <broker-host>:9094 -brief 2>&1 | head -5

# 7. 송수신 테스트 (bastion 또는 kafka Pod에서)
echo '{"test":"ping"}' | kafka-console-producer.sh \
  --bootstrap-server "$KAFKA_BROKERS" --topic platform.auth.user-registered-v1
kafka-console-consumer.sh --bootstrap-server "$KAFKA_BROKERS" \
  --topic platform.auth.user-registered-v1 --from-beginning --max-messages 1 --timeout-ms 10000

# 8. (선택) ACL 설정 — SASL 비사용 환경에서만
# 위 ACL 섹션 명령어 실행

# 9. ArgoCD 서비스 상태 확인
kubectl get pods -n synapse-dev
bash scripts/verify-argocd-deploy.sh synapse-dev
```

---

## Bastion 검증 실행 (SSM) — 2~4단계 (재apply window)

> EKS 엔드포인트가 **프라이빗 전용**이라 kubectl/argocd/MSK는 **VPC 내부 bastion에서만**. bastion = `i-0702b02eee5ed19d6`(`synapse-dev-bastion`, SSM Online). MSK는 **TLS(9094)·SASL/IAM 미활성** → `--command-config`(SSL) 필수.

### 0. 접속 + 스크립트 확보
```bash
aws ssm start-session --target i-0702b02eee5ed19d6 --region ap-northeast-2
# bastion 내부:
git clone https://github.com/team-project-final/synapse-shared.git && cd synapse-shared   # 토큰 필요. 불가 시 Step2는 인라인(아래)
```

### Step 2 — MSK 9토픽 생성 (TLS)

> ⚠️ **bastion 역할 권한 갭**: `synapse-dev-bastion-role`에 `kafka:ListClustersV2`(및 `GetBootstrapBrokers`)가 **없음**(06-01 확인) → bastion에서 직접 fetch 시 `AccessDeniedException`. 아래 우선순위로 BROKER 확보:
> 1. **(권장)** 권한 있는 머신(team-lead 로컬)에서 fetch한 값을 **직접 지정** ↓
> 2. (durable) 인프라가 bastion 역할에 `kafka:DescribeCluster*`·`GetBootstrapBrokers`·`ListClustersV2` 추가(terraform) 후 fetch

```bash
# 1) BROKER 직접 지정 — 재apply마다 team-lead가 fetch해 전달(아래는 06-01 v2grm6 값)
BROKER="b-1.synapsedevkafka.v2grm6.c2.kafka.ap-northeast-2.amazonaws.com:9094,b-2.synapsedevkafka.v2grm6.c2.kafka.ap-northeast-2.amazonaws.com:9094"
#    (권한 있으면 ARN 명시 fetch도 가능)
#    aws kafka get-bootstrap-brokers --region ap-northeast-2 \
#      --cluster-arn arn:aws:kafka:ap-northeast-2:963773969059:cluster/synapse-dev-kafka/a82f880a-d195-4223-ae1b-c7aee86ce5d8-2 \
#      --query BootstrapBrokerStringTls --output text
printf 'security.protocol=SSL\n' > /tmp/client.properties      # MSK = TLS 암호화, 클라이언트 인증 없음

# (A) 스크립트 — TLS 지원 추가됨(COMMAND_CONFIG)
COMMAND_CONFIG=/tmp/client.properties KAFKA_BROKERS="$BROKER" REPLICATION_FACTOR=3 MIN_INSYNC_REPLICAS=2 \
  bash scripts/create-kafka-topics.sh
# (B) clone 불가 시 인라인
for t in platform.auth.user-registered-v1 knowledge.note.note-created-v1 knowledge.note.note-updated-v1 \
  learning.card.review-completed-v1 learning.card.review-due-v1 engagement.gamification.level-up-v1 \
  engagement.gamification.badge-earned-v1 platform.notification.notification-send-v1 learning.ai.cards-generated-v1; do
  kafka-topics.sh --bootstrap-server "$BROKER" --command-config /tmp/client.properties \
    --create --if-not-exists --topic "$t" --partitions 3 --replication-factor 3 \
    --config min.insync.replicas=2 --config retention.ms=604800000
done
kafka-topics.sh --bootstrap-server "$BROKER" --command-config /tmp/client.properties --list   # 9토픽 확인
```

### Step 3 — dev 배포 검증 (bastion은 private endpoint 접근 가능)
```bash
aws eks update-kubeconfig --name synapse-dev --region ap-northeast-2
kubectl get nodes && kubectl get pods -n synapse-dev
bash scripts/verify-argocd-deploy.sh synapse-dev      # 5/5 (Sync/Health/ExternalSecret)
```
> 선결: bastion에 `kubectl`+`argocd` CLI. argocd 사용 시 `argocd login <argocd-server> --sso`(또는 admin) 먼저.

### Step 4 — Schema Registry BACKWARD 실등록 (REST, **docker-exec harness 아님**)
> 로컬 `kafka-e2e-test.sh --avro`는 docker-compose 전용 → 클러스터엔 부적합. dev Schema Registry **REST API**로 검증:
```bash
kubectl get svc -A | grep -i schema-registry                       # 배포 위치 확인
kubectl -n <ns> port-forward svc/<schema-registry> 8081:8081 &
curl -s localhost:8081/config        # {"compatibilityLevel":"BACKWARD"} 기대
curl -s localhost:8081/subjects      # 등록된 <topic>-value 목록
# 호환성 체크(예: LevelUp)
curl -s -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data "$(jq -Rs '{schema:.}' src/main/avro/engagement/LevelUp.avsc)" \
  localhost:8081/compatibility/subjects/engagement.gamification.level-up-v1-value/versions/latest
# → {"is_compatible":true} 기대. 게이트 §1(레지스트리 BACKWARD) 해소 근거
```
> ⚠️ dev에 Schema Registry **미배포면** 이 단계는 SR 배포(gitops) 후. (W3 게이트 §1 "URL 미설정"이 이 맥락.)

### 종료
결과(토픽 9 / verify 5/5 / SR BACKWARD)를 team-lead에 전달 → 게이트 §1·HANDOFF 갱신. 서비스 미머지 상태면 검증 후 **EKS destroy**(비용).

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| Connection refused | 보안그룹 미허용 또는 VPN 미연결 | SG inbound 9094 확인, VPN/Bastion 연결 확인 |
| TopicExistsException | 토픽 이미 존재 | 정상 — 스크립트가 자동 스킵 |
| InvalidReplicationFactorException | RF > broker 수 | `REPLICATION_FACTOR` 값을 broker 수 이하로 설정 |
