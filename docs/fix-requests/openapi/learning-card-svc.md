## 배경 / 근거

> 레포: `team-project-final/synapse-learning-svc` 하위 **`learning-card/`** 모듈. 이슈 제목에 `[learning-card]` 명시.

W5 FR-TL-304 API 문서 최신화. synapse-shared의 OpenAPI survey(2026-06-10, `scripts/api-doc-survey.ps1`)에서
learning-card-svc의 OpenAPI doc **생성 실패(500)**를 확인. Swagger UI 셸은 200으로 뜨지만 UI가 fetch 하는
`/v3/api-docs`가 **500**이라 실제 스펙이 렌더되지 않는다. 컨테이너 로그에서 **root cause를 확정**했다:

```
Caused by: java.lang.NoSuchMethodError:
  'java.lang.Class[] io.swagger.v3.oas.annotations.Parameter.validationGroups()'
    at org.springdoc.core.converters.ResponseSupportConverter.resolve(ResponseSupportConverter.java:87)
    ...
    at org.springdoc.webmvc.api.OpenApiResource.openapiJson(OpenApiResource.java:127)
```

즉 클래스패스의 **`swagger-annotations` 버전이 SpringDoc이 기대하는 버전보다 낮아** `Parameter.validationGroups()`
메서드가 존재하지 않는다. 전형적인 **swagger-core / springdoc 버전 불일치(dependency conflict)**.

- 증거(직접): `GET http://localhost:8084/v3/api-docs` → **500**
  ```json
  {"error":{"code":"INTERNAL_ERROR","message":"서버 내부 오류"}}
  ```
- 증거(UI): `GET http://localhost:8084/swagger-ui/index.html` → 200 (셸만, 스펙 미렌더)
- 증거(로그): `docker logs synapse-learning-card-svc` → 위 `NoSuchMethodError` 스택
- gateway 경유: `GET http://localhost:8080/api/learning/v3/api-docs` → 401 (gateway `/api/**` JWT 인증 — 별도 사안)
- 대조표: synapse-shared `docs/reports/API_DOC_SURVEY_W5_DAY3.md`

## 현재 상태

- [x] `/v3/api-docs` 200 미응답 → **500**(INTERNAL_ERROR envelope)
- [x] Swagger UI 셸 200이나 스펙 fetch 실패로 미렌더
- [x] root cause: `NoSuchMethodError: io.swagger.v3.oas.annotations.Parameter.validationGroups()` (swagger-annotations 구버전)
- [ ] swagger-core/swagger-annotations ↔ springdoc 버전 정합 미적용

## 정확한 변경 지점

1. **버전 정합 (확정 원인)**: `learning-card/build.gradle(.kts)`에서 swagger·springdoc 버전을 일치시킨다.
   - `org.springdoc:springdoc-openapi-starter-webmvc-ui`가 요구하는 `io.swagger.core.v3:swagger-annotations`(및 `swagger-core`, `swagger-models`) 버전(보통 2.2.x — `validationGroups()` 포함)을 강제.
   - 충돌 추적: `./gradlew :learning-card:dependencies --configuration runtimeClasspath | grep -i swagger`
     → 어떤 의존성이 구버전 `swagger-annotations`를 끌어오는지 확인 후 `resolutionStrategy.force(...)` 또는 transitively `exclude` 처리.
   - 권장: **정상 노출 중인 engagement-svc와 동일한 springdoc 라인(Spring Boot 3.x ↔ springdoc 2.6.x)**으로 정렬.
2. 빌드 후 `/v3/api-docs` 200 확인. 여전히 다른 converter에서 실패하면 `logging.level.org.springdoc: DEBUG`로 다음 예외 라인 확인.
3. SecurityConfig의 `/v3/api-docs/**`, `/swagger-ui/**` permitAll 유지 확인(현재 UI 셸 200으로 보안은 통과 중).

## 검증 (DoD)

- [ ] `curl -s -o /dev/null -w "%{http_code}" http://localhost:8084/v3/api-docs` → `200`
- [ ] 응답 JSON에 `openapi`/`paths`/`components` 정상 포함(error envelope 아님)
- [ ] `docker logs synapse-learning-card-svc`에 `NoSuchMethodError ... validationGroups` 재발 없음
- [ ] `http://localhost:8084/swagger-ui/index.html`에서 실제 엔드포인트 목록 렌더
- [ ] 정상 노출 중인 engagement-svc와 동일한 응답 구조

## 참조

- 대조표: synapse-shared `docs/reports/API_DOC_SURVEY_W5_DAY3.md`
- survey 스크립트: synapse-shared `scripts/api-doc-survey.ps1`
- 세션 스펙: synapse-shared `docs/superpowers/specs/2026-06-10-w5-day3-d004stage1-schema-apidocs-design.md`
- 정상 예시: engagement-svc(`:8083/v3/api-docs` 200)
