# Synapse 통합 핸드오프 허브

> **최종 갱신**: 2026-06-08 (W5 Day 1 — EKS 재apply→**dev/staging 5/5 ALL PASSED**, 서비스 단위 E2E 환경 구축, 정본 avsc 표준 정렬(P0 2건 근본 원인 제거))
> **현재 주차**: W5 Day 1 (06-08, 발표 06-15)
> **갱신자**: @VelkaressiaBlutkrone
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

[잔여-owner-P0] Avro 계약 — 서비스 벤더링 교체 (Day2 풀 E2E 선결, AVRO_CONTRACT_FIX_W5)
    ├─ engagement: UserRegistered reader 구형 registeredAt → 정본 교체 (F1, 가입 체인 차단)
    └─ learning-ai: NotificationSend writer namespace/메타 → 정본 교체 (F2/F3, 알림 체인 차단)
    └─→ shared 정본은 ✅ 정렬 완료(#26), 서비스 측만 남음

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
| synapse-gitops | `docs/project-management/history/HISTORY_gitops.md` | 2026-06-02 | ✅ 동기 — MSK 토픽 terraform화·TLS-only·EKS window 하드닝(#87~89) 완료, #91 잔여 |
| synapse-shared | `docs/project-management/HANDOFF_SHARED.md` | 2026-06-05 | ✅ 동기 — §5 Kafka 추적 origin/main 실측 정정 |

> **W4 종료 게이트 평가 + W5 인수**: [reports/W4_EXIT_GATE.md](../reports/W4_EXIT_GATE.md) (06-05, §5 성공기준 6/6 구현충족·검증대기 + 머지 조율 + 리스크 처리).

---

## 4. 다음 세션 작업 순서

> **W3 종료 → W4 인수인계**: W3 종료 게이트 미통과(**충족 1/5** · 부분 1 · 미확인 3, [W3_EXIT_GATE](../reports/W3_EXIT_GATE.md)). **§1 레지스트리 BACKWARD는 06-02 로컬 `--avro`(8/8)+강제 프로브로 실검증 → ✅.** shared 전제(토픽·스키마·harness·Security·배포전략·계약표준·발행)는 완료.
> **▶ 월요일(06-01) 바로 시작 순서: [W4_PLAN.md](./W4_PLAN.md)** — Day1 병렬 2트랙(A: EKS `terraform apply` / B: v0.1.0 발행 + knowledge Producer 착수 + 필드 확정), 화요일 consumer, 목요일 통합 E2E.

```
1. [team-lead] 🟢 최우선 — **통합 E2E 실행**(Step 9). 4서비스 Kafka 전원 origin/main → 머지 대기 없이 로컬 compose에서 즉시 실행 가능.
     → ✅ 전제 충족(06-05 origin/main 실측): knowledge #40·platform #46·engagement #23·learning — Producer/Consumer 전원 main
     → 시나리오: E2E_SCENARIOS_W4 S1~S4 (복습→XP→레벨업→알림 <10초 등)
     → [owner들] W4 하드닝 dev→main 머지(병행): platform(S6 #52/TLS #54/게이트 #61/staging #48), engagement #24, knowledge #42/#43/#45 — EKS 배포·전도메인 audit 커버에 필요
2. [shared] 서비스 PR 도착 시 E2E consumer 시나리오 확장 검증
     → ✅ 선행 완료: 로컬 harness 전송 경로 + CloudEvent 단위 round-trip (--all 5/5, --full 13/13)
     → 잔여: E2E_SCENARIOS_W3.md 시나리오로 consumer 비즈니스 로직까지 검증
3. [gitops] ArgoCD 부트스트랩([#91](https://github.com/team-project-final/synapse-gitops/issues/91)) — **✅ 06-02 dev 5/5(15/15)+롤백 검증 완료** (FR-TL-402 dev 충족). 재apply 시 `bring-up.sh`
     → ✅ 선결 자동화(06-02): 토픽 terraform·브로커 ConfigMap(#88)·D-026 SG(#89)·bastion aws-auth(#87)
4. [platform owner] platform-svc `application-staging.yml` **datasource url/password 연결**([#37](https://github.com/team-project-final/synapse-platform-svc/issues/37)) → staging 4/5→5/5
     → 06-02 검증: 다른 4개 staging ✅, **platform-svc만 CrashLoop**(datasource 미연결). gitops overlay/시크릿은 정상
5. [gitops] Observability 설치 — 매니페스트 작성됨(`infra/monitoring/`) → window apply + 서비스별 `/metrics` 노출(서비스 owner)
6. [gitops] terraform state 정리 — D-026 SG ✅(#89 완료) / OIDC 코드 반영 잔여
     → 완료 기준: terraform plan → no unexpected drift
```

---

## 5. 주간 마일스톤 추적

| 주차 | 목표 | 상태 | 실제 완료일 |
|---|---|---|---|
| W1 (5/12-16) | ArgoCD bootstrap + CI | ✅ 완료 | 5/16 |
| W2 (5/19-23) | Dev 5앱 + secrets + image sync | ✅ 완료 | 5/21 (9차 세션) |
| W3 (5/26-29) | Kafka E2E + Staging + Observability | 🔴 게이트 미통과 | 종료 충족 **1/5** (부분 1·미확인 3) — §1 레지스트리 BACKWARD 06-02 실검증 ✅. shared 전제 완료. 서비스 Kafka(06-02): learning·platform·**knowledge** Producer/스키마 완성 / **engagement** Consumer만 잔여 — **전원 dev→main 미머지** + EKS destroy로 W4 이월 |
| W4 (6/01-05) | Notification/Audit 소비 + Admin 모더레이션 + 통합 E2E + dev/staging 배포 검증 | 🔄 진행(Day4, 마지막날) | — · **서비스 Kafka 4서비스 전원 origin/main 머지 완료**(knowledge#40·platform#46·engagement#23·learning) + S5 모더레이션(#23)·S6 audit(platform dev #52) 구현 / 잔여=통합 E2E·SLA **실행**(머지 무관, 로컬 가능) + EKS staging window + 하드닝 dev→main 머지 |
| W5 (6/08-12) | E2E + 버그수정 + P1 마무리 + Staging + 발표 자료/리허설 (발표 6/15) | ⏳ 계획 | — |
