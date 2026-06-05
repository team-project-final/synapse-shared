# Synapse 통합 핸드오프 허브

> **최종 갱신**: 2026-06-05 (W4 Day 4 — **서비스 Kafka 머지 상태 origin 실측 정정**: 4서비스 Kafka Producer/Consumer **전원 origin/main 머지 완료** → 통합 E2E는 머지 무관·실행 가능. 잔여=W4 하드닝 dev→main 머지 + E2E/SLA 실행 + EKS staging window)
> **현재 주차**: W4 Day 4 (06-05, W4 마지막 영업일)
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
| platform-svc | ✅ Healthy | ✅ 5/5(06-02)→destroy | 🔴 CrashLoop([#37](https://github.com/team-project-final/synapse-platform-svc/issues/37)) | ⏳ W4 |
| engagement-svc | ✅ Healthy | ✅ 5/5(06-02)→destroy | ✅(06-02)→destroy | ⏳ W4 |
| knowledge-svc | ✅ Healthy | ✅ 5/5(06-02)→destroy | ✅(06-02)→destroy | ⏳ W4 |
| learning-card | ✅ Healthy | ✅ 5/5(06-02)→destroy | ✅(06-02)→destroy | ⏳ W4 |
| learning-ai | ✅ Healthy | ✅ 5/5(06-02)→destroy | ✅(06-02)→destroy | ⏳ W4 |

> 상태 enum: ✅ Healthy / 🔄 검증 대기(apply 후) / ⚠️ Degraded / 🔴 Down / ⏳ destroy(on-demand 재기동) or Not Started
> **06-02 라이브 검증(gitops #91)**: ArgoCD 부트스트랩 → **dev `verify-argocd-deploy.sh synapse-dev` 15/15 ALL PASSED(5/5)** + 롤백 124s(<3분) → **FR-TL-402 dev 충족**. **staging 4/5** — platform-svc만 CrashLoop([#37](https://github.com/team-project-final/synapse-platform-svc/issues/37): application-staging.yml datasource 미연결). 검증 후 비용관리 destroy(on-demand). 로컬 compose는 항상 ✅.

### 인프라 상태

| 컴포넌트 | 상태 | 비고 |
|---|---|---|
| EKS | ⏳ destroy (on-demand) | **06-02 재apply→부트스트랩→dev 5/5 검증→destroy**(gitops #91). v1.30, 프라이빗 엔드포인트, bastion aws-auth 코드화(#87) |
| RDS PostgreSQL 16 | ⏳ destroy | **D-026 SG terraform 코드화 완료(gitops #89)** — 재apply 시 자동(수동 불요) |
| MSK Kafka | ⏳ destroy | **토픽 terraform 관리(gitops kafka-topics/, RF=2)** + **브로커 주소 ConfigMap 자동화(#88)** → 재apply 시 자동. 로컬 Kafka로 대체 검증 |
| Redis | ⏳ destroy | D-026 SG terraform 코드화 완료(#89) — 자동 |
| Elasticsearch | ⏳ destroy | OpenSearch→Elasticsearch 전환(gitops PR #114). D-026 SG terraform 코드화 완료(#89) — 자동 |
| ArgoCD | ⏳ destroy | HA, dev auto-sync + staging manual. **06-02 부트스트랩 완료·검증(gitops #91)** — 재apply 시 `bring-up.sh`로 부트스트랩 |
| 로컬 docker-compose | ✅ | 13 서비스 Healthy — **W4 임계경로 검증 환경**(EKS 무관) |

### Kafka / 스키마 상태

| 항목 | 상태 |
|---|---|
| **이벤트 계약 표준** | ✅ 수립 — Avro + Schema Registry (D-002 Option 1). [EVENT_CONTRACT_STANDARD](../guides/EVENT_CONTRACT_STANDARD.md) |
| Avro 스키마 | ✅ 이벤트 11종(기존 보강 + 신규 CardReviewDue/LevelUp/BadgeEarned/NotificationSend), 공통메타 적용, generateAvroJava 컴파일. BACKWARD |
| 토픽 (로컬 Kafka) | ✅ 8종 생성(신규 4종 추가: review-due/level-up/badge-earned/notification-send) + round-trip 검증 |
| MSK 토픽 (EKS) | ⏳ destroy — 재기동 window에 `create-kafka-topics.sh` 9토픽(8 active + cards-generated 잔존) 재생성 |
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

[독립-잔여] W4 하드닝 dev→main 머지(EKS/MSK 배포 시 필요, 로컬 E2E 무관)
    ├─ platform dev 11커밋: S6 audit 다중토픽(#52)·TLS(#54)·KAFKA_ENABLED 게이트(#61)·staging 프로파일(#48→#37 해소)·Step9 E2E(#57)
    ├─ engagement dev: #24 step9-11 flow
    └─ knowledge dev: 컨벤션(#42)·노트버전이력(#43)·MSK TLS(#45)

[선행완료] 로컬 E2E harness — 전송 경로 + CloudEvent 단위 round-trip 검증 ✅ / 계약 BACKWARD 실검증 ✅(06-02 --avro)

[해소] EKS window 진입 하드닝 ✅(gitops #87~89) → 잔여 ArgoCD 부트스트랩(gitops #91)
    └─→ dev/staging EKS 검증 (MSK 토픽=terraform 자동)

[블로커] platform-svc application-staging.yml datasource 연결 (platform owner, #37/gitops#92)
    └─→ staging 4/5→5/5 (다른 4개 ✅ 06-02 검증, platform-svc만 CrashLoop)

[독립] Observability 스택 (gitops, 매니페스트 작성됨) → window apply
[독립] terraform state 정리 — OIDC 코드 반영 (gitops) / SG D-026 ✅(#89)
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
