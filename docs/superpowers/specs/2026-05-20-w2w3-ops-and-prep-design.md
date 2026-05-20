# W2/W3 운영 정비 + E2E 검증 준비 설계

> **작성일**: 2026-05-20
> **작성자**: @team-lead
> **상태**: 승인됨

---

## 1. 개요

W1/W2에서 완료된 인프라 위에서, 미해결 운영 항목을 정리하고 W3 Kafka E2E 검증에 필요한 사전 준비를 완료한다.

### 작업 우선순위

| 순서 | 작업 | 성격 | 실행 방식 |
|:----:|------|------|-----------|
| 1 | Gateway master → main 브랜치 변경 | 직접 실행 | 브랜치 → PR |
| 2 | GitHub Actions Node.js 20 deprecation 수정 | 직접 실행 | 9개 레포 각각 브랜치 → dev PR |
| 3 | MSK 토픽 생성 스크립트 보강 | 직접 실행 | 스크립트 + 가이드 |
| 4 | Kafka E2E 검증 계획 | 계획 + 인프라 준비 | 시나리오 + 스크립트 + 샘플 |
| 5 | ArgoCD dev/staging 배포 검증 | 점검 + 계획 | 매니페스트 점검 + 가이드 |
| 6 | 사전 준비 (팀원 체크리스트 + 시드) | 문서 + 스크립트 | 체크리스트 + SQL 시드 |

### 제약 조건

- main/dev 직접 푸시 불가 — 별도 브랜치에서 dev PR 필수
- 브랜치명 컨벤션: `chore/...` 형태
- MSK 토픽 실행은 인프라 담당자가 수행 — 스크립트 + 가이드만 준비
- Kafka E2E 실제 검증은 팀원 Producer/Consumer 구현 후 (W3~W4)

---

## 2. Gateway master → main 브랜치 변경

### 범위

**synapse-gateway:**
- `.github/workflows/ci.yml` — `branches: [master]` → `[main]`
- `.github/workflows/deploy.yml` — `branches: [master]` → `[main]`
- 기타 `master` 참조 일괄 교체

**synapse-shared:**
- `docs/project-management/HANDOFF_2026-05-19.md` — 참조 업데이트

**synapse-gitops:**
- ArgoCD 매니페스트 `targetRevision: master` → `main` (해당되는 경우)

### 순서

1. synapse-gateway에서 `chore/rename-master-to-main` 브랜치 생성
2. 워크플로 파일 master → main 교체
3. PR 생성 → 머지 후 GitHub settings에서 default branch 변경
4. synapse-shared / synapse-gitops 참조 업데이트

---

## 3. GitHub Actions Node.js 20 Deprecation 일괄 수정

### 수정 대상 (9건, 7개 레포)

| 레포 | 워크플로 | 변경 내용 |
|------|----------|-----------|
| synapse-gateway | deploy.yml | `amazon-ecr-login@v2` → `@v3` |
| synapse-gitops | deploy-pages.yml | `setup-dart@v1` → `@v2`, `upload-pages-artifact@v3` → `@v4` |
| synapse-gitops | validate-manifests.yml | `setup-kustomize@v2` → `@v3` |
| documents | deploy-workflow-guide.yml | `node-version: '20'` → `'22'` |
| schedule-repo | deploy.yml | `node-version: 20` → `22`, `upload-pages-artifact@v3` → `@v4` |
| moking-data-guide | deploy.yml | `upload-pages-artifact@v3` → `@v4` |
| workflow-dashboard | build.yml | `upload-pages-artifact@v3` → `@v4` |

### 작업 방식

- 각 레포에서 `dev` 기반으로 `chore/upgrade-github-actions` 브랜치 생성
- 워크플로 수정 후 커밋 → dev PR 생성
- synapse-shared는 이슈 없으므로 수정 없음

### 주의사항

- `amazon-ecr-login@v3` 출력 파라미터 호환성 확인
- `setup-kustomize@v3` 동작 호환 확인
- `setup-dart@v2` Dart SDK 버전 호환 확인
- 각 PR 설명에 deprecation 경고 설명 포함

---

## 4. MSK 클러스터 토픽 반영

### 스크립트 보강 (`scripts/create-kafka-topics.sh`)

1. 실행 전 MSK 연결 확인 (bootstrap server 접근 체크)
2. 이미 존재하는 토픽 스킵 (멱등성 보장)
3. 생성 후 토픽 목록 검증 출력
4. production 설정 (replication-factor: 3, min.insync.replicas: 2)
5. 실행 결과 로그 파일 출력

### 실행 가이드 (`docs/guides/MSK_TOPIC_SETUP.md`)

- 사전 조건 (AWS 인증, MSK 보안그룹, VPN/Bastion)
- 환경별 실행 방법 (dev / staging / prod)
- 실행 후 검증 명령어
- 롤백 방법 (토픽 삭제 명령)
- 인프라 담당자 step-by-step 가이드

---

## 5. Kafka E2E 검증 계획

### 테스트 시나리오 (4개 이벤트 흐름)

| # | 흐름 | Producer | Topic | Consumer | 검증 기준 |
|---|------|----------|-------|----------|-----------|
| 1 | 회원가입 → 프로필 생성 | platform-svc | `platform.auth.user-registered-v1` | engagement-svc | 이벤트 수신 후 프로필 레코드 생성 |
| 2 | 노트 생성 → AI 카드 생성 | knowledge-svc | `knowledge.note.note-created-v1` | learning-ai-svc | AI 카드 생성 트리거 |
| 3 | 카드 복습 → XP 적립 | learning-card-svc | `learning.card.review-completed-v1` | engagement-svc | XP 포인트 증가 |
| 4 | AI 카드 완료 → 알림 | learning-ai-svc | `learning.ai.cards-generated-v1` | platform-svc | 알림 트리거 |

### 인프라 준비 (이번 세션)

- **`scripts/kafka-e2e-test.sh`** — 샘플 메시지 produce/consume 테스트 스크립트
- **`src/test/resources/e2e-samples/`** — 토픽별 JSON 샘플 메시지
- **`docs/guides/KAFKA_E2E_TEST.md`** — 검증 체크리스트 + 트러블슈팅

### 실행 시점

팀원 Producer/Consumer 구현 완료 후 (W3~W4), Docker Compose 전체 기동 → 시나리오 순서 검증

---

## 6. ArgoCD dev/staging 배포 검증

### 매니페스트 점검 (이번 세션)

- ApplicationSet / Application 정의 (4개 서비스 + gateway)
- 환경별 오버레이 (base / dev / staging / prod)
- 이미지 태그 전략 (deploy.yml → ECR push → gitops tag)
- 리소스 요청/제한, ConfigMap/Secret 참조

### dev 환경 배포 검증 계획

- ArgoCD Sync → 서비스 healthy 확인
- Pod readiness/liveness 통과
- gateway → 서비스 네트워크 통신
- Kafka (MSK) 연결 확인

### staging 환경 배포 검증 계획

- Manual Sync 워크플로 확인
- dev → staging 프로모션 절차
- Rollback 시나리오 (이전 버전 복원 + 검증)

### 산출물

- 매니페스트 점검 결과 (이슈 시 수정 PR)
- `docs/guides/ARGOCD_DEPLOY_VERIFICATION.md`

---

## 7. 사전 준비

### 팀원 Kafka 구현 체크리스트

| 서비스 | Producer 토픽 | Consumer 토픽 | 체크 항목 |
|--------|--------------|--------------|-----------|
| platform-svc | `user-registered-v1` | `cards-generated-v1` | Avro 직렬화, CloudEvent 래핑, 에러 핸들링 |
| knowledge-svc | `note-created-v1`, `note-updated-v1` | — | 동일 |
| learning-card-svc | `review-completed-v1` | — | 동일 |
| learning-ai-svc | `cards-generated-v1` | `note-created-v1` | Python Avro, consumer group |
| engagement-svc | — | `user-registered-v1`, `review-completed-v1` | 멱등성, dead-letter 토픽 |

### 테스트 데이터 시드

- **`scripts/seed-test-data.sh`** — PostgreSQL 시드 실행 스크립트
- **`src/test/resources/seed/V001__test_users.sql`** — 테스트 유저 3명
- **`src/test/resources/seed/V002__test_notes.sql`** — 테스트 노트 2개
- **`src/test/resources/seed/V003__test_cards.sql`** — 기본 카드 데이터

### 산출물

- `docs/guides/TEAM_CHECKLIST_W3.md`
- 시드 스크립트 + SQL 파일

---

## 8. 전체 산출물 요약

### 직접 실행 (코드 변경)
- synapse-gateway 워크플로 `master` → `main` 교체
- 7개 레포 GitHub Actions 버전 업그레이드
- `scripts/create-kafka-topics.sh` 보강
- `scripts/kafka-e2e-test.sh` 신규
- `scripts/seed-test-data.sh` 신규
- 테스트 SQL 시드 파일

### 문서 산출물
- `docs/guides/MSK_TOPIC_SETUP.md`
- `docs/guides/KAFKA_E2E_TEST.md`
- `docs/guides/ARGOCD_DEPLOY_VERIFICATION.md`
- `docs/guides/TEAM_CHECKLIST_W3.md`
- synapse-gitops 매니페스트 점검 결과

### PR 목록
- synapse-gateway: `chore/rename-master-to-main` → dev
- 7개 레포 각각: `chore/upgrade-github-actions` → dev
- synapse-shared: `chore/w2w3-ops-prep` → dev (스크립트, 문서, 시드)
- synapse-gitops: 이슈 발견 시 수정 PR
