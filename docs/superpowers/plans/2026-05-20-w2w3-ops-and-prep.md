# W2/W3 운영 정비 + E2E 검증 준비 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 미해결 운영 항목(브랜치 통일, CI deprecation, MSK 토픽)을 정리하고, W3 Kafka E2E 검증 + ArgoCD 배포를 위한 사전 준비를 완료한다.

**Architecture:** 6개 작업을 순차 실행한다. 직접 코드 변경은 별도 브랜치에서 수행 후 PR을 생성한다. 외부 의존(팀원 구현, MSK 실행)이 있는 작업은 스크립트/문서/계획만 준비한다.

**Tech Stack:** GitHub Actions, Bash, Kafka CLI, Kustomize, ArgoCD, PostgreSQL

**브랜치 전략:** 모든 코드 변경은 feature 브랜치에서 작업 후 PR 생성. main/dev 직접 푸시 금지. 대부분의 레포는 `main`이 기본 브랜치이므로 `main` 기준으로 브랜치 생성 → `main` 대상 PR.

---

## File Structure

### 신규 생성 파일
| 파일 | 역할 |
|------|------|
| `docs/guides/MSK_TOPIC_SETUP.md` | MSK 토픽 생성 실행 가이드 |
| `docs/guides/KAFKA_E2E_TEST.md` | Kafka E2E 검증 체크리스트 |
| `docs/guides/ARGOCD_DEPLOY_VERIFICATION.md` | ArgoCD 배포/검증/롤백 절차 |
| `docs/guides/TEAM_CHECKLIST_W3.md` | 팀원별 Kafka 구현 체크리스트 |
| `scripts/kafka-e2e-test.sh` | Kafka E2E produce/consume 테스트 스크립트 |
| `scripts/seed-test-data.sh` | PostgreSQL 테스트 데이터 시드 스크립트 |
| `src/test/resources/e2e-samples/*.json` | 토픽별 샘플 이벤트 데이터 |
| `src/test/resources/seed/V001__test_users.sql` | 테스트 유저 시드 |
| `src/test/resources/seed/V002__test_notes.sql` | 테스트 노트 시드 |
| `src/test/resources/seed/V003__test_cards.sql` | 테스트 카드 시드 |

### 수정 파일
| 파일 | 변경 내용 |
|------|-----------|
| `scripts/create-kafka-topics.sh` | 연결 확인, 로깅, min.insync.replicas 추가 |
| `docs/project-management/HANDOFF_2026-05-19.md` | gateway 브랜치 참조 업데이트 |

### 외부 레포 수정 파일 (각 레포에서 별도 브랜치)
| 레포 | 파일 | 변경 |
|------|------|------|
| synapse-gateway | `.github/workflows/ci.yml` | `master` → `main` |
| synapse-gateway | `.github/workflows/deploy.yml` | `master` → `main`, `ecr-login@v2` → `@v3` |
| synapse-gitops | `.github/workflows/deploy-pages.yml` | `setup-dart@v1` → `@v2`, `upload-pages-artifact@v3` → `@v4` |
| synapse-gitops | `.github/workflows/validate-manifests.yml` | `setup-kustomize@v2` → `@v3` |
| documents | `.github/workflows/deploy-workflow-guide.yml` | `node-version: '20'` → `'22'` |
| schedule-repo | `.github/workflows/deploy.yml` | `node-version: 20` → `22`, `upload-pages-artifact@v3` → `@v4` |
| moking-data-guide | `.github/workflows/deploy.yml` | `upload-pages-artifact@v3` → `@v4` |
| workflow-dashboard | `.github/workflows/build.yml` | `upload-pages-artifact@v3` → `@v4` |

---

## Task 1: Gateway master → main 브랜치 변경

**Files:**
- Modify: `../synapse-gateway/.github/workflows/ci.yml:5,7`
- Modify: `../synapse-gateway/.github/workflows/deploy.yml:5`
- Modify: `docs/project-management/HANDOFF_2026-05-19.md:55`

- [ ] **Step 1: synapse-gateway에서 브랜치 생성**

```bash
cd ../synapse-gateway
git checkout master
git pull origin master
git checkout -b chore/rename-master-to-main
```

- [ ] **Step 2: ci.yml에서 master → main 변경**

`../synapse-gateway/.github/workflows/ci.yml` 수정:

```yaml
# 변경 전 (line 5, 7)
    branches: [master]

# 변경 후
    branches: [main]
```

두 곳 모두 변경 (line 5 push, line 7 pull_request).

- [ ] **Step 3: deploy.yml에서 master → main 변경**

`../synapse-gateway/.github/workflows/deploy.yml` 수정:

```yaml
# 변경 전 (line 5)
    branches: [master]

# 변경 후
    branches: [main]
```

- [ ] **Step 4: 변경 확인**

```bash
cd ../synapse-gateway
grep -rn "master" .github/workflows/
```

Expected: 결과 없음 (모든 master 참조 제거됨)

- [ ] **Step 5: 커밋**

```bash
cd ../synapse-gateway
git add .github/workflows/ci.yml .github/workflows/deploy.yml
git commit -m "chore: rename branch references master → main in workflows"
```

- [ ] **Step 6: 푸시 + PR 생성**

```bash
cd ../synapse-gateway
git push -u origin chore/rename-master-to-main
```

PR 생성 (gh CLI 또는 GitHub 웹):
- Title: `chore: rename branch references master → main`
- Base: `master` (현재 기본 브랜치)
- Body: gateway 워크플로의 master 참조를 main으로 변경. PR 머지 후 GitHub Settings에서 default branch를 main으로 변경 필요.

> **중요**: 이 PR 머지 후 GitHub repo settings → Default branch에서 `master` → `main` 변경 필요. 그 후 `master` 브랜치 삭제.

- [ ] **Step 7: synapse-shared HANDOFF 문서 업데이트**

`docs/project-management/HANDOFF_2026-05-19.md` line 55 수정:

```markdown
# 변경 전
5. **synapse-gateway 브랜치**: `master` 사용 중 (다른 레포는 `main`)

# 변경 후
5. **synapse-gateway 브랜치**: `main`으로 통일 완료 (PR #N 참조)
```

- [ ] **Step 8: 커밋**

```bash
cd ../synapse-shared
git add docs/project-management/HANDOFF_2026-05-19.md
git commit -m "docs: update HANDOFF — gateway branch renamed to main"
```

---

## Task 2: GitHub Actions Node.js 20 Deprecation 수정 — synapse-gateway

**Files:**
- Modify: `../synapse-gateway/.github/workflows/deploy.yml:33`

> **Note**: Task 1의 브랜치(`chore/rename-master-to-main`)가 아직 머지 안 됐으면, 같은 브랜치에서 이 변경도 함께 진행 가능. 별도 브랜치가 필요하면 `chore/upgrade-github-actions`로 생성.

- [ ] **Step 1: deploy.yml에서 ecr-login 버전 업그레이드**

`../synapse-gateway/.github/workflows/deploy.yml` line 33 수정:

```yaml
# 변경 전
        uses: aws-actions/amazon-ecr-login@v2

# 변경 후
        uses: aws-actions/amazon-ecr-login@v3
```

> `amazon-ecr-login@v3`은 v2와 동일한 출력(`outputs.registry`)을 제공하므로 line 37의 `${{ steps.ecr-login.outputs.registry }}` 참조는 변경 불필요.

- [ ] **Step 2: 변경 확인**

```bash
cd ../synapse-gateway
grep -n "ecr-login" .github/workflows/deploy.yml
```

Expected: `33:        uses: aws-actions/amazon-ecr-login@v3`

- [ ] **Step 3: 커밋 + 푸시**

Task 1 브랜치에 함께 넣는 경우:
```bash
cd ../synapse-gateway
git add .github/workflows/deploy.yml
git commit -m "chore: upgrade amazon-ecr-login@v2 → v3 (Node.js 20 deprecation)"
git push
```

별도 브랜치인 경우:
```bash
cd ../synapse-gateway
git checkout master
git checkout -b chore/upgrade-github-actions
git add .github/workflows/deploy.yml
git commit -m "chore: upgrade amazon-ecr-login@v2 → v3 (Node.js 20 deprecation)"
git push -u origin chore/upgrade-github-actions
```

PR 생성:
- Title: `chore: upgrade amazon-ecr-login v2 → v3`
- Body: Node.js 20 런타임 deprecation 대응. v3는 v2와 동일한 출력 인터페이스.

---

## Task 3: GitHub Actions Deprecation 수정 — synapse-gitops

**Files:**
- Modify: `../synapse-gitops/.github/workflows/deploy-pages.yml:32,40,56`
- Modify: `../synapse-gitops/.github/workflows/validate-manifests.yml:18`

- [ ] **Step 1: 브랜치 생성**

```bash
cd ../synapse-gitops
git checkout main
git pull origin main
git checkout -b chore/upgrade-github-actions
```

- [ ] **Step 2: deploy-pages.yml 수정 (3건)**

`../synapse-gitops/.github/workflows/deploy-pages.yml` 수정:

Line 32:
```yaml
# 변경 전
        uses: dart-lang/setup-dart@v1

# 변경 후
        uses: dart-lang/setup-dart@v2
```

Line 40:
```yaml
# 변경 전
        uses: subosito/flutter-action@v2

# 변경 후
        uses: subosito/flutter-action@v2
```

> `subosito/flutter-action@v2`는 현재 최신이므로 변경 없음.

Line 56:
```yaml
# 변경 전
        uses: actions/upload-pages-artifact@v3

# 변경 후
        uses: actions/upload-pages-artifact@v4
```

- [ ] **Step 3: validate-manifests.yml 수정 (1건)**

`../synapse-gitops/.github/workflows/validate-manifests.yml` line 18 수정:

```yaml
# 변경 전
        uses: imranismail/setup-kustomize@v2

# 변경 후
        uses: imranismail/setup-kustomize@v2
```

> `imranismail/setup-kustomize`는 v2가 최신 릴리스. npm16 경고는 이 액션의 내부 문제로, 메인테이너 업데이트를 대기하거나 대안(`yokawasa/action-setup-kube-tools`)을 고려. 현재는 변경하지 않고 주석으로 기록.

```yaml
      - name: Install kustomize
        # NOTE: setup-kustomize@v2 triggers Node.js 16 warning — no v3 available yet.
        # Alternative: direct curl install or yokawasa/action-setup-kube-tools
        uses: imranismail/setup-kustomize@v2
```

- [ ] **Step 4: 변경 확인**

```bash
cd ../synapse-gitops
grep -rn "@v1\|@v3" .github/workflows/deploy-pages.yml
grep -n "setup-kustomize" .github/workflows/validate-manifests.yml
```

Expected (deploy-pages.yml): `upload-pages-artifact@v4`만 남고 `@v1`, `@v3` 없음
Expected (validate-manifests.yml): `setup-kustomize@v2` + 주석

- [ ] **Step 5: 커밋 + 푸시 + PR**

```bash
cd ../synapse-gitops
git add .github/workflows/deploy-pages.yml .github/workflows/validate-manifests.yml
git commit -m "chore: upgrade GitHub Actions — setup-dart@v2, upload-pages-artifact@v4"
git push -u origin chore/upgrade-github-actions
```

PR 생성:
- Title: `chore: upgrade GitHub Actions for Node.js 20 deprecation`
- Base: `main`
- Body: `setup-dart@v1` → `@v2`, `upload-pages-artifact@v3` → `@v4`. `setup-kustomize@v2`는 최신이므로 주석만 추가.

---

## Task 4: GitHub Actions Deprecation 수정 — documents

**Files:**
- Modify: `../documents/.github/workflows/deploy-workflow-guide.yml:24`

- [ ] **Step 1: 브랜치 생성**

```bash
cd ../documents
git checkout main
git pull origin main
git checkout -b chore/upgrade-github-actions
```

- [ ] **Step 2: node-version 변경**

`../documents/.github/workflows/deploy-workflow-guide.yml` line 24 수정:

```yaml
# 변경 전
          node-version: '20'

# 변경 후
          node-version: '22'
```

- [ ] **Step 3: 커밋 + 푸시 + PR**

```bash
cd ../documents
git add .github/workflows/deploy-workflow-guide.yml
git commit -m "chore: upgrade node-version 20 → 22 (deprecation)"
git push -u origin chore/upgrade-github-actions
```

PR 생성:
- Title: `chore: upgrade node-version 20 → 22`
- Base: `main`

---

## Task 5: GitHub Actions Deprecation 수정 — schedule-repo

**Files:**
- Modify: `../schedule-repo/.github/workflows/deploy.yml:23,27`

- [ ] **Step 1: 브랜치 생성**

```bash
cd ../schedule-repo
git checkout main
git pull origin main
git checkout -b chore/upgrade-github-actions
```

- [ ] **Step 2: deploy.yml 수정 (2건)**

`../schedule-repo/.github/workflows/deploy.yml` 수정:

Line 23:
```yaml
# 변경 전
          node-version: 20

# 변경 후
          node-version: 22
```

Line 27:
```yaml
# 변경 전
      - uses: actions/upload-pages-artifact@v3

# 변경 후
      - uses: actions/upload-pages-artifact@v4
```

- [ ] **Step 3: 커밋 + 푸시 + PR**

```bash
cd ../schedule-repo
git add .github/workflows/deploy.yml
git commit -m "chore: upgrade node 20→22 + upload-pages-artifact@v4"
git push -u origin chore/upgrade-github-actions
```

PR 생성:
- Title: `chore: upgrade node-version + upload-pages-artifact`
- Base: `main`

---

## Task 6: GitHub Actions Deprecation 수정 — moking-data-guide

**Files:**
- Modify: `../moking-data-guide/.github/workflows/deploy.yml:26`

- [ ] **Step 1: 브랜치 생성**

```bash
cd ../moking-data-guide
git checkout main
git pull origin main
git checkout -b chore/upgrade-github-actions
```

- [ ] **Step 2: deploy.yml 수정**

`../moking-data-guide/.github/workflows/deploy.yml` line 26 수정:

```yaml
# 변경 전
      - uses: actions/upload-pages-artifact@v3

# 변경 후
      - uses: actions/upload-pages-artifact@v4
```

- [ ] **Step 3: 커밋 + 푸시 + PR**

```bash
cd ../moking-data-guide
git add .github/workflows/deploy.yml
git commit -m "chore: upgrade upload-pages-artifact@v3 → v4"
git push -u origin chore/upgrade-github-actions
```

PR 생성:
- Title: `chore: upgrade upload-pages-artifact v3 → v4`
- Base: `main`

---

## Task 7: GitHub Actions Deprecation 수정 — workflow-dashboard

**Files:**
- Modify: `../workflow-dashboard/.github/workflows/build.yml:43`

- [ ] **Step 1: 브랜치 생성**

```bash
cd ../workflow-dashboard
git checkout main
git pull origin main
git checkout -b chore/upgrade-github-actions
```

- [ ] **Step 2: build.yml 수정**

`../workflow-dashboard/.github/workflows/build.yml` line 43 수정:

```yaml
# 변경 전
      - uses: actions/upload-pages-artifact@v3

# 변경 후
      - uses: actions/upload-pages-artifact@v4
```

> 이 레포는 이미 `node-version: 22`를 사용 중이므로 Node.js 버전 변경 불필요.

- [ ] **Step 3: 커밋 + 푸시 + PR**

```bash
cd ../workflow-dashboard
git add .github/workflows/build.yml
git commit -m "chore: upgrade upload-pages-artifact@v3 → v4"
git push -u origin chore/upgrade-github-actions
```

PR 생성:
- Title: `chore: upgrade upload-pages-artifact v3 → v4`
- Base: `main`

---

## Task 8: MSK 토픽 생성 스크립트 보강

**Files:**
- Modify: `scripts/create-kafka-topics.sh`
- Create: `docs/guides/MSK_TOPIC_SETUP.md`

- [ ] **Step 1: create-kafka-topics.sh 보강**

`scripts/create-kafka-topics.sh` 전체를 다음으로 교체:

```bash
#!/usr/bin/env bash
# scripts/create-kafka-topics.sh
# Create Kafka topics on MSK cluster (idempotent).
# Usage:
#   KAFKA_BROKERS=<broker-list> bash scripts/create-kafka-topics.sh
#   KAFKA_BROKERS=<broker-list> REPLICATION_FACTOR=1 bash scripts/create-kafka-topics.sh  # local
set -euo pipefail

BROKER="${KAFKA_BROKERS:?Set KAFKA_BROKERS env var (e.g. b-1.msk:9094,b-2.msk:9094)}"
REPLICATION="${REPLICATION_FACTOR:-3}"
MIN_ISR="${MIN_INSYNC_REPLICAS:-2}"
LOG_FILE="kafka-topics-$(date +%Y%m%d-%H%M%S).log"

TOPICS=(
  "platform.auth.user-registered-v1"
  "knowledge.note.note-created-v1"
  "knowledge.note.note-updated-v1"
  "learning.card.review-completed-v1"
  "learning.ai.cards-generated-v1"
)

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }

# --- 1. Connection check ---
log "Checking connection to $BROKER ..."
if ! kafka-broker-api-versions.sh --bootstrap-server "$BROKER" --timeout 10000 > /dev/null 2>&1; then
  log "ERROR: Cannot connect to Kafka broker at $BROKER"
  log "Check: VPN/Bastion connection, security group, bootstrap server address"
  exit 1
fi
log "Connection OK"

# --- 2. Create topics ---
created=0
skipped=0
for topic in "${TOPICS[@]}"; do
  existing=$(kafka-topics.sh --bootstrap-server "$BROKER" --list 2>/dev/null | grep -cx "$topic" || true)
  if [ "$existing" -ge 1 ]; then
    log "SKIP (exists): $topic"
    ((skipped++))
  else
    log "CREATE: $topic (partitions=3, rf=$REPLICATION, min.isr=$MIN_ISR)"
    kafka-topics.sh --bootstrap-server "$BROKER" \
      --create \
      --topic "$topic" \
      --partitions 3 \
      --replication-factor "$REPLICATION" \
      --config retention.ms=604800000 \
      --config cleanup.policy=delete \
      --config min.insync.replicas="$MIN_ISR" \
      2>&1 | tee -a "$LOG_FILE"
    ((created++))
  fi
done

# --- 3. Verify ---
log ""
log "=== Result: created=$created, skipped=$skipped ==="
log "Current topics on cluster:"
kafka-topics.sh --bootstrap-server "$BROKER" --list 2>&1 | tee -a "$LOG_FILE"
log ""
log "Log saved to $LOG_FILE"
```

- [ ] **Step 2: 스크립트 실행 권한 확인**

```bash
chmod +x scripts/create-kafka-topics.sh
```

- [ ] **Step 3: MSK_TOPIC_SETUP.md 작성**

`docs/guides/MSK_TOPIC_SETUP.md` 생성:

```markdown
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
```

- [ ] **Step 4: 커밋**

```bash
git add scripts/create-kafka-topics.sh docs/guides/MSK_TOPIC_SETUP.md
git commit -m "feat(scripts): enhance MSK topic script — connection check, idempotency, logging"
```

---

## Task 9: Kafka E2E 검증 — 테스트 인프라 준비

**Files:**
- Create: `scripts/kafka-e2e-test.sh`
- Create: `src/test/resources/e2e-samples/user-registered.json`
- Create: `src/test/resources/e2e-samples/note-created.json`
- Create: `src/test/resources/e2e-samples/review-completed.json`
- Create: `src/test/resources/e2e-samples/cards-generated.json`
- Create: `docs/guides/KAFKA_E2E_TEST.md`

- [ ] **Step 1: 샘플 이벤트 데이터 작성**

`src/test/resources/e2e-samples/user-registered.json`:

```json
{
  "specversion": "1.0",
  "id": "e2e-test-001",
  "source": "platform-svc",
  "type": "platform.auth.user-registered",
  "subject": "user/e2e-user-01",
  "time": "2026-05-20T09:00:00Z",
  "tenantid": "tenant-e2e-001",
  "datacontenttype": "application/avro",
  "traceparent": "00-e2etest00000000000000000000001-0000000000000001-01",
  "data": {
    "userId": "e2e-user-01",
    "email": "e2e-user@test.synapse.dev",
    "tenantId": "tenant-e2e-001",
    "registeredAt": "2026-05-20T09:00:00Z"
  }
}
```

`src/test/resources/e2e-samples/note-created.json`:

```json
{
  "specversion": "1.0",
  "id": "e2e-test-002",
  "source": "knowledge-svc",
  "type": "knowledge.note.note-created",
  "subject": "note/e2e-note-01",
  "time": "2026-05-20T09:01:00Z",
  "tenantid": "tenant-e2e-001",
  "datacontenttype": "application/avro",
  "traceparent": "00-e2etest00000000000000000000002-0000000000000002-01",
  "data": {
    "noteId": "e2e-note-01",
    "tenantId": "tenant-e2e-001",
    "title": "E2E Test Note",
    "content": "This is a test note for Kafka E2E validation.",
    "createdAt": "2026-05-20T09:01:00Z"
  }
}
```

`src/test/resources/e2e-samples/review-completed.json`:

```json
{
  "specversion": "1.0",
  "id": "e2e-test-003",
  "source": "learning-card-svc",
  "type": "learning.card.review-completed",
  "subject": "card/e2e-card-01",
  "time": "2026-05-20T09:02:00Z",
  "tenantid": "tenant-e2e-001",
  "datacontenttype": "application/avro",
  "traceparent": "00-e2etest00000000000000000000003-0000000000000003-01",
  "data": {
    "cardId": "e2e-card-01",
    "userId": "e2e-user-01",
    "tenantId": "tenant-e2e-001",
    "rating": "GOOD",
    "nextReviewAt": "2026-05-21T09:00:00Z",
    "reviewedAt": "2026-05-20T09:02:00Z"
  }
}
```

`src/test/resources/e2e-samples/cards-generated.json`:

```json
{
  "specversion": "1.0",
  "id": "e2e-test-004",
  "source": "learning-ai-svc",
  "type": "learning.ai.cards-generated",
  "subject": "note/e2e-note-01",
  "time": "2026-05-20T09:03:00Z",
  "tenantid": "tenant-e2e-001",
  "datacontenttype": "application/avro",
  "traceparent": "00-e2etest00000000000000000000004-0000000000000004-01",
  "data": {
    "noteId": "e2e-note-01",
    "userId": "e2e-user-01",
    "tenantId": "tenant-e2e-001",
    "cardCount": 5,
    "generatedAt": "2026-05-20T09:03:00Z"
  }
}
```

- [ ] **Step 2: E2E 테스트 스크립트 작성**

`scripts/kafka-e2e-test.sh`:

```bash
#!/usr/bin/env bash
# scripts/kafka-e2e-test.sh
# Kafka E2E produce/consume smoke test (Docker Compose local environment).
# Usage: bash scripts/kafka-e2e-test.sh [topic] [sample-file]
# Example: bash scripts/kafka-e2e-test.sh platform.auth.user-registered-v1 user-registered.json
set -euo pipefail

BROKER="${KAFKA_BROKERS:-localhost:9092}"
CONTAINER="${KAFKA_CONTAINER:-synapse-kafka}"
SAMPLES_DIR="src/test/resources/e2e-samples"
TIMEOUT="${CONSUME_TIMEOUT:-10}"

topic="${1:-}"
sample="${2:-}"

usage() {
  echo "Usage: bash $0 <topic> <sample-json>"
  echo ""
  echo "Topics:"
  echo "  platform.auth.user-registered-v1"
  echo "  knowledge.note.note-created-v1"
  echo "  knowledge.note.note-updated-v1"
  echo "  learning.card.review-completed-v1"
  echo "  learning.ai.cards-generated-v1"
  echo ""
  echo "Example:"
  echo "  bash $0 platform.auth.user-registered-v1 user-registered.json"
  echo ""
  echo "Run all:"
  echo "  bash $0 --all"
}

produce_and_consume() {
  local t="$1" f="$2"
  local filepath="$SAMPLES_DIR/$f"

  if [ ! -f "$filepath" ]; then
    echo "ERROR: Sample file not found: $filepath"
    return 1
  fi

  echo "=== Testing: $t ==="
  echo "[PRODUCE] Sending message from $f ..."

  # Produce via docker exec
  docker exec -i "$CONTAINER" kafka-console-producer \
    --bootstrap-server kafka:29092 \
    --topic "$t" \
    < "$filepath"

  echo "[PRODUCE] OK"

  echo "[CONSUME] Reading from $t (timeout=${TIMEOUT}s) ..."
  docker exec "$CONTAINER" kafka-console-consumer \
    --bootstrap-server kafka:29092 \
    --topic "$t" \
    --from-beginning \
    --max-messages 1 \
    --timeout-ms "$((TIMEOUT * 1000))"

  echo "[CONSUME] OK"
  echo ""
}

if [ "$topic" = "--all" ]; then
  produce_and_consume "platform.auth.user-registered-v1" "user-registered.json"
  produce_and_consume "knowledge.note.note-created-v1" "note-created.json"
  produce_and_consume "learning.card.review-completed-v1" "review-completed.json"
  produce_and_consume "learning.ai.cards-generated-v1" "cards-generated.json"
  echo "=== All E2E smoke tests passed ==="
elif [ -n "$topic" ] && [ -n "$sample" ]; then
  produce_and_consume "$topic" "$sample"
else
  usage
  exit 1
fi
```

- [ ] **Step 3: 스크립트 실행 권한**

```bash
chmod +x scripts/kafka-e2e-test.sh
```

- [ ] **Step 4: KAFKA_E2E_TEST.md 작성**

`docs/guides/KAFKA_E2E_TEST.md`:

```markdown
# Kafka E2E 검증 가이드

## 개요

4개 이벤트 흐름을 Docker Compose 로컬 환경에서 검증한다.

## 사전 조건

1. Docker Compose 실행 중: `docker compose up -d`
2. 모든 서비스 healthy: `docker compose ps`
3. Kafka 토픽 생성 완료 (kafka-init 서비스가 자동 생성)

## 검증 시나리오

### 시나리오 1: 회원가입 → 프로필 생성

| 항목 | 값 |
|------|---|
| Producer | platform-svc |
| Topic | `platform.auth.user-registered-v1` |
| Consumer | engagement-svc |
| 검증 | engagement-svc 로그에서 이벤트 수신 확인 + DB에 프로필 레코드 생성 |

**수동 테스트 (서비스 구현 전 — 메시지 흐름만 확인):**
```bash
bash scripts/kafka-e2e-test.sh platform.auth.user-registered-v1 user-registered.json
```

**서비스 구현 후 E2E 테스트:**
```bash
# 1. platform-svc에 회원가입 API 호출
curl -X POST http://localhost:8081/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"e2e@test.com","password":"Test1234!"}'

# 2. engagement-svc 로그에서 이벤트 수신 확인
docker logs synapse-engagement-svc 2>&1 | grep "user-registered"

# 3. engagement-svc DB에서 프로필 확인
docker exec synapse-postgres psql -U synapse -c \
  "SELECT * FROM engagement.user_profiles WHERE email='e2e@test.com'"
```

### 시나리오 2: 노트 생성 → AI 카드 생성

| 항목 | 값 |
|------|---|
| Producer | knowledge-svc |
| Topic | `knowledge.note.note-created-v1` |
| Consumer | learning-ai-svc |
| 검증 | learning-ai-svc 로그에서 카드 생성 트리거 확인 |

**수동 테스트:**
```bash
bash scripts/kafka-e2e-test.sh knowledge.note.note-created-v1 note-created.json
```

### 시나리오 3: 카드 복습 → XP 적립

| 항목 | 값 |
|------|---|
| Producer | learning-card-svc |
| Topic | `learning.card.review-completed-v1` |
| Consumer | engagement-svc |
| 검증 | engagement-svc에서 XP 포인트 증가 확인 |

**수동 테스트:**
```bash
bash scripts/kafka-e2e-test.sh learning.card.review-completed-v1 review-completed.json
```

### 시나리오 4: AI 카드 완료 → 알림

| 항목 | 값 |
|------|---|
| Producer | learning-ai-svc |
| Topic | `learning.ai.cards-generated-v1` |
| Consumer | platform-svc |
| 검증 | platform-svc 알림 로그 확인 |

**수동 테스트:**
```bash
bash scripts/kafka-e2e-test.sh learning.ai.cards-generated-v1 cards-generated.json
```

## 전체 스모크 테스트 (한 번에 실행)

```bash
bash scripts/kafka-e2e-test.sh --all
```

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `Topic not found` | kafka-init 미완료 | `docker compose restart kafka-init` |
| `Connection refused` | Kafka 미기동 | `docker compose up -d kafka` + health 대기 |
| Consume timeout | 메시지 미도착 | Producer 로그 확인, 토픽 파티션 확인 |
| Serialization error | 스키마 불일치 | Schema Registry에 등록된 스키마 버전 확인 |
```

- [ ] **Step 5: 커밋**

```bash
git add scripts/kafka-e2e-test.sh src/test/resources/e2e-samples/ docs/guides/KAFKA_E2E_TEST.md
git commit -m "feat(e2e): Kafka E2E test script + sample events + verification guide"
```

---

## Task 10: ArgoCD dev/staging 배포 검증 계획

**Files:**
- Create: `docs/guides/ARGOCD_DEPLOY_VERIFICATION.md`

> **참고**: synapse-gitops의 ApplicationSet은 이미 `targetRevision: main`을 사용 중이며, 5개 서비스(platform-svc, engagement-svc, knowledge-svc, learning-card, learning-ai) × dev 환경이 정의되어 있다. gateway는 ApplicationSet에 포함되어 있지 않으므로 별도 확인 필요.

- [ ] **Step 1: ARGOCD_DEPLOY_VERIFICATION.md 작성**

`docs/guides/ARGOCD_DEPLOY_VERIFICATION.md`:

```markdown
# ArgoCD Dev/Staging 배포 검증 가이드

## 현재 ArgoCD 구성 요약

### ApplicationSet (`argocd/applicationset.yaml`)

- **Generator**: Matrix (5 services × environments)
- **Services**: platform-svc, engagement-svc, knowledge-svc, learning-card, learning-ai
- **Environments**: dev (현재), staging/prod (추후)
- **Sync Policy**: automated (prune: true, selfHeal: true)
- **Source**: `synapse-gitops` repo, `apps/{service}/overlays/{env}` 경로
- **targetRevision**: `main`

### 서비스별 오버레이 구조

```
apps/
├── platform-svc/
│   ├── base/          (deployment, service, configmap, externalsecret)
│   └── overlays/dev/  (replicas=1, DEBUG, dev DB/Redis/Kafka endpoints)
├── engagement-svc/
│   ├── base/
│   └── overlays/dev/
├── knowledge-svc/
│   ├── base/
│   └── overlays/dev/
├── learning-card/
│   ├── base/
│   └── overlays/dev/
└── learning-ai/
    ├── base/
    └── overlays/dev/
```

### 이미지 업데이트 전략

- **ArgoCD Image Updater** 사용 (semver 태그 매칭)
- ECR: `963773969059.dkr.ecr.ap-northeast-2.amazonaws.com/synapse/{service}`
- Write-back: Git (kustomization)

> **주의**: synapse-gateway는 ApplicationSet에 미포함. 별도 Application 또는 ApplicationSet 확장 필요.

## Dev 환경 배포 검증

### Step 1: ArgoCD 접속

```bash
# ArgoCD 서버 포트포워드 (EKS 클러스터에서)
kubectl port-forward svc/argocd-server -n argocd 8443:443

# 브라우저: https://localhost:8443
# 또는 CLI:
argocd login localhost:8443 --insecure
```

### Step 2: Application 상태 확인

```bash
# 전체 Application 목록
argocd app list

# 개별 서비스 상태
argocd app get synapse-platform-svc-dev
argocd app get synapse-engagement-svc-dev
argocd app get synapse-knowledge-svc-dev
argocd app get synapse-learning-card-dev
argocd app get synapse-learning-ai-dev
```

Expected: 각 앱이 `Synced` + `Healthy` 상태

### Step 3: Pod 상태 확인

```bash
kubectl get pods -n synapse-dev
kubectl describe pod -n synapse-dev -l app.kubernetes.io/component=platform-svc
```

Expected: 모든 Pod `Running`, readiness/liveness probe 통과

### Step 4: 서비스 간 네트워크 확인

```bash
# Gateway → 각 서비스 통신 (gateway Pod에서)
kubectl exec -n synapse-dev deploy/gateway -- curl -s http://platform-svc:8081/actuator/health
kubectl exec -n synapse-dev deploy/gateway -- curl -s http://engagement-svc:8082/actuator/health
kubectl exec -n synapse-dev deploy/gateway -- curl -s http://knowledge-svc:8083/actuator/health
kubectl exec -n synapse-dev deploy/gateway -- curl -s http://learning-card-svc:8084/actuator/health
```

### Step 5: Kafka 연결 확인

```bash
# 서비스 로그에서 Kafka 연결 확인
kubectl logs -n synapse-dev deploy/platform-svc | grep -i "kafka\|bootstrap"
```

Expected: Kafka bootstrap 연결 성공 로그

## Staging 환경 배포 검증

### 사전 작업: staging 오버레이 생성

각 서비스의 `overlays/staging/kustomization.yaml` 생성 필요:
- replicas: 2 (HA)
- LOG_LEVEL: INFO
- SPRING_PROFILES_ACTIVE: staging
- staging DB/Redis/Kafka endpoints

ApplicationSet generator에 `env: staging` 추가:

```yaml
- list:
    elements:
      - env: dev
      - env: staging  # 추가
```

### Manual Sync 워크플로

Staging은 자동 sync 대신 수동 승인:

```yaml
syncPolicy:
  # automated 제거 → 수동 sync
  syncOptions:
    - CreateNamespace=true
```

```bash
# 수동 sync 실행
argocd app sync synapse-platform-svc-staging
```

### Dev → Staging 프로모션 절차

1. Dev에서 검증 완료된 이미지 태그 확인
2. Staging kustomization에 동일 태그 설정
3. PR → main 머지 → ArgoCD manual sync

```bash
# Dev 이미지 태그 확인
kubectl get deploy -n synapse-dev platform-svc -o jsonpath='{.spec.template.spec.containers[0].image}'

# Staging kustomization 업데이트
cd apps/platform-svc/overlays/staging
kustomize edit set image 963773969059.dkr.ecr.ap-northeast-2.amazonaws.com/synapse/platform-svc:TAG
```

## Rollback 절차

### ArgoCD Rollback (빠른 복구)

```bash
# 이전 배포 이력 확인
argocd app history synapse-platform-svc-dev

# 특정 리비전으로 롤백
argocd app rollback synapse-platform-svc-dev <REVISION>
```

### Git Revert (영구 롤백)

```bash
# 문제 커밋 식별
git log --oneline -5

# Revert 커밋
git revert <COMMIT_SHA>
git push

# ArgoCD가 자동 sync (dev) 또는 수동 sync (staging)
```

### 긴급 롤백 체크리스트

- [ ] 문제 서비스 식별
- [ ] ArgoCD에서 이전 리비전으로 롤백
- [ ] Pod 상태 확인 (Running, Healthy)
- [ ] 헬스체크 통과 확인
- [ ] 로그에서 에러 없음 확인
- [ ] 원인 분석 후 Git revert PR 생성
```

- [ ] **Step 2: 커밋**

```bash
git add docs/guides/ARGOCD_DEPLOY_VERIFICATION.md
git commit -m "docs: ArgoCD dev/staging deploy verification guide"
```

---

## Task 11: 팀원 체크리스트 + 테스트 데이터 시드

**Files:**
- Create: `docs/guides/TEAM_CHECKLIST_W3.md`
- Create: `scripts/seed-test-data.sh`
- Create: `src/test/resources/seed/V001__test_users.sql`
- Create: `src/test/resources/seed/V002__test_notes.sql`
- Create: `src/test/resources/seed/V003__test_cards.sql`

- [ ] **Step 1: TEAM_CHECKLIST_W3.md 작성**

`docs/guides/TEAM_CHECKLIST_W3.md`:

```markdown
# W3 팀원 Kafka 구현 체크리스트

> **목적**: W3~W4 Kafka E2E 검증 전에 각 서비스가 준비해야 할 항목

## 공통 요구사항

모든 Producer/Consumer는 다음을 충족해야 합니다:

- [ ] **Avro 직렬화/역직렬화**: Schema Registry 연동 (`KafkaAvroSerializer`/`KafkaAvroDeserializer`)
- [ ] **CloudEvent 래핑**: `CloudEventEnvelope.avsc` 기반 (specversion, id, source, type, subject, time, tenantid, traceparent)
- [ ] **Consumer Group**: 서비스명 기반 (`{service-name}-group`)
- [ ] **에러 핸들링**: 역직렬화 실패 시 로그 + 스킵 (DLT 전송은 Phase 2)
- [ ] **멱등성**: 동일 이벤트 재처리 시 부작용 없음 (eventId 기반 중복 체크)
- [ ] **application.yml 설정**: Kafka bootstrap, Schema Registry URL, consumer group

### 공통 Kafka 설정 예시 (application.yml)

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BROKERS:kafka:29092}
    properties:
      schema.registry.url: ${SCHEMA_REGISTRY_URL:http://schema-registry:8081}
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: io.confluent.kafka.serializers.KafkaAvroSerializer
    consumer:
      group-id: ${spring.application.name}-group
      auto-offset-reset: earliest
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: io.confluent.kafka.serializers.KafkaAvroDeserializer
      properties:
        specific.avro.reader: true
```

## 서비스별 체크리스트

### platform-svc (@팀원A)

**Producer:**
- [ ] `UserRegistered` 이벤트 발행 → `platform.auth.user-registered-v1`
- [ ] 회원가입 API 성공 후 이벤트 발행
- [ ] 단위 테스트: Producer mock으로 이벤트 발행 검증

**Consumer:**
- [ ] `CardsGenerated` 이벤트 수신 ← `learning.ai.cards-generated-v1`
- [ ] 알림 트리거 로직 구현
- [ ] 단위 테스트: Consumer mock으로 이벤트 처리 검증

### knowledge-svc (@팀원B)

**Producer:**
- [ ] `NoteCreated` 이벤트 발행 → `knowledge.note.note-created-v1`
- [ ] `NoteUpdated` 이벤트 발행 → `knowledge.note.note-updated-v1`
- [ ] 노트 생성/수정 API 성공 후 이벤트 발행
- [ ] 단위 테스트

**Consumer:** 없음

### learning-card-svc (@팀원C)

**Producer:**
- [ ] `ReviewCompleted` 이벤트 발행 → `learning.card.review-completed-v1`
- [ ] 카드 복습 API 성공 후 이벤트 발행
- [ ] 단위 테스트

**Consumer:** 없음

### learning-ai-svc (@팀원D)

**Producer:**
- [ ] `CardsGenerated` 이벤트 발행 → `learning.ai.cards-generated-v1`
- [ ] AI 카드 생성 완료 후 이벤트 발행
- [ ] Python Avro 직렬화 (`confluent-kafka[avro]` 패키지)

**Consumer:**
- [ ] `NoteCreated` 이벤트 수신 ← `knowledge.note.note-created-v1`
- [ ] 노트 수신 → AI 카드 생성 파이프라인 트리거
- [ ] Consumer group: `learning-ai-svc-group`

### engagement-svc (@팀원E)

**Consumer:**
- [ ] `UserRegistered` 이벤트 수신 ← `platform.auth.user-registered-v1`
- [ ] 프로필 레코드 자동 생성
- [ ] `ReviewCompleted` 이벤트 수신 ← `learning.card.review-completed-v1`
- [ ] XP 포인트 적립 로직
- [ ] 멱등성 처리 (동일 reviewId 중복 적립 방지)

**Producer:** 없음

## 완료 기준

각 서비스가 아래를 모두 충족하면 E2E 검증 시작:

1. Docker Compose로 기동 시 Kafka 연결 성공 (로그 확인)
2. Producer: API 호출 → 토픽에 메시지 발행 확인 (`kafka-console-consumer`로 확인)
3. Consumer: 토픽 메시지 수신 → 비즈니스 로직 실행 확인 (로그 + DB 확인)
4. 단위 테스트 통과

## E2E 검증 가이드

구현 완료 후 `docs/guides/KAFKA_E2E_TEST.md`의 시나리오를 순서대로 실행하세요.
```

- [ ] **Step 2: SQL 시드 파일 작성**

`src/test/resources/seed/V001__test_users.sql`:

```sql
-- V001__test_users.sql
-- E2E 테스트용 유저 시드 데이터
-- Docker Compose 로컬 환경 (synapse DB) 기준

-- Tenant 1: 기본 테스트 테넌트
INSERT INTO platform.users (id, email, tenant_id, created_at)
VALUES
  ('e2e-user-01', 'alice@test.synapse.dev', 'tenant-e2e-001', '2026-05-20 09:00:00'),
  ('e2e-user-02', 'bob@test.synapse.dev',   'tenant-e2e-001', '2026-05-20 09:00:00')
ON CONFLICT (id) DO NOTHING;

-- Tenant 2: 멀티테넌시 테스트
INSERT INTO platform.users (id, email, tenant_id, created_at)
VALUES
  ('e2e-user-03', 'carol@test.synapse.dev', 'tenant-e2e-002', '2026-05-20 09:00:00')
ON CONFLICT (id) DO NOTHING;
```

`src/test/resources/seed/V002__test_notes.sql`:

```sql
-- V002__test_notes.sql
-- E2E 테스트용 노트 시드 데이터

INSERT INTO knowledge.notes (id, user_id, tenant_id, title, content, created_at)
VALUES
  ('e2e-note-01', 'e2e-user-01', 'tenant-e2e-001',
   'Kafka Basics', 'Introduction to Apache Kafka event streaming.',
   '2026-05-20 09:01:00'),
  ('e2e-note-02', 'e2e-user-01', 'tenant-e2e-001',
   'Distributed Systems', 'CAP theorem and consistency models.',
   '2026-05-20 09:01:00')
ON CONFLICT (id) DO NOTHING;
```

`src/test/resources/seed/V003__test_cards.sql`:

```sql
-- V003__test_cards.sql
-- E2E 테스트용 플래시카드 시드 데이터

INSERT INTO learning.cards (id, note_id, user_id, tenant_id, front, back, next_review_at, created_at)
VALUES
  ('e2e-card-01', 'e2e-note-01', 'e2e-user-01', 'tenant-e2e-001',
   'What is Kafka?', 'A distributed event streaming platform.',
   '2026-05-21 09:00:00', '2026-05-20 09:01:00'),
  ('e2e-card-02', 'e2e-note-01', 'e2e-user-01', 'tenant-e2e-001',
   'What is a Kafka topic?', 'A category/feed name to which records are published.',
   '2026-05-21 09:00:00', '2026-05-20 09:01:00'),
  ('e2e-card-03', 'e2e-note-02', 'e2e-user-01', 'tenant-e2e-001',
   'What is CAP theorem?', 'A distributed system can only guarantee 2 of 3: Consistency, Availability, Partition tolerance.',
   '2026-05-21 09:00:00', '2026-05-20 09:01:00')
ON CONFLICT (id) DO NOTHING;
```

- [ ] **Step 3: seed-test-data.sh 작성**

`scripts/seed-test-data.sh`:

```bash
#!/usr/bin/env bash
# scripts/seed-test-data.sh
# Seed test data into PostgreSQL (Docker Compose local environment).
# Usage: bash scripts/seed-test-data.sh
set -euo pipefail

CONTAINER="${POSTGRES_CONTAINER:-synapse-postgres}"
DB="${POSTGRES_DB:-synapse}"
USER="${POSTGRES_USER:-synapse}"
SEED_DIR="src/test/resources/seed"

echo "=== Seeding test data into $DB ==="

for sql in "$SEED_DIR"/V*.sql; do
  filename=$(basename "$sql")
  echo "[SEED] Applying $filename ..."
  docker exec -i "$CONTAINER" psql -U "$USER" -d "$DB" < "$sql"
done

echo ""
echo "=== Seed complete. Verifying... ==="
echo ""

echo "[CHECK] platform.users:"
docker exec "$CONTAINER" psql -U "$USER" -d "$DB" -c \
  "SELECT id, email, tenant_id FROM platform.users WHERE id LIKE 'e2e-%';"

echo "[CHECK] knowledge.notes:"
docker exec "$CONTAINER" psql -U "$USER" -d "$DB" -c \
  "SELECT id, title, tenant_id FROM knowledge.notes WHERE id LIKE 'e2e-%';"

echo "[CHECK] learning.cards:"
docker exec "$CONTAINER" psql -U "$USER" -d "$DB" -c \
  "SELECT id, front, tenant_id FROM learning.cards WHERE id LIKE 'e2e-%';"

echo ""
echo "=== Done ==="
```

- [ ] **Step 4: 스크립트 실행 권한**

```bash
chmod +x scripts/seed-test-data.sh
```

- [ ] **Step 5: 커밋**

```bash
git add docs/guides/TEAM_CHECKLIST_W3.md \
        scripts/seed-test-data.sh \
        src/test/resources/seed/
git commit -m "feat: W3 team checklist + test data seed scripts"
```

---

## Task 12: synapse-shared 전체 변경사항 브랜치 + PR

> Tasks 8~11에서 만든 synapse-shared 변경사항을 별도 브랜치로 분리하여 PR 생성.

**주의**: Tasks 8~11의 커밋이 main에 직접 들어갔다면, 아래 절차로 브랜치를 만들어야 한다. 처음부터 브랜치에서 작업했다면 이 Task는 푸시 + PR 생성만 수행.

- [ ] **Step 1: 브랜치 전략 결정**

현재 main에 커밋이 쌓여 있는 경우:

```bash
cd ../synapse-shared

# main에서 새 브랜치 생성 (이미 커밋한 상태이므로 현재 HEAD 사용)
git checkout -b chore/w2w3-ops-prep

# 또는, 처음부터 브랜치에서 작업 시작:
# git checkout main && git pull && git checkout -b chore/w2w3-ops-prep
# 그 후 Tasks 8~11 수행
```

- [ ] **Step 2: 푸시 + PR 생성**

```bash
git push -u origin chore/w2w3-ops-prep
```

PR 생성:
- Title: `chore: W2/W3 운영 정비 — MSK 스크립트 + E2E 준비 + 가이드 문서`
- Base: `main` (또는 `dev` if exists)
- Body:

```markdown
## Summary
- MSK 토픽 생성 스크립트 보강 (연결 확인, 멱등성, 로깅, min.insync.replicas)
- Kafka E2E 테스트 스크립트 + 샘플 이벤트 데이터
- PostgreSQL 테스트 데이터 시드 스크립트
- 가이드 문서 4건 (MSK 토픽, E2E 검증, ArgoCD 배포, 팀원 체크리스트)

## 관련 설계
- `docs/superpowers/specs/2026-05-20-w2w3-ops-and-prep-design.md`

## Test plan
- [ ] `scripts/create-kafka-topics.sh` — Docker Compose 환경에서 REPLICATION_FACTOR=1로 실행 확인
- [ ] `scripts/kafka-e2e-test.sh --all` — 로컬 Kafka에서 produce/consume 동작 확인
- [ ] `scripts/seed-test-data.sh` — PostgreSQL 시드 실행 확인 (스키마 존재 시)
- [ ] 가이드 문서 마크다운 렌더링 확인
```

---

## Summary: PR 전체 목록

| # | 레포 | 브랜치 | PR 대상 | 내용 |
|---|------|--------|---------|------|
| 1 | synapse-gateway | `chore/rename-master-to-main` | master | 워크플로 master→main + ecr-login@v3 |
| 2 | synapse-gitops | `chore/upgrade-github-actions` | main | setup-dart@v2, upload-pages-artifact@v4 |
| 3 | documents | `chore/upgrade-github-actions` | main | node-version 20→22 |
| 4 | schedule-repo | `chore/upgrade-github-actions` | main | node 20→22, upload-pages-artifact@v4 |
| 5 | moking-data-guide | `chore/upgrade-github-actions` | main | upload-pages-artifact@v4 |
| 6 | workflow-dashboard | `chore/upgrade-github-actions` | main | upload-pages-artifact@v4 |
| 7 | synapse-shared | `chore/w2w3-ops-prep` | main | 스크립트 + 문서 + 시드 |
