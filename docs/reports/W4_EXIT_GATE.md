# W4 종료 게이트 평가 + W5 인수인계

> **작성**: 2026-06-05 (W4 Day 4, 마지막 영업일) · **기준**: origin/main 실측(`git fetch` 후)
> **참조**: [PRD_W4 §5](../project-management/prd/PRD_W4.md) · [HANDOFF_HUB](../project-management/HANDOFF_HUB.md) · [W4_PLAN](../project-management/W4_PLAN.md)
> **요지**: **구현은 거의 완료(4서비스 Kafka 전원 origin/main)**, 미완은 **검증 "실행"**(통합 E2E·SLA·staging 배포). 06-02 HANDOFF의 "서비스 Kafka 미머지" 서술은 stale 로컬 main 오판 → origin/main 실측으로 폐기.

---

## 1. PRD_W4 §5 성공 기준 평가 (06-05)

| # | 기준 | 구현(origin/main) | 검증 실행 | 판정 |
|---|---|---|---|---|
| 1 | notification 소비 → FCM 푸시 + SES 이메일 | ✅ platform `NotificationKafkaConsumer`(#46) | ❌ 런타임 발송 미검증(FCM/SES 자격) | 🟡 구현완료·검증대기 |
| 2 | audit 소비 → audit_logs(90일) | 🟡 단일토픽 main(#46) / **전도메인 다중토픽=platform dev #52 미머지** | ❌ 적재 E2E 미실행 | 🟡 부분(머지 필요) |
| 3 | 관리자 신고 + 모더레이션 API | ✅ engagement S5 모더레이션 알림(#23) | ❌ API E2E 미실행 | 🟡 구현완료·검증대기 |
| 4 | 검색 튜닝 + 하이브리드 검색 E2E | ✅ knowledge 검색/RRF(#40), ES 정합(D-003/#16) | ❌ RRF 정확도 E2E 미실행 | 🟡 구현완료·검증대기 |
| 5 | AI 카드 자동생성 E2E | ✅ learning-ai note-created 소비 | ❌ E2E 미실행 | 🟡 구현완료·검증대기 |
| 6 | ArgoCD dev/staging 배포 검증 | dev ✅(5/5, gitops #91) / staging 🟡(4/5, platform CrashLoop #37 — **수정 #48 platform dev에 있음**) | dev 검증 완료 / staging 미완 | 🟡 dev충족·staging대기 |

> **종합**: 6개 기준 모두 **구현은 충족**, 6개 모두 **검증 실행 미완**(staging 제외 전부 로컬 compose로 실행 가능). **W4 단일 잔여 테마 = 검증 실행**(Kafka 머지 차단 아님).

## 2. 머지 조율 — dev→main 하드닝 (owner 액션)

> 4서비스 핵심 Kafka는 **이미 origin/main**. 아래는 **EKS/MSK 배포·전도메인 audit·KAFKA_ENABLED 게이트**에 필요한 하드닝으로, 로컬 E2E와는 무관하나 W5 staging window 전 머지 필요.

| 레포 | dev 미머지(핵심) | 이슈 | 영향 |
|---|---|---|---|
| platform-svc | #52 S6 audit 다중토픽 · #54 TLS · #61 KAFKA_ENABLED 게이트 · **#48 staging 프로파일(→#37 해소)** · #57 Step9 E2E | #37·#51·#59 | §5-2 전도메인 audit, §5-6 staging |
| engagement-svc | #24 step9-11 flow | TLS=#26(신규) | TLS MSK 연결 |
| knowledge-svc | #42 컨벤션 · #43 노트버전이력/태그 · #45 MSK TLS | #46(KAFKA_ENABLED) | EKS TLS |
| learning-svc | TLS는 origin/dev 완료(#50 닫음) | #49(KAFKA_ENABLED) | EKS TLS |

> **KAFKA_ENABLED 게이트 갭**: Spring 3서비스(platform/knowledge/learning-card)는 `synapse.kafka.enabled` 게이트가 없어 gitops `KAFKA_ENABLED` env가 no-op — 이슈 #59/#46/#49. engagement는 정상 게이트.

## 3. 리스크 처리 방향 (06-05 결정: 일부 오늘 + 나머지 W5)

| 리스크 | 06-05 실측 | 처리 |
|---|---|---|
| 검색 ES↔OpenSearch 불일치 | **해소** — gitops 인클러스터 ES 9.2.1 + `ELASTICSEARCH_URIS` 정합(D-003/#114/#16) | ✅ 완료(추가 작업 불요) |
| Kafka TLS 앱 배선 | platform/knowledge/learning origin/dev 완료(#54 등), **engagement만 미배선** | engagement=#26 신규 / 나머지 머지로 해소 |
| platform staging CrashLoop #37 | 수정 #48(staging 프로파일) platform dev에 존재 | 머지+EKS 재기동 시 해소(W5) |

## 4. W5 인수인계 (06-08~12, 발표 06-15)

1. **[team-lead] 통합 E2E·SLA 실행** — 4서비스 origin/main 기준 로컬 compose에서 E2E_SCENARIOS_W4 S1~S4 + SLA_VERIFICATION_W4 P1~P7 실측(머지 무관, 즉시 가능). §5-1~5 검증 완료 처리.
2. **[owners] §2 하드닝 dev→main 머지** — 특히 platform #48(staging)·#52(audit 전도메인).
3. **[team-lead/gitops] EKS staging window** — 재apply → platform 머지본 배포 → staging 5/5 + Observability 설치(W3 이월) + §5-6 완료.
4. **[team-lead] Step 12** — 발표 슬라이드 + 데모 스크립트 + 6/12 리허설.

> **검증 방법 주의(반복 실수 방지)**: 서비스 머지 상태는 **반드시 `git fetch` 후 `origin/main`** 기준 확인. 로컬 main/feature 브랜치는 stale → 미머지 오판 유발(W4 갱신 중 knowledge·platform 2회 발생).
