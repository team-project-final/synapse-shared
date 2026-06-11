# 핸드오프 — W5 Day3 종료(closeout) → Day4 진입점

> **작성**: 2026-06-10 (W5 Day3 연장 세션 종료) · **다음 세션 진입점** · **발표**: 06-15(월, 코드 동결)
> **상위**: [HANDOFF_HUB](./HANDOFF_HUB.md) · [HANDOFF_W5_DAY3](./HANDOFF_W5_DAY3.md)(§0) · [SLA_VERIFICATION_W5](../reports/SLA_VERIFICATION_W5.md) · [W5_PLAN](./W5_PLAN.md)

---

## 1. 한 줄 현황

D-004 Stage1(F10)·Schema BACKWARD·API문서에 더해 **SLA P1·P2·P4·P5·P7 충족 + W1 풀체인 PASS + P3 nori 해소(레이턴시 PASS)**까지 종결. **P7 FCM은 실 웹 토큰을 직접 발급해 100% 실측 PASS**. 남은 건 **owner 레포 체인 갭(P6 AI·P3 기능검색)·커버리지 80%·Day4 staging 24h·발표 자료**.

## 2. 이번 세션 완료 (전부 머지)

| 영역 | 결과 | PR |
|---|---|---|
| **SLA P1·P2·P4·P5** | ✅ 충족(P4 체인 1.31s·P5 audit 1.31s) | shared#38 |
| **SLA P7 FCM** | ✅ **10/10=100%** — 실 웹 등록 토큰(Playwright `getToken` 자동 발급, `secrets/fcm-web/`) 등록 → NotificationSend 10건 전건 accept | shared#43·#45·#48 |
| **W1 풀체인** | ✅ PASS(복습→XP→레벨업→audit→FCM skip, UUID) | shared#38 |
| **P3 검색 nori** | 🟢 커스텀 ES 이미지(`docker/elasticsearch/Dockerfile`, analysis-nori) → 검색 200·**0.012s≪2s**. 기능검색(결과>0)은 owner 잔여 | shared#42 |
| **platform 커버리지** | line **92.4%** baseline | shared#38 |
| **W4 대시보드 정합** | 워크플로 대시보드 **10%→~82%**(원인=parse-workflow가 `WORKFLOW_W4.md` 체크박스 파싱, W5 종결분 미반영) | shared#47 |
| **보안** | `secrets/` .gitignore(FCM 키 커밋 차단) | shared#44 |
| **일정 문서** | task/workflow/history·HUB 정합 | shared#39·#40·#41·#46 |

## 3. SLA 최종 (P1~P7)

| 항목 | 목표 | 결과 |
|---|---|---|
| P1 API P95 | <200ms | ✅ 79.7/15.3ms |
| P2 Kafka 홉 | <5s | ✅ ~1.42s |
| P3 검색 | <2s | 🟡 **레이턴시 0.012s PASS** / 기능검색 결과 0(인덱서·청킹 owner) |
| P4 체인 | <10s | ✅ 1.31s(알림 leg 포함) |
| P5 audit | <30s | ✅ 1.31s |
| P6 AI 카드 | <30s | 🔴 체인 갭(아래) — 측정불가 |
| P7 FCM | >95% | ✅ **100%(10/10)** |

## 4. 미해결 owner 이슈 레지스터 (다음 세션, team-lead 직접 머지 불가)

| 영역 | 이슈 |
|---|---|
| **P6 AI 체인** | knowledge#74(note-create deckId 갭) · learning#77(Anthropic 모델ID 폐기 404) · learning#78(note 본문 fetch 계약 불일치) · ⚠️OpenAI 키 할당량0(사용자 빌링) |
| **P3 기능검색** | knowledge#71(note→ES 인덱서 컨슈머 미등록) · knowledge#72(청킹 pgvector 타입) · gitops#174(EKS nori ECR 이미지) |
| **커버리지 80%** | engagement#39 · knowledge#73 · learning#76(jacoco 설정+테스트) |
| **인증/신원** | platform#86(F8 ADMIN role) · platform#91(미커밋 V28 oauth rename·스키마 갭) |
| **staging/인프라(W5 Day4)** | **gitops#182**(bastion role `eks:DescribeCluster` 결여 → bring-up 자동화 중단·복구됨 + 서비스 ECR 레포 7종 미프로비저닝·team-lead 선생성) · 서비스 이미지 빌드·push 필요(각 owner, 레포는 준비됨) — 상세 [STAGING_BRINGUP_W5_DAY4](../reports/STAGING_BRINGUP_W5_DAY4.md) |
| **audit/배포** | **learning#81**(ReviewCompleted 발행 스키마 정본 분기 → platform#87 DLT **근본수정**, 가설 A 확정: learning=`com.synapse.event.learning`+timestamp-millis ≠ 정본 `com.synapse.learning`+string/long) · platform#87(정본 유지·소비측 graceful skip만 선택) · knowledge#68(dev→main 18커밋 미반영) |
| **API 문서** | platform#84 · knowledge#67 · learning#72(learning-card) |
| **정리** | gitops#175(bringup.out .gitignore) |

## 5. 다음 세션 우선순위

1. **[owner] P6 AI 체인** — 최단 해소: learning#77(모델ID 교체) → #78(note 계약) → knowledge#74(deckId) → OpenAI 빌링. 풀리면 P6<30s 즉시 측정 가능(키·FCM 인프라는 준비됨).
2. **[owner] P3 기능검색** — knowledge#71(인덱서)·#72(pgvector) → 검색 결과>0 → P3 완전 종결. EKS는 gitops#174.
3. **[owner] 커버리지 80%** — 3서비스 jacoco(#39/#73/#76).
4. **[team-lead/gitops] Day4** — staging 최종 + Observability(ServiceMonitor/대시보드/알림) 검증 + **24h 안정**.
5. **[team-lead] Day5(06-12)** — 발표 슬라이드·데모 스크립트·리허설 → 발표 06-15.
6. **[owner 합의]** F8(platform#86)·D-004 Stage2(PK uuid).

## 6. 환경·도구 상태

- **e2e 스택**: 가동 중(13서비스, **FCM 활성**). 재기동 시 `down -v`(stale ZK). registry host 포트=**8086**(8081=platform).
- **FCM**: SA `secrets/fcm-sa.json`(gitignore) + `docker-compose.fcm.yml` 오버라이드(`FCM_ENABLED=true`)로 적용. 실 토큰 재발급 도구 `secrets/fcm-web/`(Playwright headed+persistent `getToken`). `.env`에 `FCM_PROJECT_ID=synapse-fcm`.
- **nori**: `docker/elasticsearch/Dockerfile`(analysis-nori)가 base compose ES에 적용됨(로컬). EKS는 gitops#174.
- **secrets/** 전체 gitignore — SA·토큰·playwright 산출물 커밋 안 됨.
- ⚠️ **OpenAI 키 할당량 0**(429) — 사용자 빌링 확인 필요(P6 임베딩/폴백).

## 7. 주의사항 (함정 회피)

- **워크플로 대시보드**: `team-project-final/workflow-dashboard`의 `parse-workflow.mjs`가 **`docs/project-management/workflow/WORKFLOW_<track>_W<n>.md`의 `### N.N` 체크박스만** 파싱(`[~]`=부분, done 미집계). 주차 완료율 갱신은 **해당 WORKFLOW 파일 체크박스**로 해야 함 — **HUB/HISTORY 수정은 대시보드에 반영 안 됨**(push path=workflow/task/prd만).
- **머지 정책**: 서비스 레포=owner 직접(dev-first: 별도 브랜치→push→dev PR→merge→dev→main PR→merge). team-lead 직접=gitops/shared/gateway(shared는 dev 없음=feature→main). 머지 확인은 `git fetch` 후 origin/main.
- **신원**: platform=UUID 정본 / engagement·knowledge=해시 Long. outbound는 UUID 필요(D-004 Stage1로 engagement outbound 해소).
- **라이브 검증 우선**: 신원/직렬화/계약 변경은 단위테스트가 놓치는 poison-message를 라이브가 잡음.

## 8. 핵심 참조
- SLA: [SLA_VERIFICATION_W5](../reports/SLA_VERIFICATION_W5.md) · 커버리지: [COVERAGE_BASELINE_W5](../reports/COVERAGE_BASELINE_W5.md)
- 검색/API: [API_DOC_SURVEY_W5_DAY3](../reports/API_DOC_SURVEY_W5_DAY3.md) · 스키마: [SCHEMA_BACKWARD_W5_DAY3](../reports/SCHEMA_BACKWARD_W5_DAY3.md)
- 식별자: [D-004](../designs/D-004_USER_IDENTITY_MODEL.md) · 일정: [W5_PLAN](./W5_PLAN.md) · 대시보드: [HANDOFF_HUB](./HANDOFF_HUB.md)
