# W3 synapse-shared 실행 계획 설계 스펙

> **작성일**: 2026-05-26 (W3 Day 1)
> **범위**: synapse-shared 레포의 team-lead W3 작업 (Day 1~4, 05-26~05-29)
> **갱신자**: @VelkaressiaBlutkrone
> **관련 플랜**:
> - 대체(shared 한정): [`2026-05-22-w3-work-composition.md`](../plans/2026-05-22-w3-work-composition.md) — gitops+shared 통합 day-by-day. **본 스펙이 shared 부분을 현행화·대체**하고, gitops 부분은 아래 머지된 통합 플랜이 담당.
> - 참조(gitops, 머지됨): synapse-gitops [`2026-05-26-w3-integrated-plan.md`](https://github.com/team-project-final/synapse-gitops/blob/main/docs/superpowers/plans/2026-05-26-w3-integrated-plan.md) — PR #47로 리포 작업 머지 완료.

---

## 1. 목적

W3(05-26~05-29, 4영업일) 동안 synapse-shared의 team-lead가 **클러스터·팀원 PR에 독립적으로** 진행 가능한 통합 검증·조율·문서 작업을 완료한다. gitops 인프라/배포/관측 작업은 별도 머지된 통합 플랜이 담당하므로 본 스펙에서 제외한다.

## 2. W3 시작 시점 현황 (05-26 기준)

### 이미 완료 (재작업 불필요)

- **shared 선행 준비 (05-22 커밋)**: `EVENT_FLOW_MATRIX.md`, `E2E_SCENARIOS_W3.md`, 리포트 템플릿 2종(`DEPLOY_REPORT_W3.md`/`E2E_REPORT_W3.md`), E2E 샘플 전부(정상/에러/멀티테넌트/시드 V001~V005), `scripts/kafka-e2e-test.sh`, `TEAM_CHECKLIST_W3.md`.
- **gitops 리포 작업 (PR #47, 05-26 02:42 머지)**: staging auto-sync, 공유 Ingress, 관측 매니페스트 9종, 포털 정리/CI/대시보드. observability는 EKS에서 SSM 터널 경유 라이브 검증 완료.

### 블로커 (W3 실작업의 제약)

- 🔴 **EKS 클러스터 destroy 후 bare 상태** — staging 5/5 Healthy·실 메트릭 수집은 인프라 재구축 필요. (gitops D-032 프라이빗 엔드포인트, D-033 EBS CSI 부재)
- 🔴 **팀원 Kafka Producer/Consumer 5개 서비스 전부 미착수, 열린 PR 0건** — shared의 코드 리뷰·클라우드 E2E가 검토 대상 자체 부재.
- 🔴 **platform-svc staging 프로필 부재** — staging 5/5 차단.

### 핵심 전환

05-22 플랜이 전제한 "매일 gitops→shared 순차 세션 + 클라우드 E2E day-by-day"는 ① gitops 분리·완료 ② 클러스터 소실 ③ 팀 PR 0건으로 **그대로 실행 불가**. 따라서 본 스펙은 shared 단독·로컬 우선·정직한 완료 정의로 재구성한다.

## 3. 핵심 결정 (브레인스토밍 합의)

| # | 결정 | 근거 |
|---|------|------|
| D1 | **scope = shared 중심 실행 계획 (Day 1~4)** | gitops는 머지된 자체 통합 플랜이 담당. 중복 제거. |
| D2 | **E2E = 로컬 docker-compose 중심**, 클라우드 E2E는 W4 이월 | 클러스터·팀PR 독립적·자기완결적. 재구축 비용/시간 회피. |
| D3 | **팀 Kafka = work-order 발행 + 추적 (team-lead 역할 유지)** | 구현은 각 owner 책임. shared E2E는 "구현된 만큼" 검증. |
| D4 | **minikube(local-k8s)는 gitops에 잔류** | `local-k8s/apps/<svc>`가 gitops `apps/<svc>/base`를 상대경로로 직접 참조 → 이동 시 경로 파손·중복·드리프트. shared는 docker-compose가 로컬 환경 역할. shared에는 포인터 1줄만 추가. |

## 4. 일자별 구성

### Day 1 (05-26, 오늘) — 언블로킹 + harness 베이스라인

1. **cross-repo work-order 발행 (5개 서비스)** — 각 owner에게 Kafka Producer/Consumer 구현 명세 + 리뷰 승인기준 + PR 기한(05-27). `synapse-gitops/docs/superpowers/specs/2026-05-21-cross-repo-work-order-design.md` 형식 참조.
2. **팀 체크리스트 현행화** — `TEAM_CHECKLIST_W3.md`를 현 인프라 현실에 맞게 갱신: 클러스터 destroy 상태 → 로컬 우선 안내, gitops `local-k8s` 포인터 추가.
3. **로컬 E2E harness 베이스라인** — `docker compose up -d` (13개 서비스) → `scripts/kafka-e2e-test.sh`로 토픽 5개·스키마·수동 produce/consume 경로 검증. **서비스 구현 0인 상태의 기준선**을 확보(harness 자체가 동작함을 증명).

### Day 2~3 (05-27~28) — 리뷰 + 머지 + 구현분 E2E

1. **work-order 진행 추적** — owner별 PR 도착 현황 점검, 미착수 시 상태 확인 메시지.
2. **PR 리뷰 + 머지 조율** — 승인기준(Avro BACKWARD / CloudEvent 래핑 / Consumer Group 네이밍 / 멱등성 / 단위테스트 / application.yml) 기반. 머지 순서: Producer(platform→knowledge→learning-card→learning-ai) → Consumer(engagement).
3. **구현분 로컬 E2E** — 머지된 서비스에 대해 `E2E_SCENARIOS_W3.md` 시나리오 실행.
4. **E2E 샘플 갭 보강** — 시나리오가 요구하나 누락된 샘플 추가.

### Day 4 (05-29) — 전체 E2E + 리포트 + 핸드오프

1. **전체 로컬 E2E** — `scripts/kafka-e2e-test.sh --full` (정상 + 에러 + 멀티테넌트).
2. **리포트 채우기** — `E2E_REPORT_W3.md`, `DEPLOY_REPORT_W3.md`에 실제 결과 기입. 미구현·미검증은 정직하게 표기.
3. **W3→W4 핸드오프 동기화** — `HANDOFF_HUB.md`, `HANDOFF_SHARED.md` 갱신(SESSION_CLOSE_CHECKLIST 정합성 3문항 통과), `WORKFLOW_team-lead_W3.md` Step 7/8 체크박스.
4. **W4 이월 명시** — 클라우드 E2E, staging 5/5, 잔여 팀 Kafka 구현/머지.

## 5. 산출물 / 완료 정의

### 산출물

- **신규**: cross-repo work-order ×5, 갱신된 `TEAM_CHECKLIST_W3.md`, 로컬 E2E harness 베이스라인 결과 기록.
- **채움**: `E2E_REPORT_W3.md`, `DEPLOY_REPORT_W3.md` (실제 결과 — 미구현/이월 정직 표기).
- **동기화**: `HANDOFF_HUB.md`, `HANDOFF_SHARED.md` (W3→W4), `WORKFLOW_team-lead_W3.md` Step 7/8.
- **부가**: shared 로컬 셋업 문서에 gitops `local-k8s` 포인터 1줄.

### Definition of Done (shared W3)

- [ ] cross-repo work-order 5건 발행 + 추적 기록 존재
- [ ] 로컬 docker-compose E2E harness가 토픽/스키마/컨슈머 경로를 검증(구현분 한정)
- [ ] E2E/배포 리포트가 실제 결과로 채워짐 (미구현/이월 정직 표기)
- [ ] HANDOFF_HUB/SHARED 정합성 ✅ + W4 이월 명시
- [ ] WORKFLOW Step 7/8 체크박스 현행화

> **명시적 비목표**: "팀 5개 서비스 E2E 그린"은 팀 미착수로 이번 주 done 조건이 **아니다**. shared의 가치는 harness·work-order·정직한 리포트·명확한 이월에서 나온다.

## 6. 리스크 & 대응

| 리스크 | 영향 | 대응 |
|--------|------|------|
| 팀 Kafka PR 이번 주 0건 유지 | E2E 검증 대상 부재 | shared 산출물이 PR 유무와 무관하게 가치 생성하도록 설계. E2E는 "구현된 만큼" |
| 로컬 compose 서비스가 W2 코드(Kafka producer 없음)로 기동 | produce는 토픽 레벨만 검증, consumer 처리 없음 | 리포트에 "토픽 경로 OK / consumer 미구현" 분리 기록 |
| 05-22 플랜과의 혼선 | 중복·모순 | 본 스펙 상단에 shared 한정 현행화·대체 명시, gitops는 머지된 통합 플랜 참조 |
| 로컬 이미지 빌드/풀 실패 | compose 기동 불가 | Day 1 harness 베이스라인에서 조기 발견 → 트러블슈팅 |

## 7. 범위 밖

- gitops 인프라 재구축·staging·관측 작업 (머지된 gitops 통합 플랜 담당)
- 클라우드(dev/staging) E2E (W4 이월)
- 팀원 서비스 Kafka 구현 자체 (각 owner 책임 — shared는 명세·리뷰·조율만)
- minikube/local-k8s 이동 (gitops 잔류 — D4)
