## 배경 / 근거

W5 FR-TL-304 API 문서 최신화. synapse-shared의 OpenAPI survey(2026-06-10, `scripts/api-doc-survey.ps1`)에서
platform-svc의 SpringDoc **미노출**을 확인. doc 경로와 Swagger UI 경로가 **모두 401**이다 — 즉 SpringDoc 의존성
유무와 무관하게, 서비스 보안 설정이 OpenAPI doc 경로를 미인증 접근 허용(permitAll)하지 않아 문서가 외부로 노출되지 않는다.

- 증거(직접): `GET http://localhost:8081/v3/api-docs` → **401** (기대 200)
- 증거(UI): `GET http://localhost:8081/swagger-ui/index.html` → **401**
- gateway 경유: `GET http://localhost:8080/api/platform/v3/api-docs` → 401 (gateway는 `/api/**` 전체 JWT 인증 강제 — gateway 측 별도 사안)
- 대조표: synapse-shared `docs/reports/API_DOC_SURVEY_W5_DAY3.md`
- 정상 예시: engagement-svc(`:8083/v3/api-docs` → 200), learning-ai(`:8090/openapi.json` → 200)

## 현재 상태

- [x] `/v3/api-docs` 200 미응답 → **401**
- [x] Swagger UI(`/swagger-ui/index.html`) 미렌더 → **401**(셸 자체 미응답)
- [ ] `springdoc-openapi-starter-webmvc-ui` 의존성 존재 여부 확인 필요(401이 보안 게이트인지 dep 부재인지 코드에서 1차 확정)
- [ ] SecurityConfig에서 doc 경로 permitAll 누락(유력 원인 — 401 응답이 인증 게이트에서 나옴)

## 정확한 변경 지점

1. **SecurityConfig 확인/수정 (유력 원인)**: HTTP Security 체인에서 doc·UI 경로를 `permitAll` 처리.
   - 허용 경로: `/v3/api-docs/**`, `/swagger-ui/**`, `/swagger-ui.html`
   - WebMVC + Spring Security 6 예:
     ```java
     .authorizeHttpRequests(auth -> auth
         .requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()
         // ... 기존 규칙
         .anyRequest().authenticated())
     ```
   - (gateway 뒤에서만 동작한다면 운영 환경 노출 정책은 별도 결정. 최소한 직접 포트에서 doc 노출되어야 survey/문서화가 가능.)
2. **의존성 확인**: `build.gradle(.kts)`에 `implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:<ver>")` 존재 여부 확인. 부재 시 정상 노출 중인 타 서비스(engagement-svc)와 **동일 버전**으로 추가.
3. (선택) `application.yml` 경로 명시:
   ```yaml
   springdoc:
     api-docs.path: /v3/api-docs
     swagger-ui.path: /swagger-ui/index.html
   ```
4. 주요 REST 컨트롤러에 `@Tag`/`@Operation` 최소 1개 도메인부터 부여(인증/사용자 등).

## 검증 (DoD)

- [ ] `curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/v3/api-docs` → `200`
- [ ] `http://localhost:8081/swagger-ui/index.html` 브라우저 렌더 + 주요 엔드포인트 노출
- [ ] 정상 노출 중인 engagement-svc와 동일한 응답 구조(`openapi`, `paths`, `components` 포함)
- [ ] (정책 결정 시) gateway 경유 doc 노출이 필요하면 gateway public-path 추가는 synapse-gateway 별도 이슈로 분리

## 참조

- 대조표: synapse-shared `docs/reports/API_DOC_SURVEY_W5_DAY3.md`
- survey 스크립트: synapse-shared `scripts/api-doc-survey.ps1`
- 세션 스펙: synapse-shared `docs/superpowers/specs/2026-06-10-w5-day3-d004stage1-schema-apidocs-design.md`
- 정상 예시: engagement-svc(`:8083/v3/api-docs` 200)
