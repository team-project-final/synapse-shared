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
- [ ] EKS `terraform apply` → ArgoCD 부트스트랩(`bring-up.sh`) → dev 5/5 재확인 (W4 자동화 #87~89·#91 그대로)
- [ ] **하드닝 머지 도착분 staging 배포** — platform #48(staging 프로파일) 머지 후 staging Sync → **platform CrashLoop(#37) 해소 확인 → staging 5/5**

### Track B — 머지 조율 + 서비스 E2E 착수 (team-lead + owner)
- [ ] **[owner] 하드닝 dev→main 머지**: platform(#52 audit 다중토픽·#54 TLS·#61 게이트), engagement #24, knowledge(#42·#43·#45 TLS) → main 정합
- [ ] **[owner] KAFKA_ENABLED 게이트**(Spring 3서비스 #59/#46/#49) — gitops env no-op 해소
- [ ] **[team-lead] 서비스 스택 E2E 환경 구성** — 각 서비스 origin/main 빌드 기동(자체 compose/Testcontainers) 또는 staging에서 consumer 동작 확인 경로 확정

## 2. 화(06-09) Day 2 — 전체 E2E (서비스 단위) + 버그 트리아지
- [ ] **(전체, FR-ALL-301 / NFR-303)** 핵심 10 시나리오 E2E — 복습→XP→배지→레벨업→알림 / 노트→AI카드 / 검색 / 신고→모더레이션 / 인증→결제
- [ ] **(team-lead, FR-TL-401 재검)** 전체 체인 E2E **복습→XP→레벨업→알림 < 10초**(W4 미실행분)
- [ ] audit 적재 < 30초 (NFR-403) — platform #52 머지 후
- [ ] **버그 트리아지** — P0/P1/P2 분류, P0 즉시 수정 지시(owner)

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

## 7. 선결 체크 (월요일 출발 전)
- ✅ 4서비스 Kafka origin/main 머지 완료 (E2E 머지 차단 없음)
- ✅ 계약·전송 E2E 베이스라인 PASS (E2E_REPORT_W4)
- ✅ E2E/SLA 시나리오 정의 완료 (E2E_SCENARIOS_W4 / SLA_VERIFICATION_W4)
- ⛔ EKS destroy — Day1 Track A `terraform apply`
- ⛔ 하드닝 dev→main 머지 (owner) — staging/audit/TLS 선결
- ⛔ 서비스 단위 E2E 실행 환경 (서비스 스택 or staging)

> **한 줄 요약**: 월=EKS 올리고+하드닝 머지+E2E 환경, 화=전체 E2E+버그, 수=SLA+커버리지+문서, 목=staging 최종+모니터링, 금=발표 리허설(6/12). 발표 6/15.
