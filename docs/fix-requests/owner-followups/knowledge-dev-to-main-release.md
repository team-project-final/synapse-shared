## 배경 / 근거

knowledge-svc의 **main이 #40(W3 시점)에 정체**되어 있고, W4/W5 하드닝·기능 전부가 **dev에만 존재**한다. 즉 knowledge의 신원 패치(F9)·검색 정합·TLS·Flyway 표준 등이 origin/main(=배포 기준)에 반영되지 않았다.

- 실측(2026-06-10): `origin/main = 94b5f06`(#40) / `origin/dev = 3ff870a`(#66) → **dev가 18커밋 앞섬**.

## dev에만 있고 main에 없는 주요 항목 (origin/main..origin/dev)

| 커밋 | 내용 | 중요도 |
|---|---|---|
| #59 | **F9** — JWT subject(UUID)→결정적 Long 도출(검색 인증 패치) | 🔴 신원 정합 |
| #51 | Flyway 마이그레이션 버전 표준(closes #48) | 🟡 |
| #45 | MSK TLS security protocol 배선 | 🔴 EKS 배포 |
| #53/#54→#57 | KAFKA_ENABLED 게이트(#54가 #57로 **Revert**됨 — 최종 상태 확인 필요) | 🟡 게이트 |
| #58/#61 | 검색 튜닝·중복 semantic hit 보정·외부 ES 경로 정합 | 🟡 검색 정확도 |
| #43 | 노트 버전 이력/복원 + 태그 API(W3 Step6/7) | 🟡 기능 |
| #42 | RULE 컨벤션 위반 수정 | ⚪ |
| #62/#63/#65 | Step7 정확도 리포트·노트/그래프 E2E·Flyway 실검증 | ⚪ 테스트 |
| #64/#66 | 워크플로/HISTORY 동기화 | ⚪ 문서 |

## 영향

- **F9(신원) 패치가 main 부재** → platform JWT(UUID)로 knowledge 검색 인증이 배포본에서 실패 위험(W5 Day2엔 dev/로컬로만 검증됨, knowledge#59 ✅ dev).
- **MSK TLS(#45) main 부재** → EKS staging/prod 배포 시 Kafka TLS 연결 누락.
- **KAFKA_ENABLED 게이트 불확실**(#54 → #57 Revert) → gitops `KAFKA_ENABLED` env가 no-op일 가능성. 게이트 최종 적용 여부 확인 필요.
- knowledge의 W4/W5 성과 전반이 배포 정합에서 빠짐.

## 정확한 변경 지점 (owner 작업)

1. **dev→main 릴리스 PR**(레포 정책 squash) — dev 18커밋을 main으로 승격.
   - 사전: `git fetch` 후 `origin/dev`/`origin/main` 실측, 충돌·Revert 이력(#54/#57) 정리.
2. **KAFKA_ENABLED 게이트 최종화** — #57 Revert로 게이트가 빠졌는지 확인 후, 빠졌다면 재적용(Spring `@ConditionalOnProperty(synapse.kafka.enabled)` — 현재 dev `global/config/KafkaConfig.java`·`search/config/KafkaConfig.java`에 일부 존재). gitops `KAFKA_ENABLED` env와 정합.
3. 릴리스 후 `origin/main` 기준 빌드/테스트 + EKS 배포 검증(verify-argocd-deploy).

## 검증 (DoD)

- [ ] `git fetch` 후 `origin/main`에 #59(F9)·#45(TLS)·#51(Flyway)·#43·검색 튜닝 포함
- [ ] KAFKA_ENABLED 게이트 최종 적용 상태 확정(`@ConditionalOnProperty` 존재 + env 연동)
- [ ] knowledge main 빌드/테스트 green
- [ ] EKS dev/staging에서 knowledge 5/5 + TLS Kafka 연결 정상
- [ ] platform JWT(UUID)로 검색 인증 통과(F9 배포본 반영)

## 참조
- synapse-shared `docs/reports/W4_EXIT_GATE.md` §2 (하드닝 dev→main)
- synapse-shared `docs/project-management/HANDOFF_HUB.md` §2 (교차 의존 — knowledge dev 잔여)
- knowledge-svc #48(Flyway, dev #51로 닫힘 예정)·#59(F9)
- 머지 실측 주의: 반드시 `git fetch` 후 `origin/main` 기준 확인
