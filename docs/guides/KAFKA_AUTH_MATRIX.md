# Kafka 인증 모델 + 서비스별 권한 매트릭스

> **작성**: 2026-06-01 (W4 Day 1) · **owner**: @team-lead · **상태**: 확정(문서) / 적용 = EKS window
> **근거**: [EVENT_CONTRACT_STANDARD §2](./EVENT_CONTRACT_STANDARD.md) (토픽·Producer·Consumer 단일 출처) · [MSK_TOPIC_SETUP](./MSK_TOPIC_SETUP.md) · PRD_W4 FR-PL-401/404
> **대응 항목**: WORKFLOW_team-lead_W3 Step 7 **1.3 Kafka 토픽 ACL/권한 확인**

---

## 1. 인증 모델 결정 — **MSK IAM 채택 (ACL 미사용)**

| 환경 | 프로토콜 | 인증 | 권한 제어 |
|------|---------|------|----------|
| **로컬 docker-compose** | PLAINTEXT (9092) | 없음 | 없음 (throwaway 스택) |
| **dev / staging / prod (MSK)** | SASL_SSL (9094) | **AWS_MSK_IAM** | **IAM Policy** (IRSA로 서비스 SA에 연결) |

**결정 근거**: MSK IAM 인증 시 토픽 접근은 **IAM Policy로 제어** → Kafka ACL **불필요**(MSK_TOPIC_SETUP "Note" 동일). IAM은 EKS IRSA와 결합해 서비스별 최소권한을 선언적으로 관리(gitops). ACL(SASL 비사용)은 폴백으로만 보존([MSK_TOPIC_SETUP](./MSK_TOPIC_SETUP.md) ACL 섹션).

> 로컬은 인증 없음 → `kafka-e2e-test.sh`/서비스가 그대로 동작. dev부터 IAM 적용.

---

## 2. 서비스별 권한 매트릭스 (단일 출처 = EVENT_CONTRACT_STANDARD §2)

| 서비스 | PRODUCE (write) | CONSUME (read) | Consumer Group |
|--------|-----------------|----------------|----------------|
| **platform** | `platform.auth.user-registered-v1` | **[알림]** `learning.card.review-due-v1`, `engagement.gamification.level-up-v1`, `engagement.gamification.badge-earned-v1`, `platform.notification.notification-send-v1` · **[audit]** 전 도메인 토픽(8) | `platform-notification-group`, `platform-audit-group` |
| **knowledge** | `knowledge.note.note-created-v1`, `knowledge.note.note-updated-v1` | — | — |
| **learning-card** | `learning.card.review-completed-v1`, `learning.card.review-due-v1` | — | — |
| **learning-ai** | `platform.notification.notification-send-v1` (AI카드 알림, [NOTIFICATION_TRIGGER_AI_CARDS](../designs/NOTIFICATION_TRIGGER_AI_CARDS.md)) | `knowledge.note.note-created-v1` | `learning-ai-svc-group` |
| **engagement** | `engagement.gamification.level-up-v1`, `engagement.gamification.badge-earned-v1` | `platform.auth.user-registered-v1`, `learning.card.review-completed-v1` | `engagement-svc-group` |

> 비고:
> - **platform = audit 싱크**(FR-PL-404): 전 도메인 이벤트 → `audit_logs`(90일). audit 그룹은 **모든 토픽 read**.
> - **platform = notification 싱크**(FR-PL-401): review-due / level-up / badge-earned / notification-send → FCM/SES.
> - `learning.ai.cards-generated-v1`는 **deprecated(D-001 HTTP)** → 어떤 서비스도 produce/consume 안 함(토픽만 잔존).
> - 멱등 producer 사용 시 `WriteDataIdempotently` 추가 필요.

---

## 3. IAM Policy 예시 (engagement — 대표 1건)

> ARN 형식: `arn:aws:kafka:ap-northeast-2:<account>:topic/<cluster>/<cluster-uuid>/<topic>` · group은 `.../group/...`. `<cluster>`/`<uuid>`는 `aws kafka describe-cluster`로 확인.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "Connect", "Effect": "Allow",
      "Action": ["kafka-cluster:Connect", "kafka-cluster:DescribeCluster"],
      "Resource": "arn:aws:kafka:ap-northeast-2:<account>:cluster/synapse-dev/*" },
    { "Sid": "Produce", "Effect": "Allow",
      "Action": ["kafka-cluster:WriteData", "kafka-cluster:DescribeTopic"],
      "Resource": [
        "arn:aws:kafka:ap-northeast-2:<account>:topic/synapse-dev/*/engagement.gamification.level-up-v1",
        "arn:aws:kafka:ap-northeast-2:<account>:topic/synapse-dev/*/engagement.gamification.badge-earned-v1"
      ] },
    { "Sid": "Consume", "Effect": "Allow",
      "Action": ["kafka-cluster:ReadData", "kafka-cluster:DescribeTopic"],
      "Resource": [
        "arn:aws:kafka:ap-northeast-2:<account>:topic/synapse-dev/*/platform.auth.user-registered-v1",
        "arn:aws:kafka:ap-northeast-2:<account>:topic/synapse-dev/*/learning.card.review-completed-v1"
      ] },
    { "Sid": "Group", "Effect": "Allow",
      "Action": ["kafka-cluster:AlterGroup", "kafka-cluster:DescribeGroup"],
      "Resource": "arn:aws:kafka:ap-northeast-2:<account>:group/synapse-dev/*/engagement-svc-group" }
  ]
}
```

> 나머지 4개 서비스는 §2 매트릭스의 produce/consume/group을 위 패턴에 대입. **platform**은 audit 그룹이 전 토픽 read이므로 Consume Resource = `.../topic/synapse-dev/*/*`(전체) + 두 그룹(`platform-notification-group`, `platform-audit-group`).

---

## 4. 서비스 application.yml 인증 설정 (dev MSK)

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BROKERS}          # MSK 9094 (TLS)
    properties:
      security.protocol: SASL_SSL
      sasl.mechanism: AWS_MSK_IAM
      sasl.jaas.config: software.amazon.msk.auth.iam.IAMLoginModule required;
      sasl.client.callback.handler.class: software.amazon.msk.auth.iam.IAMClientCallbackHandler
```
- Python(learning-ai): `aws-msk-iam-sasl-signer` + `MSKAuthTokenProvider` (MSK_TOPIC_SETUP §SASL/IAM).
- **로컬**은 위 properties 없이 PLAINTEXT — 프로파일 분리(`application-local` vs `application-dev`).

---

## 5. 적용 시점 / 소유 (A/B 구분)

| 단계 | 소유 | 시점 |
|------|------|------|
| 인증 모델 결정 + 권한 매트릭스(본 문서) | team-lead | ✅ 지금(문서 확정) |
| 서비스 `application-{env}.yml` IAM 설정 | 각 서비스 owner | 서비스 Kafka 구현 시 |
| **IAM Policy + IRSA(서비스 SA 연결)** | **gitops `(A)`** | **EKS window**(재기동) |
| 실제 권한 검증(produce/consume 동작) | team-lead | EKS window |

> 본 문서로 WORKFLOW_W3 7-1.3의 **설계·결정 부분은 완료**. 실제 IAM/IRSA 적용·검증만 EKS 재기동 window에서.
