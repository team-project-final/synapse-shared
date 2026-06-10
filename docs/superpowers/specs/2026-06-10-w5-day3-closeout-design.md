# 설계 — W5 Day3 마무리(closeout): owner 무관 오늘 종결 항목

> **작성**: 2026-06-10 (W5 Day3) · **작성자**: @team-lead
> **상위**: [HANDOFF_W5_DAY3 §0](../../project-management/HANDOFF_W5_DAY3.md) · [W5_PLAN §3](../../project-management/W5_PLAN.md)
> **상태**: 🟢 승인(사용자, 2026-06-10) — 다음=실행 플랜

---

## 1. 목적

각 레포 owner 작업과 **무관하게**, team-lead/shared 단독으로 **오늘 종결 가능한 항목만** 선별·실행한다. 부분 진척·owner 의존·외부 자격 의존 항목은 **명시적으로 제외**한다.

## 2. 범위 (IN — 오늘 종결)

| 우선 | 항목 | 종류 | 종결 정의 |
|---|---|---|---|
| 1 | **platform 커버리지 baseline** | 오프라인 | platform-svc jacoco 리포트 생성 + 현재 커버리지% 기록 |
| 2 | **W1 풀체인 정식 PASS 종결** | 라이브 | 복습→XP→레벨업→audit→알림(FCM skip 경로) 단일 시나리오 PASS 기록 (A 머지로 알림 leg 동작) |
| 3 | **SLA P1~P5 측정·리포트 종결** | 라이브+기측정 | P1·P2·P4·P5(기측정 통합) + P3 검색(라이브 신규) → SLA 결과 리포트 |
| 4 | **추적/문서 정합** | 오프라인 | WORKFLOW_W5·HANDOFF에 위 종결분 반영 |

## 3. 범위 (OUT — 오늘 제외, 사유 명시)

- **P6 AI(<30s)** — AI키 부재(`.env` 실측 0건) → learning #73(F4). 외부 의존.
- **P7 실 FCM 발송률(>95%)** — FCM 자격 부재. **경로 신뢰성(engagement→platform→FCM skip)은 측정 가능하나 실 발송률은 보류**(W4-1 FCM/SES와 동급). 리포트에 "경로 OK / 실발송 보류"로 기록.
- **커버리지 80% 달성** + engagement·knowledge·learning **jacoco 미설정**(실측 0곳) → 각 owner 빌드 설정. baseline 집계는 platform만.
- **owner 이슈** — F8(#86)·audit DLT(#87)·F4(#73)·knowledge release(#68)·API문서(#84/#67/#72). 어제 발행, owner 작업.

## 4. 환경 전제

- **오프라인(우선 1·4)**: Docker 불필요. 로컬 레포 체크아웃에서 gradle.
- **라이브(우선 2·3)**: **Docker Desktop 재기동 + e2e 스택 재빌드** 선행(현재 데몬 down). `docker compose -f docker-compose.yml -f docker-compose.e2e.yml up -d --build` (engagement는 origin/main에 A 머지됨 → worktree origin/main 새로고침 후 빌드). stale 볼륨 시 `down -v`.

## 5. 산출물

- `docs/reports/SLA_VERIFICATION_W5.md` — P1~P7 표(P1~P5 측정값, P6/P7 보류 사유).
- `docs/reports/COVERAGE_BASELINE_W5.md` — platform 커버리지% + 타서비스 jacoco 미설정 명시(owner 이월).
- W1 풀체인 종결 기록(SLA 리포트 또는 별도 섹션).
- `WORKFLOW_team-lead_W5.md`(Step10 일부·FR-ALL-303 부분)·`HANDOFF_W5_DAY3 §0` 갱신.
- shared feature→main PR.

## 6. 실행 순서 (다음 플랜)

오프라인 1 → (Docker 재기동·스택 up) → 라이브 2·3 → 통합 4 → PR. 라이브 준비가 오래 걸리면 1을 그 사이 진행(병렬). P6/P7/owner는 손대지 않음.
