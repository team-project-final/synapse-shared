## 배경 / 근거

GitHub Actions의 **Node.js 20 런타임 액션이 deprecation**(2026-09-16 runner에서 제거 예정, runner 경고 출력). synapse-shared는 전 워크플로를 최신 메이저로 일괄 업그레이드 완료(**PR #56**, breaking 없음 검증). 동일 구버전 액션을 쓰는 **owner 레포 4종**도 업그레이드 필요 — 머지 정책상 owner 직접 작업이라 별도 이슈로 발행.

- 선례/템플릿: synapse-shared PR #56(checkout v4→v6, setup-java v4→v5, setup-node v4→v6, setup-python v5→v6, configure-aws-credentials v4→v6)
- 실측일: 2026-06-11(각 레포 `origin` `.github/workflows/` grep)

## 발행 이슈

| 이슈 | 레포 | 비고 |
|---|---|---|
| [engagement#40](https://github.com/team-project-final/synapse-engagement-svc/issues/40) | engagement-svc | + **amazon-ecr-login@v3 깨진 태그**(아래) |
| [knowledge#77](https://github.com/team-project-final/synapse-knowledge-svc/issues/77) | knowledge-svc | |
| [learning#82](https://github.com/team-project-final/synapse-learning-svc/issues/82) | learning-svc | + gradle/actions/setup-gradle |
| [platform#97](https://github.com/team-project-final/synapse-platform-svc/issues/97) | platform-svc | |

## 레포별 현황 (실측)

**engagement-svc**
- `ci-java.yml`: `actions/checkout@v4`(×2), `actions/setup-java@v4`(×2)
- `deploy.yml`: `actions/checkout@v4`, `aws-actions/configure-aws-credentials@v4`, **`aws-actions/amazon-ecr-login@v3`(미존재 태그)**
- `parse-workflow.yml`: `actions/checkout@v4`(×2), `actions/setup-node@v4`

**knowledge-svc**
- `ci-java.yml`: `actions/checkout@v4`(×2), `actions/setup-java@v4`(×2)
- `parse-workflow.yml`: `actions/checkout@v4`(×2), `actions/setup-node@v4`

**learning-svc**
- `ci.yml`: `actions/checkout@v4`(×4), `actions/setup-java@v4`(×2), `actions/setup-python@v5`(×2), `gradle/actions/setup-gradle@v4`(×2)
- `parse-workflow.yml`: `actions/checkout@v4`(×2), `actions/setup-node@v4`

**platform-svc**
- `ci-java.yml`: `actions/checkout@v4`(×2), `actions/setup-java@v4`(×2)
- `parse-workflow.yml`: `actions/checkout@v4`(×2), `actions/setup-node@v4`

## 권장 타깃 버전 (최신 메이저, Node 24)

| 액션 | 현재 | → 권장 |
|---|---|---|
| actions/checkout | v4 | **v6** |
| actions/setup-java | v4 | **v5** |
| actions/setup-node | v4 | **v6** |
| actions/setup-python | v5 | **v6** |
| aws-actions/configure-aws-credentials | v4 | **v6** |
| gradle/actions/setup-gradle | v4 | **v6** |
| aws-actions/amazon-ecr-login | v2(최신) / **engagement은 v3=미존재** | **v2**(최신 메이저, 경고 미해당) |

사용 중인 `with:` 파라미터(distribution/java-version/cache, node-version, python-version, role-to-assume/aws-region 등)는 모두 신규 메이저에서 지원 → **breaking 없음**(shared #56에서 ci-java·build-elasticsearch 라이브 검증).

## ⚠️ engagement deploy.yml — amazon-ecr-login@v3 깨진 태그 (별도 버그)

`aws-actions/amazon-ecr-login@v3`는 **존재하지 않는 태그**(GitHub API 404, 최신 메이저 v2). deploy 실행 시 `Unable to resolve action`으로 **ECR 로그인 스텝 해석 실패**. → engagement#40에서 **@v2로 교정** 포함.

## 검증 (DoD, 각 이슈 공통)

- [ ] (engagement) deploy.yml `amazon-ecr-login@v3` → `@v2` 교정
- [ ] 각 레포 워크플로 액션을 권장 최신 메이저로 업그레이드
- [ ] CI(및 deploy) 런에서 **Node 20 deprecation 경고 소멸**
- [ ] 기존 잡(빌드/테스트/배포) 정상 동작

## 참조
- synapse-shared PR #56(업그레이드 선례·검증)
- GitHub: [Deprecation of Node 20 on GitHub Actions runners](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/)
