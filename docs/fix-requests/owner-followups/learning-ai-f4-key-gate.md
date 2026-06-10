## 배경 / 근거

W4 성공기준 #5(AI 카드 자동생성 E2E)와 W5 P6 SLA(AI 카드 <30s)·P3 시맨틱 검색이 **learning-ai의 AI 키 처리 부재**로 차단된다(버그 **F4**). 키가 없으면 graceful 비활성화 없이 빈 키로 클라이언트를 만들어 호출 시점에 실패한다.

- 출처: synapse-shared `docs/reports/E2E_W5_DAY2.md` (F4) · `docker-compose.e2e.yml` 주석("빈 키면 OpenAI/Anthropic 클라이언트 생성이 기동 단계에서 실패 — 게이트 없음")
- 연관 E2E 이슈: learning-svc #51 ([W5 E2E] note→AI카드 자동생성) — 본 건이 직접 차단

## 현재 상태 (실측 2026-06-10, learning-ai)

빈 키를 그대로 통과시킨다:
- `learning-ai/app/api/deps.py:25` → `ClaudeService(api_key=settings.anthropic_api_key or "")`
- `learning-ai/app/api/deps.py:30` → `OpenAIEmbeddingService(api_key=settings.openai_api_key or "")`
- `learning-ai/app/main.py:34-35` → 동일하게 `or ""`
- `learning-ai/app/core/config.py:12-13` → `anthropic_api_key: str | None = None`, `openai_api_key: str | None = None`

즉 키 미설정 시 **빈 문자열로 클라이언트를 생성** → 기동은 되지만 AI 호출(카드 생성/임베딩) 시 인증 실패. **graceful 게이트도, 명확한 사전 차단도 없음**. E2E/staging에서 실 키 주입 절차도 미문서화.

## 정확한 변경 지점 (제안)

1. **Graceful 게이트** — 키 미설정 감지 시:
   - 기동은 정상 유지(헬스체크 통과)하되, AI 의존 엔드포인트(카드 생성·시맨틱 검색)는 **명확한 503/'AI disabled: API key not configured'** 반환(현재처럼 빈 키로 호출해 모호한 인증 에러를 던지지 않음).
   - `app/core/config.py`에 `ai_enabled` 파생 플래그(키 존재 여부) + `deps.py`/`main.py`에서 분기.
2. **키 provisioning 문서/배선** — 실 키 주입 경로 명시:
   - 로컬/E2E: `.env` 또는 셸 `ANTHROPIC_API_KEY`/`OPENAI_API_KEY`(compose가 `LEARNING_AI_*`로 매핑).
   - EKS staging/prod: ExternalSecret/SecretsManager 키 시드 → 배포 가이드에 추가.
3. **관측성** — 기동 시 키 유무 1회 로깅(WARN if disabled), AI 비활성 메트릭.

## 검증 (DoD)

- [ ] 키 미설정 시 서비스 기동 정상 + AI 엔드포인트가 **명확한 비활성 응답**(크래시/모호한 인증 에러 X)
- [ ] 키 설정 시 note→AI카드 자동생성 E2E PASS(learning-svc #51)
- [ ] P6 SLA(AI 카드 <30s) 측정 가능
- [ ] (해당 시) P3 시맨틱 검색 leg 통과
- [ ] 실 키 주입 절차가 배포 가이드에 문서화

## 참조
- synapse-shared `docs/reports/E2E_W5_DAY2.md` (F4)
- learning-svc #51 (W5 AI 카드 E2E)
- synapse-shared `docker-compose.e2e.yml` (learning-ai-svc 환경 주석)
- synapse-shared `docs/project-management/HANDOFF_W5_DAY3.md` §0 (이월: P6 SLA·F4 선결)
