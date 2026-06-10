# 커버리지 baseline — W5 Day3 (2026-06-10)

> team-lead 종합 집계(FR-ALL-303). **owner 무관 측정 가능분만**. 80% "달성"은 전 서비스 jacoco 설정 + 테스트 보강이 필요(owner) — 본 문서는 현황 스냅샷.

## 측정 결과

| 서비스 | 커버리지 도구 | LINE | INSTRUCTION | BRANCH | 판정(line 80%) |
|---|---|---|---|---|---|
| **platform-svc** | JaCoCo ✅ | **92.4%** (1847/2000) | 91.1% (7367/8088) | 69.6% (238/342) | ✅ 충족 |
| engagement-svc | ❌ jacoco 미설정 | — | — | — | 측정 불가(owner) |
| knowledge-svc | ❌ jacoco 미설정 | — | — | — | 측정 불가(owner) |
| learning-card | ❌ jacoco 미설정 | — | — | — | 측정 불가(owner) |
| learning-ai | pytest-cov 미확인 | — | — | — | 별도 확인(owner) |

- platform: `./gradlew test jacocoTestReport` → `build/reports/jacoco/test/jacocoTestReport.xml` 집계(METHOD 91.0%·CLASS 96.2%).

## 측정 메모

- **platform 로컬 stray 마이그레이션**: 측정 중 platform 로컬 작업트리에 **untracked** `V28__rename_oauth_provider_id_column.sql`가 있어 origin/main의 `V28__allow_multiple_refresh_tokens.sql`와 Flyway 버전 충돌(`Found more than one migration with version 28`) → DB 테스트 전부 실패. **origin/main엔 V28 하나뿐(정상)** — 로컬 WIP 잔재. 측정 시 임시 비켜두고 main 기준 측정 후 **복원함**. (owner가 해당 WIP를 V29로 재번호하거나 정리 필요할 수 있음 — 로컬 상태이므로 이슈화 X, 참고만.)

## 결론 / 이월

- **platform-svc는 이미 line 92% (>80%)** — 충족.
- engagement·knowledge·learning은 **jacoco 미설정(실측 0곳)** → 각 owner 빌드에 jacoco 플러그인 + 리포트 태스크 추가 후라야 집계 가능. **FR-ALL-303 "전 서비스 80%"는 owner 작업 이월**.
- BRANCH 커버리지(platform 69.6%)는 분기 테스트 보강 여지 — 참고.
