## 배경 / 근거

W5 FR-TL-304 API 문서 최신화. synapse-shared의 OpenAPI survey(2026-06-10, `scripts/api-doc-survey.ps1`)에서
knowledge-svc의 OpenAPI doc **생성 실패(500)**를 확인. Swagger UI 셸은 200으로 뜨지만, UI가 내부적으로 fetch 하는
`/v3/api-docs`가 **500**을 반환하므로 실제 API 스펙은 렌더되지 않는다. SpringDoc은 클래스패스에 존재하나 문서
**생성 단계에서 예외**가 발생한다(서비스 자체 글로벌 예외 핸들러 envelope `C500`이 반환됨 → 라우팅 404가 아니라
컨트롤러 도달 후 생성 실패).

- 증거(직접): `GET http://localhost:8082/v3/api-docs` → **500**
  ```json
  {"code":"C500","message":"Internal server error occurred","timestamp":"2026-06-10T03:53:59..."}
  ```
- 증거(UI): `GET http://localhost:8082/swagger-ui/index.html` → 200 (셸만, 스펙 미렌더)
- gateway 경유: `GET http://localhost:8080/api/knowledge/v3/api-docs` → 401 (gateway `/api/**` JWT 인증 — 별도 사안)
- 대조표: synapse-shared `docs/reports/API_DOC_SURVEY_W5_DAY3.md`
- 참고: 동일 Spring Boot 기반 learning-card-svc도 같은 `/v3/api-docs` 500을 보이며, 그쪽 컨테이너 로그에서는
  `java.lang.NoSuchMethodError: io.swagger.v3.oas.annotations.Parameter.validationGroups()` (swagger-annotations/springdoc
  **버전 불일치**)가 root cause로 확인됨. knowledge-svc도 **동일 원인일 가능성이 높음** — 빌드 의존성 트리에서 swagger-core/
  swagger-annotations 버전을 우선 점검할 것. (knowledge-svc 컨테이너 stdout에는 해당 스택이 캡처되지 않아 단정하지 않음.)

## 현재 상태

- [x] `/v3/api-docs` 200 미응답 → **500**(C500 envelope)
- [x] Swagger UI 셸 200이나 스펙 fetch 실패로 미렌더
- [ ] SpringDoc 문서 생성 시 예외 발생(스택트레이스 확보 필요 — 로깅 레벨/로거 조정 후 1회 재현)
- [ ] swagger-annotations / springdoc 버전 정합성 미확인

## 정확한 변경 지점

1. **의존성 버전 정합 (유력 원인)**: `build.gradle(.kts)` 의존성 트리에서 `io.swagger.core.v3:swagger-annotations`(및 `swagger-core`)와
   `org.springdoc:springdoc-openapi-starter-webmvc-ui` 버전을 확인.
   - 정상 노출 중인 **engagement-svc의 springdoc/swagger 버전과 일치**시킬 것(Spring Boot 3.x ↔ springdoc 2.6.x ↔ swagger-core 2.2.x 라인 정합).
   - 다른 라이브러리가 구버전 `swagger-annotations`를 끌어와 `Parameter.validationGroups()` 메서드 부재를 유발할 수 있음 → `./gradlew :knowledge-svc:dependencies --configuration runtimeClasspath`로 충돌 확인 후 강제 버전/제외 처리.
2. **스택트레이스 확보**: `application.yml`에 일시적으로
   ```yaml
   logging.level.org.springdoc: DEBUG
   ```
   추가 후 `/v3/api-docs` 1회 호출 → 정확한 예외 라인 확인.
3. (필요 시) 문제 컨트롤러/DTO의 swagger 어노테이션·`Pageable`/`Sort` 파라미터 표기 점검(SpringDoc converter 단계에서 흔히 실패).
4. SecurityConfig에서 `/v3/api-docs/**`, `/swagger-ui/**` permitAll 유지 확인(현재 UI 셸 200이므로 보안은 통과 중).

## 검증 (DoD)

- [ ] `curl -s -o /dev/null -w "%{http_code}" http://localhost:8082/v3/api-docs` → `200`
- [ ] 응답 JSON에 `openapi`/`paths`/`components` 정상 포함(C500 envelope 아님)
- [ ] `http://localhost:8082/swagger-ui/index.html`에서 실제 엔드포인트 목록 렌더
- [ ] 정상 노출 중인 engagement-svc와 동일한 응답 구조

## 참조

- 대조표: synapse-shared `docs/reports/API_DOC_SURVEY_W5_DAY3.md`
- survey 스크립트: synapse-shared `scripts/api-doc-survey.ps1`
- 세션 스펙: synapse-shared `docs/superpowers/specs/2026-06-10-w5-day3-d004stage1-schema-apidocs-design.md`
- 동일 증상 참고: learning-card-svc fix-request(`docs/fix-requests/openapi/learning-card-svc.md`) — NoSuchMethodError root cause
- 정상 예시: engagement-svc(`:8083/v3/api-docs` 200)
