# Synapse 통합 핸드오프 허브

> **최종 갱신**: 2026-06-09 (W5 Day 2 — **P0 2건(F1/F2·F3) 벤더링 정본 교체 + 라이브 재검증 완료**(engagement#32·learning#64), 가입→게이미피케이션·알림 발행/소비·audit 적재 E2E PASS. 신규 P1 F7(크로스서비스 JWT 신원 불일치) 발견)
> **현재 주차**: W5 Day 2 (06-09, 발표 06-15)
> **갱신자**: @VelkaressiaBlutkrone
>
> ⏱ **Day2 E2E 결과**: [E2E_W5_DAY2](../reports/E2E_W5_DAY2.md) — W4 가입·W2 audit·W3 알림 leg PASS / W1 복습→레벨업·W5 신고→모더레이션 BLOCKED(시드 갭 + F7)
>
> ⚠️ **06-05 실측 방법 주의**: 머지 상태는 반드시 **`git fetch` 후 `origin/main`** 기준으로 확인할 것. 로컬 main/feature 브랜치는 stale일 수 있어 오판 유발(이번 갱신서 knowledge 로컬 main이 05-20에 멈춰 "미머지" 오판 → origin/main #40으로 정정). 검증: `git -C <repo> log origin/main -1`.

---

## 1. 프로젝트 상태 대시보드

### 환경별 서비스 상태

> ⏳ **EKS는 on-demand** — **현재 destroy** (06-01 apply→검증보류→destroy). 상태는 apply↔destroy로 변동 → **확인은 `aws eks describe-cluster --name synapse-dev`**(STATUS/존재 여부). **재apply 선결(bastion aws-auth·SG·브로커·토픽)은 06-02 gitops 하드닝(#87~89)으로 terraform 자동화** → 잔여는 **ArgoCD 부트스트랩([gitops #91](https://github.com/team-project-final/synapse-gitops/issues/91))**([W4_DAY1_POST_APPLY](../runbooks/W4_DAY1_POST_APPLY.md)).
> **임계경로(서비스 Kafka·통합 E2E·계약)는 EKS 무관** → **로컬 docker-compose**로 진행([W4_PLAN](./W4_PLAN.md) §0 "[배포] Kafka 무관, 병렬 가능"). EKS는 **배포 검증(Step 8/11)·Observability window**에만 재기동 → 검증 → 다시 destroy.
> 재기동 시 절차: [W4_DAY1_POST_APPLY](../runbooks/W4_DAY1_POST_APPLY.md).

| 서비스 | 로컬 compose | dev (EKS) | staging | prod |
|---|---|---|---|---|
| platform-svc | ✅ Healthy | ✅ **5/5(06-08)** | ✅ **5/5(06-08, CrashLoop 해소)** | ⏳ W5 |
| engagement-svc | ✅ Healthy | ✅ 5/5(06-08) | ✅ 5/5(06-08) | ⏳ W5 |
| knowledge-svc | ✅ Healthy | ✅ 5/5(06-08) | ✅ 5/5(06-08) | ⏳ W5 |
| learning-card | ✅ Healthy | ✅ 5/5(06-08) | ✅ 5/5(06-08) | ⏳ W5 |
| learning-ai | ✅ Healthy | ✅ 5/5(06-08) | ✅ 5/5(06-08) | ⏳ W5 |
| gateway | ✅ Healthy | ✅ **5/5(06-08, JWT 매핑 해소)** | — | ⏳ W5 |

> **06-08 라이브 검증**: `verify-argocd-deploy.sh` **dev 16/0/0 · staging 20/0/0 ALL PASSED**. platform CrashLoop(#37)의 실제 근본 원인 = **5서비스가 단일 RDS `synapse` DB 공유 → flyway_schema_history 충돌**(이전 가설 #48 staging 프로파일 아님), gateway CrashLoop = JWT_PUBLIC_KEY ExternalSecret 미매핑(#128 local 전용). 둘 다 [gitops#136](https://github.com/team-project-final/synapse-gitops/pull/136)(DB 분리 + JWT 매핑)로 해소. **EKS는 검증 후에도 유지 중**(W5 staging 24h 안정·SLA 측정 필요) — Day 4 종료 후 destroy 판단.

> 상태 enum: ✅ Healthy / 🔄 검증 대기(apply 후) / ⚠️ Degraded / 🔴 Down / ⏳ destroy(on-demand 재기동) or Not Started
> **06-02 라이브 검증(gitops #91)**: ArgoCD 부트스트랩 → **dev `verify-argocd-deploy.sh synapse-dev` 15/15 ALL PASSED(5/5)** + 롤백 124s(<3분) → **FR-TL-402 dev 충족**. **staging 4/5** — platform-svc만 CrashLoop([#37](https://github.com/team-project-final/synapse-platform-svc/issues/37): application-staging.yml datasource 미연결). 검증 후 비용관리 destroy(on-demand). 로컬 compose는 항상 ✅.

### 인프라 상태

| 컴포넌트 | 상태 | 비고 |
|---|---|---|
| EKS | ✅ **ACTIVE (06-08 재apply)** | 62리소스, v1.30, 프라이빗 엔드포인트. W5 staging 안정·SLA 측정 위해 유지(Day 4 후 destroy 판단) |
| RDS PostgreSQL 16 | ✅ ACTIVE | 서비스별 DB 5개로 분리(gitops#136, `synapse_*`). learning-ai용 pgvector는 EKS RDS에 별도 확인 필요(Day 2) |
| MSK Kafka | ✅ ACTIVE | **토픽 terraform 관리(gitops kafka-topics/, RF=2)** + 브로커 ConfigMap 자동화(#88) — 재apply 시 자동 |
| Redis | ✅ ACTIVE | ElastiCache, transit TLS |
| Elasticsearch | ✅ ACTIVE | OpenSearch→Elasticsearch 전환(gitops PR #114) |
| ArgoCD | ✅ ACTIVE | HA, dev auto-sync + staging auto-sync. 14앱 Synced(06-08 `bring-up.sh`) |
| Observability | ✅ **기동(06-08)** | kube-prometheus-stack + Grafana + Alertmanager + Loki/Promtail (Day 4 ServiceMonitor/대시보드 검증·SLA 알림) |
| 로컬 docker-compose | ✅ | 13 서비스 Healthy + **e2e overlay**(서비스 단위 E2E, [shared#25](https://github.com/team-project-final/synapse-shared/pull/25)) |

### Kafka / 스키마 상태

| 항목 | 상태 |
|---|---|
| **이벤트 계약 표준** | ✅ 수립 — Avro + Schema Registry (D-002 Option 1). [EVENT_CONTRACT_STANDARD](../guides/EVENT_CONTRACT_STANDARD.md) |
| Avro 스키마 | ✅ 이벤트 11종, 공통메타 적용, generateAvroJava 컴파일. BACKWARD. **06-08 정본 정렬**: UserRegistered/NotificationSend → platform-canonical(`com.synapse.platform`), 레지스트리 BACKWARD 검증([shared#26](https://github.com/team-project-final/synapse-shared/pull/26)). ⚠️ 서비스 벤더링 교체 잔여(owner P0, [AVRO_CONTRACT_FIX_W5](../fix-requests/AVRO_CONTRACT_FIX_W5.md)) |
| 토픽 (로컬 Kafka) | ✅ 8종 생성(신규 4종 추가: review-due/level-up/badge-earned/notification-send) + round-trip 검증 |
| MSK 토픽 (EKS) | ✅ ACTIVE(06-08) — terraform 선언 관리(gitops kafka-topics/) 자동 재생성 |
| 로컬 E2E harness | ✅ transport(`--all`/`--full`) + **Avro 라운드트립(`--avro`)** 모드 |
| 라이브러리 발행 | ✅ **발행 완료(06-02)** — GitHub Packages `com.synapse:synapse-shared:0.1.0`([runbook](../runbooks/PUBLISH_SHARED_LIBRARY.md)). `v0.1.0` 태그 push → publish.yml run 26792658024 성공. 잔여: 각 서비스 소비측 의존 배선(read:packages 토큰) |
| 서비스 Kafka Producer/Consumer | 🟢 **4서비스 전원 origin/main 머지 완료(06-05 실측) → 통합 E2E 머지 무관·실행 가능** · **knowledge** 🟢 origin/main **#40**(06-02) NoteCreated Producer 존재 · **platform** 🟢 **#46**(06-01) `AuditKafkaConsumer`+`NotificationKafkaConsumer` · **engagement** 🟢 **#23**(06-04) Consumer + S5 모더레이션 알림 · **learning** 🟢 main Kafka(Avro·알림발행). **dev 잔여(하드닝, main 미머지)**: platform dev 11커밋(#52 S6 audit 다중토픽·#54 TLS·#61 KAFKA_ENABLED 게이트·#48 staging 프로파일·#57 Step9 E2E) / engagement #24 / knowledge 3커밋(#42 컨벤션·#43 노트버전이력·#45 MSK TLS) → **EKS/MSK 배포·전도메인 audit엔 필요, 로컬 E2E엔 불요**. cards-generated HTTP(D-001). |

---

## 2. 교차 의존관계 맵

```
[해소] 서비스 Kafka (06-05 origin/main 실측): **4서비스 Producer/Consumer 전원 origin/main 머지 완료**
    ├─ knowledge ✅ #40(06-02) NoteCreated Producer
    ├─ platform ✅ #46(06-01) audit/notification Consumer
    ├─ engagement ✅ #23(06-04) Consumer + S5
    └─ learning ✅ main Kafka
    └─→ 통합 E2E는 **머지에 막히지 않음** → 로컬 compose에서 즉시 실행 가능(team-lead Step 9)

[잔여-owner] 하드닝 dev→main 머지 (W5 Day1 06-08 실측)
    ├─ platform: #74만 잔여 (S6 audit #52·TLS #54·게이트 #61은 release #73로 main 반영)
    ├─ engagement dev +2: #24 step9-11·#29 flyway guard (+ #23 main→dev 역동기화)
    ├─ knowledge dev +3: #42·#43·#45 TLS (+ open PR #51 flyway) · **#46 KAFKA_ENABLED 게이트 미구현(OPEN)**
    └─ learning dev +18: release PR 필요 (#54 게이트·#56 안정화 포함, + #41/#42 역동기화)

[해소-06-09] Avro 계약 — 서비스 벤더링 교체 + 라이브 재검증 완료 (E2E_W5_DAY2)
    ├─ engagement: UserRegistered 정본 교체 ✅ PR #32 (가입→게이미피케이션 PASS, AvroTypeException 0)
    └─ learning-ai: NotificationSend 정본 교체 ✅ PR #64 (알림 발행→platform 소비 PASS, SerializationException 0)
    └─→ 잔여 = 각 owner 머지(#32·#64) + dev 반영 후 dev→main

[해소-06-09-P1] F7 JWT 신원 모델 불일치 — engagement#33 (W5 신고접수 PASS 검증)
    └─ engagement 인증 API가 platform JWT(subject=UUID) 거부 → CurrentUser.resolveUserId 단일화
    └─→ HTTP·Kafka 동일 도출, 신고 201 + reporter_id=Kafka 프로필 PK 일치 입증

[해소-06-09-P2] F9 knowledge 검색 인증 — knowledge#59 (F7 동일 계열)
    └─ 검색이 platform JWT subject(UUID) 거부 → subject UUID→결정적 Long 폴백(engagement 동일 알고리즘)
    └─→ 라이브 401→500(인증 통과). 잔여 500=시맨틱 leg(learning-ai)=F4+빈 코퍼스

[잔여-P1] F8 platform ADMIN role 발급 메커니즘 부재 (W5 관리자 모더레이션 차단)
    └─ login이 ROLE_USER 하드코딩 + users에 roles 컬럼 없음 + role 명명 불일치(ROLE_ADMIN vs ADMIN)
    └─→ @platform admin 발급 + role claim 규칙 합의 필요 (E2E_W5_DAY2 §3 F8)

[잔여-owner] PR 머지: engagement#32(F1)·#33(F7) · learning#64(F2/F3) · knowledge#59(F9) → dev 반영

[해소-06-08] EKS 재apply → ArgoCD 14앱 → dev 16/0/0 · staging 20/0/0 ALL PASSED
[해소-06-08] platform/gateway CrashLoop = DB 공유 flyway 충돌 + JWT 미매핑 → gitops#136
    └─→ (#37의 실제 근본 원인은 #48 staging 프로파일이 아니었음)
[해소-06-08] Observability 스택 — bring-up에 포함, 기동 완료 (Day4 검증·SLA 알림)
[선행완료] 로컬 E2E harness ✅ + 서비스 단위 E2E 환경 ✅(shared#25)
```

---

## 3. 스포크 참조

| 레포 | 스포크 문서 | 최종 갱신 | 정합성 |
|---|---|---|---|
| synapse-gitops | `docs/project-management/history/HISTORY_gitops.md` | 2026-06-02 | ✅ 동기 — MSK 토픽 terraform화·TLS-only·EKS window 하드닝(#87~89). W5: DB 분리+gateway JWT(#136) |
| synapse-shared | `docs/project-management/HANDOFF_SHARED.md` | 2026-06-09 | ✅ 동기 — W5 Day2 풀 E2E: P0 2건 라이브 PASS·F7/F9 신원 수정·SLA P1/P2/P5 |

> **W4 종료 게이트 평가 + W5 인수**: [reports/W4_EXIT_GATE.md](../reports/W4_EXIT_GATE.md) (06-05). **W5 Day1 결과**: [E2E_SMOKE_W5_DAY1](../reports/E2E_SMOKE_W5_DAY1.md) · [W5_PLAN §8](./W5_PLAN.md).

---

## 4. 다음 세션 작업 순서 (W5 Day 2, 06-09)

> **W5 Day1(06-08) 완료**: EKS 재apply→dev/staging 5/5 · 서비스 단위 E2E 환경 · 정본 스키마 정렬. 인프라·환경 차단 해소됨. **Day2 차단 요소는 owner 액션 2종**(하드닝 머지 + Avro P0 벤더링 교체).

```
1. [owner들] 🔴 Day2 선결 — **Avro 계약 P0 벤더링 교체** ([AVRO_CONTRACT_FIX_W5](../fix-requests/AVRO_CONTRACT_FIX_W5.md))
     → engagement: UserRegistered reader 정본 교체(F1) — 안 하면 가입→게이미피케이션 체인 FAIL
     → learning-ai: NotificationSend writer 정본 교체(F2/F3) — 안 하면 노트→AI카드→알림 체인 FAIL
     → shared 정본은 ✅ 정렬 완료(#26), 서비스 측 벤더링만 남음
2. [owner들] 하드닝 dev→main 머지: engagement #24·#29, knowledge #42/#43/#45/#51 + #46 게이트 구현, learning release(+#54)
3. [team-lead] 🟢 **핵심 10 시나리오 풀 E2E**(Step 9) — `docker-compose.e2e.yml`로 실행. P0 수정 도착분부터 재빌드 검증.
     → 시나리오: E2E_SCENARIOS_W4 (복습→XP→배지→레벨업→알림 <10초 / 노트→AI카드 / 검색 / 신고→모더레이션 / 인증→결제)
     → 버그 트리아지 P0/P1/P2, 전체 체인 <10초·audit <30초
4. [team-lead] EKS RDS에 learning-ai pgvector extension 확인(Day2) — 로컬은 pgvector/pg16, EKS RDS는 별도 확인 필요
5. [team-lead] Day3~ SLA 측정(풀 홉 eventId correlation) · 커버리지 80% · API 문서 · Schema 전수 BACKWARD
6. [gitops/team-lead] Day4 Observability 검증(ServiceMonitor/대시보드/SLA 알림) + staging 24h 안정
```

---

## 5. 주간 마일스톤 추적

| 주차 | 목표 | 상태 | 실제 완료일 |
|---|---|---|---|
| W1 (5/12-16) | ArgoCD bootstrap + CI | ✅ 완료 | 5/16 |
| W2 (5/19-23) | Dev 5앱 + secrets + image sync | ✅ 완료 | 5/21 (9차 세션) |
| W3 (5/26-29) | Kafka E2E + Staging + Observability | 🔴 게이트 미통과 | 종료 충족 **1/5** (부분 1·미확인 3) — §1 레지스트리 BACKWARD 06-02 실검증 ✅. shared 전제 완료. 서비스 Kafka(06-02): learning·platform·**knowledge** Producer/스키마 완성 / **engagement** Consumer만 잔여 — **전원 dev→main 미머지** + EKS destroy로 W4 이월 |
| W4 (6/01-05) | Notification/Audit 소비 + Admin 모더레이션 + 통합 E2E + dev/staging 배포 검증 | 🔄 진행(Day4, 마지막날) | — · **서비스 Kafka 4서비스 전원 origin/main 머지 완료**(knowledge#40·platform#46·engagement#23·learning) + S5 모더레이션(#23)·S6 audit(platform dev #52) 구현 / 잔여=통합 E2E·SLA **실행**(머지 무관, 로컬 가능) + EKS staging window + 하드닝 dev→main 머지 |
| W5 (6/08-12) | E2E + 버그수정 + P1 마무리 + Staging + 발표 자료/리허설 (발표 6/15) | 🔄 진행(Day2) | Day1 EKS 5/5·E2E 환경·정본 정렬 / **Day2 풀 E2E: P0 2건(F1/F2·F3) 라이브 PASS·F7/F9 신원 수정·SLA P1/P2/P5 충족**(engagement#32/#33·learning#64·knowledge#59). 잔여: W1·W5모더(F8)·W3/P3(F4) |
