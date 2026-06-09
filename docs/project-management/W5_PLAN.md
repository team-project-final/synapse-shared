# W5 실행 순서 (월요일 바로 시작용)

> **작성**: 2026-06-05 (W4 종료) · **기간**: 2026-06-08(월)~06-12(금), 5영업일 · **발표**: 06-15(월, 코드 동결)
> **근거**: [PRD_W5](./prd/PRD_W5.md) · [W4_EXIT_GATE](../reports/W4_EXIT_GATE.md)(이월 출처) · [E2E_SCENARIOS_W4](../guides/E2E_SCENARIOS_W4.md) · [SLA_VERIFICATION_W4](../reports/SLA_VERIFICATION_W4.md)
> **W5 목표(PRD)**: 전체 E2E + P0 버그 0 + 커버리지 80% + Staging 배포 + 발표 자료/리허설

---

## 0. W4 이월 항목 (왜 W5로 넘어왔나)

> W4는 **구현 완료, 검증 실행 미완**으로 종료. shared compose의 app 컨테이너가 스텁이라 서비스 비즈니스 로직 E2E를 W4에서 못 돌림 + EKS destroy로 staging 미가동. 4서비스 Kafka는 origin/main 머지 완료라 **머지 차단은 없음 — 잔여는 "실행"**.

| 이월 | 출처 | W5 담당 | 선결 |
|---|---|---|---|
| 서비스 비즈니스 로직 E2E (FR-ALL-301) | W4 Step 9.2 | team-lead 조율 + 각 owner | 서비스 스택 기동 or staging |
| SLA 성능 측정 (FR-TL-301, Step 10) | W4 Step 10.2 | team-lead | E2E 통과 후 |
| Staging 배포 + Observability (FR-ALL-304/FR-TL-303, Step 11) | W4 Step 11 | team-lead/gitops | EKS 재apply window |
| 하드닝 dev→main 머지 | W4_EXIT_GATE §2 | 각 owner | — (platform #52 audit·#54 TLS·#48 staging / engagement #24 / knowledge #45) |
| platform staging CrashLoop 해소 | #37 (수정 #48) | platform owner + gitops | #48 머지 + EKS |
| KAFKA_ENABLED 게이트 | #59/#46/#49 | platform/knowledge/learning owner | — |

---

## 1. 월(06-08) Day 1 — staging window + 하드닝 머지 + E2E 착수 (병렬)

### Track A — 인프라 (team-lead/gitops)
- [x] EKS `terraform apply` → ArgoCD 부트스트랩(`bring-up.sh`) → dev 5/5 재확인 — **06-08 완료**: 62리소스 + 14앱 Synced + monitoring 스택까지(Day 4 Observability 선반영). dev **16/0/0 ALL PASSED**
- [x] **staging 배포 + platform CrashLoop(#37) 해소 → staging 5/5** — **06-08 완료, 단 경로 변경**: 근본 원인은 #48(staging 프로파일)이 아니라 **5서비스가 단일 RDS `synapse` DB 공유 → flyway_schema_history 충돌** ([gitops#136](https://github.com/team-project-final/synapse-gitops/pull/136) DB 분리로 해소). gateway CrashLoop(JWT_PUBLIC_KEY 미매핑, #128은 local 전용)도 동일 PR. staging **20/0/0 ALL PASSED**

### Track B — 머지 조율 + 서비스 E2E 착수 (team-lead + owner)
- [ ] **[owner] 하드닝 dev→main 머지**: platform #74만 잔여(#52·#54·#61은 release #73로 main 반영됨), engagement #24·#29(+#23 dev 역동기화), knowledge(#42·#43·#45 TLS + open PR #51) → main 정합. **learning은 dev +18커밋 — release PR 필요**
- [ ] **[owner] KAFKA_ENABLED 게이트**: platform #61 ✅main / learning #54 ✅dev(main 머지 대기) / **knowledge #46 미구현(OPEN)**
- [x] **[team-lead] 서비스 스택 E2E 환경 구성** — **06-08 완료**: `docker-compose.e2e.yml`(origin/main worktree 실빌드, 13/13 healthy, [shared#25](https://github.com/team-project-final/synapse-shared/pull/25)). 가입 스모크에서 **P0 2건 발견**(engagement UserRegistered reader / learning-ai NotificationSend writer) → 정본 정렬 [shared#26](https://github.com/team-project-final/synapse-shared/pull/26) + owner 지시서 [AVRO_CONTRACT_FIX_W5](../fix-requests/AVRO_CONTRACT_FIX_W5.md). 상세: [E2E_SMOKE_W5_DAY1](../reports/E2E_SMOKE_W5_DAY1.md)

> **Day 2 선결 주의**: 핵심 10 시나리오 중 가입→게이미피케이션·노트→AI카드→알림 체인은 **owner P0 수정(AVRO_CONTRACT_FIX_W5) 전까지 FAIL 확정** — Day 2 트리아지에 선반영됨.

## 2. 화(06-09) Day 2 — 전체 E2E (서비스 단위) + 버그 트리아지
> **06-09 실행 결과**: [E2E_W5_DAY2](../reports/E2E_W5_DAY2.md) — P0 2건(F1/F2·F3) 수정·라이브 재검증 완료. 핵심 시나리오 W4·W2 PASS / W3 알림 leg PASS·AI생성 leg는 F4 차단 / W1·W5 사전 차단(시드 갭 + 신규 F7 JWT 신원 불일치).
- [x] **(team-lead) Day1 P0 2건 정본 벤더링 교체 + 라이브 재검증** — engagement#32·learning#64, 가입/알림 체인 에러 0 ✅
- [~] **(전체, FR-ALL-301 / NFR-303)** 핵심 10 시나리오 E2E — W4 가입→프로필 ✅ / W2 audit ✅ / W3 알림발행·소비 ✅(AI생성 leg F4 차단) / **W1 복습→레벨업 🔴**(SRS 세션 API + 레벨업 경계 시드 갭) / **W5 신고→모더레이션 🔴**(F7 JWT 신원 불일치 + 시드 갭)
- [ ] **(team-lead, FR-TL-401 재검)** 전체 체인 E2E **복습→XP→레벨업→알림 < 10초** — W1 차단으로 미실행(레벨업 경계 시드 + SRS 세션 구동 선결)
- [x] audit 적재 < 30초 (NFR-403) — `USER_REGISTERED` audit_logs 적재 확인 ✅
- [x] **버그 트리아지** — P0(F1/F2·F3) 수정 완료 / **신규 P1 F7**(크로스서비스 JWT 신원 모델 불일치) 지시 대상: @engagement+@platform / P2 F4(AI 키 게이트)

## 3. 수(06-10) Day 3 — SLA + 커버리지 + API 문서
- [ ] **(team-lead, FR-TL-301 / NFR-301)** SLA 측정 — API P95<200ms · Kafka<5s · 검색<2s (SLA_VERIFICATION_W4 P1~P7, 3회 평균)
- [ ] **(전체, FR-ALL-303 / NFR-302)** 커버리지 80%+ (jacoco/coverage/flutter_test)
- [ ] **(team-lead, FR-TL-302)** Schema Registry 전 토픽 BACKWARD 전수 — `--avro` 라이브 + 강제 프로브
- [ ] **(team-lead, FR-TL-304)** API 문서 최신화 (SpringDoc OpenAPI + gateway 라우팅 대조)

## 4. 목(06-11) Day 4 — Staging 최종 + 모니터링 + 24h 안정
- [ ] **(team-lead, Step 11, FR-ALL-304)** Staging 최종 배포 + 전 서비스 Health
- [ ] **(gitops, FR-TL-303, W3→W4→W5 이월)** Observability 설치(kube-prometheus-stack) + ServiceMonitor 5 + Grafana 대시보드 + 알림 규칙
- [ ] **(NFR-305)** staging 24h 안정 운영 모니터 시작
- [ ] P0 버그 회귀 테스트 (FR-ALL-302 → P0 0건)

## 5. 금(06-12) Day 5 — 발표 자료 + 리허설 (D-3)
- [ ] **(team-lead, Step 12, FR-TL-305)** 발표 슬라이드(15~20) + 데모 스크립트(5분) 확정
- [ ] 시연 환경 사전 점검 (staging/네트워크/시드 계정/깨진 링크 0)
- [ ] **전체 팀 시연 리허설 1회 이상** + 회고 → 보완
- [ ] **코드 동결 준비** — 06-15 발표 전 P0 hotfix만 허용

---

## 6. team-lead TASK 매핑 (W5)
| Step | 내용 | W5 배치 |
|------|------|--------|
| Step 9 (W4 이월) | E2E 서비스 단위 실행 조율 | Day 2 |
| Step 10 (W4 이월) | SLA 성능 측정 | Day 3 |
| Step 11 (W4 이월) | Staging 최종 + 모니터링 | Day 4 |
| Step 12 | 발표 자료 + 리허설 | Day 5 (리허설 6/12) |

## 7. 선결 체크 (월요일 출발 전 → 06-08 종료 시점)
- ✅ 4서비스 Kafka origin/main 머지 완료 (E2E 머지 차단 없음)
- ✅ 계약·전송 E2E 베이스라인 PASS (E2E_REPORT_W4)
- ✅ E2E/SLA 시나리오 정의 완료 (E2E_SCENARIOS_W4 / SLA_VERIFICATION_W4)
- ✅ ~~EKS destroy~~ — **06-08 재apply 완료**, dev/staging 5/5 (gitops#136 머지 후)
- ⛔ 하드닝 dev→main 머지 (owner) — **잔여(§1 Track B)**: engagement #24·#29, knowledge #42/#43/#45/#51, learning release, knowledge #46 게이트
- ✅ ~~서비스 단위 E2E 실행 환경~~ — **06-08 `docker-compose.e2e.yml` 완료**

## 8. Day 1 종료 산출물 (06-08 추가)
| 산출물 | 경로/PR | 비고 |
|--------|---------|------|
| 서비스 E2E 환경 | `docker-compose.e2e.yml` + `scripts/initdb/` ([shared#25](https://github.com/team-project-final/synapse-shared/pull/25), merged) | 스텁→origin/main 실빌드, 서비스별 DB 분리 |
| Day1 스모크/Avro 감사 | [E2E_SMOKE_W5_DAY1](../reports/E2E_SMOKE_W5_DAY1.md) | 13/13 healthy, P0 2건·인프라 F5/F6 |
| 정본 스키마 정렬 | UserRegistered/NotificationSend ([shared#26](https://github.com/team-project-final/synapse-shared/pull/26), merged) | platform writer 정합, BACKWARD 검증 |
| owner 수정 지시서 | [AVRO_CONTRACT_FIX_W5](../fix-requests/AVRO_CONTRACT_FIX_W5.md) | engagement F1·learning F2/F3/F4 |
| DB 분리 + gateway JWT | [gitops#136](https://github.com/team-project-final/synapse-gitops/pull/136) (merged) | platform/gateway CrashLoop 근본 해소 |
| verify 스크립트 보강 | `scripts/verify-argocd-deploy.sh` | kubectl CRD 우선(SSM 터널 argocd login 불가 대응) |

> **한 줄 요약**: 월=EKS 올리고+하드닝 머지+E2E 환경, 화=전체 E2E+버그, 수=SLA+커버리지+문서, 목=staging 최종+모니터링, 금=발표 리허설(6/12). 발표 6/15.
