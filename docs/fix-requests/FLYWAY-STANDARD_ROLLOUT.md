# 수정 요청: Flyway 마이그레이션 버전 표준 적용

> 작성일: 2026-06-05 · 우선순위: platform-svc High(충돌 존재), 그 외 Medium
> 표준 문서: synapse-shared `docs/rules/12-flyway-migration.md`
> 모든 작업은 **전용 브랜치 → 커밋 → 푸쉬 → PR** 로 진행할 것.

## 공통 작업(4개 서비스 전부)

### 1) caller workflow 추가
`.github/workflows/flyway-guard.yml`:

```yaml
name: Flyway Guard
on:
  pull_request:
    branches: [main, dev]
  push:
    branches: [main, dev]
jobs:
  guard:
    uses: team-project-final/synapse-shared/.github/workflows/flyway-guard.yml@main
```

### 2) `src/main/resources/application.yml` 의 `spring.flyway` 표준화
`out-of-order: true` 추가, `baseline-on-migrate` 명시. 서비스별 목표 블록은 아래 각 섹션 참조.

---

## platform-svc (우선순위 High)

**(a) V28 중복 해소** — `src/main/resources/db/migration/` 에 동일 V28이 2개 존재:
- `V28__allow_multiple_refresh_tokens.sql` (이미 머지됨, 변경 금지)
- `V28__rename_oauth_provider_id_column.sql` (**untracked, 미머지**) → **타임스탬프로 rename**

```bash
cd src/main/resources/db/migration
git mv V28__rename_oauth_provider_id_column.sql "V$(date +%Y%m%d%H%M%S)__rename_oauth_provider_id_column.sql"
# 예: V20260605120000__rename_oauth_provider_id_column.sql
```

**(b) flyway 블록** (현재 `enabled: true` 만 있음) →

```yaml
  flyway:
    enabled: true
    out-of-order: true
    baseline-on-migrate: false
```

---

## knowledge-svc

현재 main `application.yml` 에 flyway 블록 없음(기본값 사용) → `spring:` 하위에 추가:

```yaml
  flyway:
    enabled: true
    out-of-order: true
    baseline-on-migrate: false
```

---

## learning-svc (learning-card)

기존 블록에 `out-of-order: true` 만 추가(나머지 유지):

```yaml
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true
    out-of-order: true
```

---

## engagement-svc

기존 멀티 location 유지하고 `out-of-order`·`baseline-on-migrate` 추가:

```yaml
  flyway:
    out-of-order: true
    baseline-on-migrate: false
    locations:
      - classpath:db/migration/community/group
      - classpath:db/migration/community/group/member
      - classpath:db/migration/community/report
      - classpath:db/migration/community/share
      - classpath:db/migration/gamification/xp
```

## 검증
PR 생성 시 `Flyway Guard` 체크가 green 이어야 머지 가능.
