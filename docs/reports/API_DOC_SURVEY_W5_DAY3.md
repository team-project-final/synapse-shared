# API 문서 Survey + gateway 라우팅 대조 — W5 Day3

> 생성: `scripts/api-doc-survey.ps1` 실측(2026-06-10) + gateway 라우트 대조 · FR-TL-304
> e2e 스택(origin/main, engagement는 D-004 Stage1 머지 후) 기준 · host 포트 platform 8081 / knowledge 8082 / engagement 8083 / learning-card 8084 / learning-ai 8090 / gateway 8080

## 0. 판정 기준

- **노출 O/X**: 서비스 **직접 포트**의 OpenAPI doc 엔드포인트(Spring `/v3/api-docs`, FastAPI `/openapi.json`)가 **200**이면 O, 아니면 X(보완 대상).
- **gateway 경유 Doc**: gateway(`localhost:8080`)는 `SecurityConfig`에서 `/api/**` 전 경로에 JWT 인증을 강제한다(`.pathMatchers("/api/**").authenticated()`). doc 경로는 public-path가 아니므로 **미인증 호출은 401이 정상**이다. 따라서 gateway 컬럼의 401은 "라우트는 존재하나 인증 게이트 통과 못함"을 의미하며, 노출 판정 근거로 쓰지 않는다.
- learning-ai는 gateway 라우트가 없어 gateway 경유 컬럼 **N/A(미라우팅)**.

## 1. OpenAPI 노출 실측

| 서비스 | 타입 | Doc 경로 | 직접 Doc | 직접 UI | gateway 경유 Doc | 노출 | 비고 |
|---|---|---|---|---|---|---|---|
| platform-svc | Spring | /v3/api-docs | **401** | 401 | 401 | **X** | doc·UI 모두 401 — 서비스 SecurityConfig가 doc 경로 permitAll 안 함 |
| knowledge-svc | Spring | /v3/api-docs | **500** | 200 | 401 | **X** | UI는 렌더되나 `/v3/api-docs`가 500(C500 envelope) — SpringDoc 문서 생성 실패 |
| engagement-svc | Spring | /v3/api-docs | 200 | 200 | 401 | **O** | D-004 Stage1 머지 후 정상 노출 (정상 기준 예시) |
| learning-card-svc | Spring | /v3/api-docs | **500** | 200 | 401 | **X** | UI는 렌더되나 `/v3/api-docs`가 500 — `NoSuchMethodError: io.swagger.v3.oas.annotations.Parameter.validationGroups()` (swagger-annotations/springdoc 버전 불일치) |
| learning-ai-svc | FastAPI | /openapi.json | 200 | 200 | N/A(미라우팅) | **O** | gateway 라우트 없음 (knowledge가 SEARCH_AI_BASE_URL로 내부 직접 호출) |

> 직접 UI(`/swagger-ui/index.html`): knowledge·learning-card는 UI 셸(200)은 뜨지만 UI가 내부적으로 fetch 하는 `/v3/api-docs`가 500이라 **실제 스펙은 렌더되지 않는다**. platform은 UI도 401이라 셸 자체가 뜨지 않는다.

## 2. gateway 라우팅 대조

gateway 라우트는 yml이 아니라 Java config(`synapse-gateway` `src/main/java/com/synapse/gateway/config/RoutesConfig.java`)에 정의됨. 모든 `/api/<svc>` 라우트는 `stripPrefix(2)` + Redis rate-limiter 필터를 적용하므로 `GET /api/engagement/v3/api-docs` → 백엔드에 `/v3/api-docs`로 포워딩된다.

| gateway route id | predicate(Path) | uri(env) | 대상 서비스 | doc 노출(직접) | gateway 경유 doc |
|---|---|---|---|---|---|
| platform-svc | /api/platform/** | `${PLATFORM_SVC_URI}` | platform-svc | X(401) | 401(인증 게이트) |
| engagement-svc | /api/engagement/** | `${ENGAGEMENT_SVC_URI}` | engagement-svc | O(200) | 401(인증 게이트) |
| knowledge-svc | /api/knowledge/** | `${KNOWLEDGE_SVC_URI}` | knowledge-svc | X(500) | 401(인증 게이트) |
| learning-svc | /api/learning/** | `${LEARNING_SVC_URI}` | learning-card-svc | X(500) | 401(인증 게이트) |
| frontend | /** (LOWEST_PRECEDENCE) | `${FRONTEND_SVC_URI}` | frontend(nginx) | — | — |
| (없음) | — | — | **learning-ai-svc** | O(200) | **N/A — 미라우팅** |

**주목 사항:**
1. **learning-ai 미라우팅**: gateway에 learning-ai 라우트가 없다. 외부 노출은 knowledge-svc가 `SEARCH_AI_BASE_URL`로 내부 호출하는 경로뿐. gateway 경유 OpenAPI 노출은 불가하며, 이는 의도된 설계(정책 결정: gateway 라우트 추가 여부는 별도 트랙).
2. **gateway 경유 doc은 전부 401**: doc 경로(`/api/*/v3/api-docs`)가 gateway public-path에 없어 미인증 시 401. 라우트 자체는 정상 동작(stripPrefix(2)로 백엔드 도달). 따라서 gateway 경유 OpenAPI 집계(예: SpringDoc `urls` groupedOpenApi)를 쓰려면 별도로 doc 경로 permitAll 또는 gateway 자체 aggregation을 검토해야 함 — **본 survey 범위 밖, 노출 판정에는 직접 포트만 사용**.
3. **라우트 정의 위치**: 플랜은 yml `spring.cloud.gateway.routes`를 가정했으나 실제로는 Java `RouteLocator`(`RoutesConfig.java`)에 있음. 대조는 Java config 기준으로 수행.

## 3. 누락 판정 → 발행 예정 이슈

직접 포트 doc이 200이 아닌 서비스 = 보완 대상. **3건**(platform-svc, knowledge-svc, learning-card-svc). engagement-svc·learning-ai-svc는 노출 O이므로 이슈 불요.

> 이슈 본문 드래프트는 작성 완료. **실제 `gh issue create` 발행은 코디네이터 리뷰 후 진행**(이 표의 발행 이슈 URL은 그때 채움).

| 서비스 | 레포(이슈 대상) | 누락 내용(증거) | 이슈 본문 드래프트 | 발행 이슈 URL |
|---|---|---|---|---|
| platform-svc | `team-project-final/synapse-platform-svc` | `/v3/api-docs`·`/swagger-ui/index.html` 모두 **401** — 서비스 SecurityConfig가 doc 경로 permitAll 안 함 | `docs/fix-requests/openapi/platform-svc.md` | TBD(코디네이터) |
| knowledge-svc | `team-project-final/synapse-knowledge-svc` | `/v3/api-docs` **500**(C500 envelope), UI 셸 200이나 스펙 미렌더 — SpringDoc 문서 생성 실패 | `docs/fix-requests/openapi/knowledge-svc.md` | TBD(코디네이터) |
| learning-card-svc | `team-project-final/synapse-learning-svc` (하위 `learning-card/`) | `/v3/api-docs` **500** — `NoSuchMethodError: Parameter.validationGroups()` (swagger-annotations/springdoc 버전 불일치) | `docs/fix-requests/openapi/learning-card-svc.md` | TBD(코디네이터) |

---

### 재현 방법

```powershell
pwsh -File scripts/api-doc-survey.ps1
```

→ `docs/reports/api-doc-survey.json` 갱신 + 위 §1 표 콘솔 출력. (e2e 스택이 기동된 상태에서 실행.)
