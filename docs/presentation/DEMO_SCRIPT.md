# SYNAPSE 시연 스크립트 (5분) + 녹화 체크리스트

> 용도: ① 제출용 시연 영상(5~10분·100MB↓·음성 소개 포함) 녹화 ② 06-15 발표 데모(영상 재생)
>
> ⚠️ **갱신 2026-06-12 저녁 — 녹화 환경 변경**: EKS 클러스터는 24h 사인오프 후 destroy 완료. **녹화는 팀원이 로컬 E2E 환경에서 별도 진행.**
> - 환경 기동: `synapse-shared` main 최신 pull → `docker-compose.yml` + `docker-compose.e2e.yml` (origin/main worktree 실빌드) — 절차는 [E2E_SMOKE_W5_DAY1 §1](../reports/E2E_SMOKE_W5_DAY1.md) 참조. 13/13 healthy 후 시작
> - knowledge Kafka는 #66/#67로 기본 활성 — 전 체인(노트→AI카드→복습→검색) 동작
> - **AI 카드 구간(③)**: 실 키를 셸 환경변수(`OPENAI_API_KEY` 또는 `ANTHROPIC_API_KEY`)로만 주입 — 파일·커밋 금지
> - **단일 환경이라 gitops#199(컨슈머 그룹 충돌) 영향 없음** — 아래 §0-A의 클러스터 시퀀스는 폐기, §0 체크리스트 중 인프라 항목은 docker 항목으로 갈음
> - 접속: frontend Flutter web(dev 빌드)이 `localhost:8080`(gateway)·`8084`(learning-card)·`8090`(learning-ai)을 호출 — compose가 동일 포트로 노출하므로 추가 설정 불요. 가입 경로: `POST http://localhost:8080/api/platform/api/v1/auth/signup` (gateway 프리픽스 = `/api/{service}/api/v1/...`)

---

## 0-A. 사전점검 실측 결과 (2026-06-12 오전, team-lead)

| 항목 | 결과 |
|---|---|
| 클러스터 | ArgoCD 16/16 Synced/Healthy, staging 재시작 0 ✅ |
| frontend | **staging·dev 모두 배포됨**(nginx 정적 서빙). 단 빌드가 `dev-latest` = API base `http://localhost:8080` → **gateway port-forward 8080 필수** (+ learning-card 8084, learning-ai 8090) |
| gateway | **dev 네임스페이스에만 존재** → 데모는 dev 환경으로 진행. 경로 프리픽스 `/api/platform|knowledge|engagement|learning/**`, 가입·로그인 검증 완료(201/JWT) |
| AI 키 (P6) | dev·staging 모두 `sk-dev-test-...` 더미 + ANTHROPIC 키 없음(MODEL_NAME=gpt-4o-mini) → **클러스터 내 AI 카드 실생성 불가**. ③ 구간은 실키 확보(ESO/Secrets Manager 주입) 또는 로컬 E2E 컷 폴백 |
| 노트→이벤트 | 노트 생성 → outbox → `note-created-v1` 발행 검증 완료 ✅ |
| ⚠️ **검색 색인** | 파이프라인 자체는 gitops PR #200으로 복구(토픽 정본·Redis idempotency·SEARCH_AI_BASE_URL — 인증 검색 200 E2E 완주, P3 0.105~0.183s). 잔존 리스크는 **[gitops#199](https://github.com/team-project-final/synapse-gitops/issues/199)** — dev/staging 동일 MSK·동일 컨슈머 그룹 → dev 이벤트 ~2/3이 staging행. **녹화는 24h 사인오프(17:15) 후, 해당 staging Application auto-sync 일시중지 → 컨슈머 scale 0 순서로 조치한 뒤** 진행(selfHeal이 scale-down을 원복시키므로 순서 중요) |
| 시드 계정 | `demo-w5-recording2@synapse.app` 가입 완료, 노트 1건(스프링 트랜잭션) 생성 |
| Grafana | monitoring 네임스페이스 `kube-prometheus-stack-grafana` port-forward로 접근 |

**확정 녹화 시퀀스**: ① 17:15 24h 사인오프 → ② staging 앱 auto-sync 일시중지 + 컨슈머 scale 0 → ③ dev 풀체인 녹화(아래 §1) → ④ 클러스터 destroy

## 0. 녹화 전 점검 체크리스트 (Go/No-Go)

### 인프라
- [ ] SSM 터널 수립 (`aws ssm start-session` — HANDOFF_W5_DAY4_CLOSEOUT §6 명령) — 유휴 끊김 주의, 녹화 직전 재수립
- [ ] ArgoCD staging 7/7 Healthy 확인, 파드 재시작 0
- [ ] port-forward: `kubectl -n synapse-staging port-forward svc/gateway 8080:8080` (+ Grafana 3000)

### 기능 Go/No-Go
- [ ] **시드 계정**: 데모용 신규 가입 이메일 준비 (가입 트리거: `POST /api/v1/auth/signup`) + 사전 작성 노트 5~6개 시드 (그래프·검색이 비어 보이지 않게)
- [ ] **frontend 접근**: staging에 frontend 미배포 시 → 로컬 `flutter run -d chrome` + API base를 port-forward gateway로 지정
- [ ] **③ AI 카드 (P6 리스크)**: staging learning-ai에 실 `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` 주입 여부 확인
  - **불가 시 폴백**: ③ 구간을 로컬 E2E(compose, 실키 주입 — #66/#67로 knowledge KAFKA_ENABLED 활성화됨) 녹화 컷으로 대체, 음성으로 환경 차이 고지
- [ ] **⑤ 검색**: staging ES `notes-v1` 색인 동작 확인 (시드 노트로 사전 쿼리 1회)
- [ ] **⑥ Grafana**: 대시보드 2종 로드 + 데모 테넌트 트래픽이 보이는지

### 녹화 품질
- [ ] 해상도 1080p 이하·30fps (100MB 제한 — 5분 기준 비트레이트 ~2.5Mbps 이하 또는 후처리 압축)
- [ ] 마이크 테스트 — 기능별 음성 소개 필수 (양식 요구사항)
- [ ] 브라우저 시크릿 창·북마크바 숨김·알림 OFF, 터미널 폰트 확대

---

## 1. 시연 흐름 (5:00) — "학습 순환 한 바퀴"

> 내레이션 원칙: 각 구간에서 ⓐ 사용자가 보는 것 ⓑ 뒤에서 일어나는 이벤트를 한 문장씩.

### ① 가입·로그인 — 0:00~0:40
- 신규 이메일로 가입 → 로그인 → 대시보드.
- 내레이션: "가입 순간 `user-registered` 이벤트가 발행되고, engagement 서비스가 이를 소비해 게이미피케이션 프로필을 자동 생성합니다. 서비스끼리 직접 호출하지 않습니다."

### ② 노트 작성 + 그래프 — 0:40~1:30
- 새 노트 작성: 제목 "스프링 트랜잭션", 본문에 `[[격리 수준]]` `[[전파 속성]]` 위키링크 포함 저장.
- 그래프 뷰 열기 — 시드 노트들과의 백링크 연결, 중요 노트(PageRank) 강조 확인.
- 내레이션: "위키링크는 자동으로 관계 그래프가 되고, 노트 본문은 백그라운드에서 512토큰 청크로 잘려 1536차원 임베딩으로 저장됩니다."

### ③ AI 카드 자동 생성 — 1:30~2:20
- 방금 노트의 덱으로 이동 → `AI_GENERATED` 카드 3~10장 생성 확인, 앞/뒤 내용 1장 낭독.
- 내레이션: "`note-created` 이벤트를 learning-ai가 소비해 Claude가 카드를 만들었습니다. 사람은 카드를 만들지 않습니다."
- ⚠️ 생성 지연 대비: ②에서 저장 후 ③ 진입까지 그래프 설명으로 시간 버퍼(30s+) 확보. 미생성 시 시드 노트의 기생성 카드로 전환.

### ④ 복습 + 게이미피케이션 — 2:20~3:20
- 복습 세션 시작 → 카드 2~3장을 AGAIN/GOOD/EASY로 평가 → 다음 복습일이 달라지는 것 표시.
- 완료 → XP +10 적립, (가능하면) 레벨업·배지 알림 수신 화면.
- 내레이션: "Anki식 SM-2 변형이 카드마다 난이도 계수를 갱신합니다. `review-completed` 이벤트로 XP가 쌓이고, 레벨업은 다시 알림으로 돌아옵니다 — 전부 비동기입니다."

### ⑤ 하이브리드 검색 — 3:20~4:00
- 동일 질의를 키워드/시맨틱/하이브리드로 전환 검색 — 예: "DB 동시성 문제" (시드 노트는 '트랜잭션 격리 수준'으로 작성해 의미 검색 우위를 연출).
- 내레이션: "키워드 BM25와 임베딩 코사인 랭킹을 RRF로 융합합니다. 시맨틱이 죽어도 키워드로 폴백해 검색은 항상 동작합니다."

### ⑥ 운영 화면 — 4:00~4:40
- Grafana 대시보드: 방금 데모로 발생한 요청·이벤트 메트릭 / audit 로그에서 가입~복습 기록 조회.
- 내레이션: "지금 시연한 모든 행위가 Kafka를 거쳐 감사 로그에 남고, Prometheus·Grafana로 관측됩니다. 이 환경은 EKS 위에서 ArgoCD GitOps로 운영 중입니다."

### 마무리 — 4:40~5:00
- "노트가 카드가 되고, 복습이 노트를 다시 살리는 순환을 보셨습니다."

---

## 2. 트러블 대응 (라이브였다면 / 녹화 중)

| 증상 | 대응 |
|---|---|
| SSM 터널 끊김 | 터널 재수립 30초 — 녹화는 구간별로 끊어 찍고 편집 합본 |
| AI 카드 미생성 | 시드 카드로 전환 or 로컬 E2E 컷 삽입 (음성 고지) |
| 검색 0건 | 시드 노트 사전 색인 확인 실패 시 키워드 검색만 시연 |
| 레벨업 미발생 | XP 적립 화면까지만 — 레벨업은 슬라이드 수치로 갈음 |

## 3. 산출물
- [ ] 원본 녹화본 → 편집(구간 합본·자막 선택) → **100MB 이하 인코딩** → 파일명 `시연영상_SYNAPSE.mp4`
- [ ] 발표장 재생 테스트 (로컬 플레이어, 인터넷 불요)
