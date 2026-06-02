# Kafka 인증 모델 + 서비스별 권한 매트릭스

> **작성**: 2026-06-01 (W4 Day 1) · **갱신**: 2026-06-02 (gitops — B/TLS-only 정합) · **owner**: @team-lead · **상태**: 확정(문서) / 적용 = EKS window
> **근거**: [EVENT_CONTRACT_STANDARD §2](./EVENT_CONTRACT_STANDARD.md) (토픽·Producer·Consumer 단일 출처) · [MSK_TOPIC_SETUP](./MSK_TOPIC_SETUP.md) · PRD_W4 FR-PL-401/404
> **대응 항목**: WORKFLOW_team-lead_W3 Step 7 **1.3 Kafka 토픽 ACL/권한 확인**

---

## 1. 인증 모델 결정 — **TLS-only 채택 (B) · IAM/ACL 미사용**

> ✅ **결정(2026-06-02, gitops)**: **B(TLS-only) 확정**. `msk.tf`는 TLS 암호화만 유지(SASL/IAM 미활성), 서비스 코드·config 무변경. A(SASL/IAM)는 5개 서비스 `aws-msk-iam-auth` 의존성·IRSA 매트릭스가 필요해 캡스톤 잔여 봉합 범위 밖 → **W5+ 백로그**. 근거: gitops spec `2026-06-02-w4-remaining-msk-terraform-tls-design.md` §3. (06-01 실측 `BootstrapBrokerStringSaslIam=null` = IAM 미활성 상태를 그대로 채택.)

| 환경 | 프로토콜 | 인증 | 권한 제어 |
|------|---------|------|----------|
| **로컬 docker-compose** | PLAINTEXT (9092) | 없음 | 없음 (throwaway 스택) |
| **dev / staging / prod (MSK)** | TLS (9094) | 없음 (전송 암호화) | **SG/네트워크 경계** (per-topic 세분 인가 없음) |

**결정 근거**: MSK는 private subnet 내부에서만 도달(EKS 노드 SG ↔ MSK SG 9094). 토픽은 terraform 선언 관리(`infra/aws/dev/kafka-topics/`)로 생성하고, 인가는 네트워크 경계로 제어한다. per-topic 최소권한(IAM)은 실 운영 가치가 크나 서비스 코드 변경·타 owner 의존이 커 캡스톤에서는 회수되지 않아 미채택. Kafka ACL도 미사용.

> 로컬은 인증 없음 → `kafka-e2e-test.sh`/서비스가 그대로 동작. dev/staging/prod는 TLS(9094)로 접속하며 추가 인증 properties 불필요(§4).

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

## 3. IAM Policy 예시 (A안 백로그 참조용 — **미적용**)

> ⚠️ **B(TLS-only) 채택으로 본 섹션은 미적용.** 아래 IAM Policy는 향후 A(SASL/IAM) 전환 시 참조용으로만 보존(W5+ 백로그, §1·§5).

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

## 4. 서비스 application.yml 인증 설정 (dev MSK) — **B(TLS-only)**

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BROKERS}          # MSK 9094 (TLS)
    properties:
      security.protocol: SSL
      # TLS-only: 브로커 인증서 = Amazon Trust Services CA 체인 → JVM 기본 truststore로 검증.
      # 클라이언트 인증서·SASL 불필요(상호 TLS 아님). 별도 properties 없음.
```
- Python(learning-ai): `security.protocol=SSL`만 설정(기본 CA truststore). `aws-msk-iam-*` 불필요.
- **로컬**은 PLAINTEXT — 프로파일 분리(`application-local` vs `application-dev`).
- ⚠️ A(SASL/IAM) 전환 시에만 `SASL_SSL` + `AWS_MSK_IAM` + `aws-msk-iam-auth` 의존성 추가(W5+ 백로그, §3).

---

## 5. 적용 시점 / 소유 (B: TLS-only)

| 단계 | 소유 | 시점 |
|------|------|------|
| 인증 모델 결정(B) + 권한 매트릭스(본 문서) | team-lead / gitops | ✅ 확정(2026-06-02) |
| 토픽 terraform 선언화(`kafka-topics/`) + apply | **gitops** | EKS window(2026-06-04) |
| 서비스 `application-{env}.yml` TLS 설정(`security.protocol: SSL`) | 각 서비스 owner | 서비스 Kafka 구현 시 |
| 실제 동작 검증(produce/consume, TLS) | team-lead | EKS window |
| ~~IAM Policy + IRSA~~ (A안) | gitops | **미적용 — W5+ 백로그** |

> WORKFLOW_W3 7-1.3의 설계·결정 완료. B(TLS-only)에서는 IAM/IRSA 적용 없이 토픽 terraform apply + TLS 접속 검증만 EKS window에서.
