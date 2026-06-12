---
marp: true
paginate: true
size: 16:9
style: |
  @import url('https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.min.css');
  :root {
    --ink: #2d2418;
    --paper: #faf6ef;
    --accent: #b5562a;
    --accent-soft: #e8d9c3;
    --muted: #7a6a55;
  }
  section {
    font-family: 'Pretendard', 'Malgun Gothic', sans-serif;
    background: var(--paper);
    color: var(--ink);
    font-size: 21px;
    padding: 48px 64px;
    line-height: 1.45;
  }
  h1 { font-size: 1.5em; color: var(--ink); }
  h2 { font-size: 1.15em; color: var(--accent); margin-top: 0; }
  h6 { color: var(--muted); font-weight: 600; letter-spacing: .12em; margin-bottom: 2px; }
  strong { color: var(--accent); }
  table { font-size: .82em; border-collapse: collapse; }
  th { background: var(--accent-soft); color: var(--ink); }
  th, td { border: 1px solid #d8cbb6; padding: 5px 10px; }
  blockquote { border-left: 4px solid var(--accent); color: var(--muted); padding-left: 14px; }
  section.lead { display: flex; flex-direction: column; justify-content: center; text-align: center; }
  section.lead h1 { font-size: 2.1em; }
  section.divider { display: flex; flex-direction: column; justify-content: center; background: var(--ink); color: var(--paper); }
  section.divider h1 { color: var(--paper); font-size: 1.9em; }
  section.divider p { color: var(--accent-soft); }
  .cols { display: flex; gap: 28px; }
  .cols > div { flex: 1; }
  .box { background: #fff; border: 1.5px solid var(--accent-soft); border-radius: 10px; padding: 8px 12px; text-align: center; }
  .arrow { color: var(--accent); font-weight: 700; align-self: center; }
  .small { font-size: .8em; color: var(--muted); }
  section.compact { font-size: 18px; padding: 36px 56px; }
  section.compact table { font-size: .85em; }
footer: 'SYNAPSE — K-Digital Training 팀별 프로젝트 결과보고서'
---

<!-- _class: lead -->
<!-- _footer: '' -->

###### K-DIGITAL TRAINING · {{훈련기관명}}

# SYNAPSE
## 노트가 카드가 되는 AI 통합 학습 플랫폼 (PKM + SRS + AI)

**TEAM SYNAPSE** (7인)
김민구(팀장) · 김해준 · 한승완 · 김현지 · 박은서 · 김나경 · 조유지

<span class="small">멘토: {{멘토명}} | 개발 기간: 2026-05-12 ~ 06-15 (5주) | 발표: 2026-06-15</span>

---

# 목 차

1. **프로젝트 개요** — 주제·배경·기획의도 / 차별화 / 내용·구조 / 개발환경 / 활용방안
2. **프로젝트 팀 구성 및 역할**
3. **프로젝트 수행 절차 및 방법**
4. **프로젝트 수행 경과** — 데이터·전처리 → 모델 → 평가·개선 → 운영 증명 → 시연
5. **자체 평가 의견**

---

###### 01. 프로젝트 개요

# 주제 · 선정 배경 · 기획 의도

> **SYNAPSE** — PKM(개인 지식 관리)과 SRS(간격 반복 학습)를 **하나의 워크플로우로 통합**하고, 그 사이를 **AI(LLM)** 가 자동으로 연결하는 멀티테넌트 학습 SaaS. 포지셔닝: **"Obsidian + Anki + RAG 융합"**

**해결하려는 문제 — 기존 도구의 단절**

| # | 문제 | 원인 |
|---|---|---|
| 1 | 워크플로우 단절 | PKM(Obsidian·Notion)과 SRS(Anki)가 분리 — 노트를 카드로 **수동 복사** |
| 2 | 맥락 상실 | 복습 카드가 원본 노트와 연결되지 않음 |
| 3 | 카드 제작 노동 | 손으로 만드는 카드가 학습 의욕을 저하 |
| 4 | 관계 시각화 부재 | 노트 간 연결을 한눈에 볼 수 없음 |
| 5 | 검색 한계 | 키워드 매칭만 가능, 의미 기반 검색 없음 |

**기획 의도(목표)**: G1 통합 워크플로우 · G2 AI 카드 자동 생성 · G3 지식 그래프 · G4 하이브리드 시맨틱 검색 · G5 크로스플랫폼(Flutter) · G6 Freemium SaaS 수익화

---

###### 01. 프로젝트 개요

# 차별화 포인트

<div class="cols">
<div>

**제품 — "통합과 자동화"**

- **PKM+SRS 단일 플랫폼**: 카드가 항상 원본 노트에 링크 → 맥락 유지
- **AI 카드 자동 생성**: LLM이 노트를 분석해 플래시카드 자동 생성 → 제작 노동 제거
- **위키링크 지식 그래프**: `[[링크]]` 자동 감지, 백링크·PageRank 중요도, 2D 시각화
- **하이브리드 검색**: BM25(키워드) × 임베딩(의미)을 **RRF**로 융합

</div>
<div>

**아키텍처 — "현업형 MSA 정공법" (ADR 3건)**

| ADR | 결정 | 근거 |
|---|---|---|
| 0001 | **MSA** 채택 | 4개 도메인 자연 분리, 경계를 네트워크·배포로 강제 |
| 0002 | **Kafka+Avro+Outbox** | 가용성 결합 제거, BACKWARD 호환 강제, 이벤트 재생 |
| 0003 | **단일 PG + 스키마 격리** | 7인 팀 현실 비용 + 계정 권한 분리, 크로스 스키마 금지 |

토이 프로젝트가 아닌 **의사결정 기록(ADR)을 남기는 아키텍처 학습**

</div>
</div>

---

<!-- _class: compact -->

###### 01. 프로젝트 개요

# 프로젝트 구조 — 시스템 구성도

<div class="cols" style="font-size:.85em">
<div style="flex:0 0 17%">
<div class="box"><b>Flutter</b><br/>Web·iOS·Android</div>
<p class="arrow" style="text-align:center">▼ REST /api/*</p>
<div class="box"><b>Gateway</b><br/>JWT 엣지검증<br/>Redis rate-limit</div>
</div>
<div style="flex:0 0 38%">
<div class="cols" style="gap:8px">
<div class="box"><b>platform</b><br/>인증·결제<br/>알림·감사</div>
<div class="box"><b>knowledge</b><br/>노트·그래프<br/>검색</div>
</div>
<div class="cols" style="gap:8px; margin-top:8px">
<div class="box"><b>learning</b><br/>SM-2 복습(Java)<br/>AI 카드(Python)</div>
<div class="box"><b>engagement</b><br/>커뮤니티<br/>게이미피케이션</div>
</div>
<p class="arrow" style="text-align:center">▲▼ 발행/소비 (Transactional Outbox)</p>
<div class="box" style="background:var(--accent-soft)"><b>Kafka (AWS MSK) + Schema Registry (Avro·BACKWARD)</b><br/><span class="small">user-registered · note-created/updated · review-completed · notification-send · level-up/badge-earned (8토픽)</span></div>
</div>
<div style="flex:0 0 30%">
<div class="box"><b>RDS PostgreSQL 16.9</b><br/>스키마 격리 + pgvector(1536d)</div>
<div class="box" style="margin-top:8px"><b>ElastiCache Redis 7.1</b><br/>캐시·rate-limit</div>
<div class="box" style="margin-top:8px"><b>Elasticsearch 9.2.1</b><br/>Nori 한국어 분석기</div>
<div class="box" style="margin-top:8px"><b>EKS + ArgoCD GitOps</b><br/>dev/staging/prod · Terraform IaC</div>
</div>
</div>

**이벤트 순환 예**: 노트 생성 → AI 카드 생성 → 복습 완료 → XP/레벨업 → 알림 (전 이벤트 감사 기록)

---

###### 01. 프로젝트 개요

# 개발환경 · 활용방안

| 영역 | 스택 |
|---|---|
| 백엔드 | **Java 21 · Spring Boot 4.0** · Spring Modulith(+ArchUnit) · Spring Cloud Gateway(WebFlux) |
| AI | **Python 3.12 · FastAPI** · anthropic/openai SDK 직접 호출(LangChain 미사용) · pgvector |
| 프론트 | **Flutter 3 / Dart** · Riverpod · go_router (단일 코드베이스 Web/iOS/Android) |
| 데이터 | PostgreSQL 16.9(RDS) · Redis 7.1 · Kafka(MSK 3.6, TLS) · Schema Registry 7.7 · ES 9.2(Nori) |
| 인프라 | **AWS EKS 1.30** · Terraform · Kustomize · **ArgoCD GitOps** · External Secrets · ECR |
| CI/CD·품질 | GitHub Actions 재사용 워크플로우(shared) · Testcontainers · JaCoCo 80% 게이트 · Flyway 가드 |

<div class="cols">
<div>

**활용방안** — Freemium SaaS(Free/Pro/Team/Enterprise), 멀티테넌트로 B2C·B2B(교육기관) 동시 대응

</div>
<div>

**기대효과** — 카드 제작 노동 제거 + 망각곡선 복습 정착 + 시맨틱 재발견 / MSA·이벤트·GitOps·LLM **현업 표준 레퍼런스**

</div>
</div>

---

<!-- _class: compact -->

###### 02. 팀 구성 및 역할

# 7인 — 도메인 트랙 분담, 프론트엔드는 전원 협업

| 훈련생 | 역할 | 트랙 | 담당 |
|---|---|---|---|
| **김민구** | **팀장** | Gateway·인프라 | EKS·MSK·RDS IaC, ArgoCD·CI/CD·Schema Registry, API Gateway, PR 크로스리뷰·통합 조율, staging 복구 |
| 김해준 | 팀원 | A · platform | 인증(OAuth+JWT+MFA), Stripe 결제, FCM/SES 알림, 감사로그(전 이벤트 소비), GDPR Admin |
| 한승완 | 팀원 | B · engagement | 커뮤니티(그룹·공유·신고/모더레이션), 게이미피케이션(XP·레벨·배지·리더보드) |
| 김현지 | 팀원 | C-1 · knowledge | 노트 CRUD·버전·태그, 위키링크·백링크, 지식 그래프(PageRank), ES 동기화 |
| 박은서 | 팀원 | C-2 · knowledge | 비동기 청킹, BM25·RRF 하이브리드 검색, Modulith 경계(ArchUnit), Avro 스키마 |
| 김나경 | 팀원 | D-1 · learning-card | 덱·카드, **SM-2 복습 알고리즘**, 세션·통계, review 이벤트 발행 |
| 조유지 | 팀원 | D-2 · learning-ai | **Claude 카드 자동 생성**, OpenAI 임베딩, pgvector 시맨틱 검색, RAG |

- **Flutter 프론트엔드**: 별도 owner 없이 **각자 자기 도메인 화면을 전원 공동 구현**
- 멘토 지원: {{멘토 지원내역 — 주제 선정 피드백, 질의응답 등}}

---

###### 03. 수행 절차 및 방법

# 5주 스프린트 (2026-05-12 ~ 06-15, 22 영업일)

| 구분 | 기간 | 활동 | 비고 |
|---|---|---|---|
| 사전 기획 | ~05-11 | 주제·페르소나·요구사항, **ADR 0001~0003**, 문서체계 수립 | 아이디어 선정 |
| **W1** 환경·골격 | 05-12~15 | EKS·RDS·MSK·ArgoCD 셋업, 4서비스 골격+CRUD, auth, Flutter 쉘 | 인프라 구축 |
| **W2** 핵심 구현 | 05-18~22 | SM-2 복습, AI 카드 골격, 그래프·ES 동기화, 청킹·BM25, Avro v1 등록 | 전처리·모델링 |
| **W3** 이벤트·고도화 | 05-26~29 | 전 producer 발행, 게이미피케이션 완성, RRF 하이브리드, AI 안정화 | 중간보고 (4일) |
| **W4** 통합·소비자 | 06-01~05 | notification(FCM/SES)·audit 소비, 모더레이션, ArgoCD dev/staging 검증 | (4일) |
| **W5** 안정화·발표 | 06-08~12 | **E2E 10 시나리오·P0 0건·SLA 측정·커버리지 80%·Staging 가동** | 최적화·오류 수정 |
| 발표 | **06-15** | 최종 발표·시연 — **코드 동결**(P0 hotfix만) | |

> 공휴일(5/25·6/3) 반영, 4주 계획을 **이벤트 흐름 축(producer→consumer)으로 5주 전면 개편**(v3.0)

---

###### 03. 수행 절차 및 방법

# 수행 방법 — 협업·품질 체계

<div class="cols">
<div>

**형상·협업**

- **멀티레포 19개** — 서비스 / gitops / shared 계약 / 문서·산출물 분리
- 브랜치 → PR → **크로스리뷰** → merge (Conventional Commits)
- **workflow-dashboard** — 7개 레포 진행 현황 일 3회 동기화 시각화
- shared **Avro 계약 단일 소스** → GitHub Packages 배포

</div>
<div>

**품질·운영**

- **5종 문서체계**: SCOPE → PRD → TASK → WORKFLOW → HISTORY (1주 스프린트)
- **ADR**로 아키텍처 의사결정 기록
- TDD·Testcontainers·**JaCoCo 80% 게이트**·ArchUnit 모듈 경계
- **GitOps**: ArgoCD — dev 자동 sync / staging·prod 승인 게이트, Image Updater
- 재사용 CI: deploy·schema-check·flyway-guard·mirror

</div>
</div>

```text
주제·ADR → 골격(W1) → 전처리·핵심 모델(W2) → 이벤트·고도화(W3) → 소비·통합(W4) → E2E·SLA·Staging·발표(W5)
```

---

###### 04-① 탐색적 분석 및 전처리

# 데이터 = 사용자 노트(Markdown) — 두 갈래 전처리

<div class="cols">
<div>

**키워드 검색용 (BM25)**

- Elasticsearch `notes-v1` 색인
- **Nori 한국어 형태소 분석기** (커스텀 nori-9.2.1 이미지)
- `bm25_tuned` 유사도 **k1=1.4 / b=0.65**
- 필드 부스트: title^4 · tags^2.5 · content^1

**그래프 전처리**

- `[[위키링크]]` 파싱 → `note_links` 관계 저장
- **PageRank**(damping 0.85, 10 iter) + in-degree로 중요 노트 산정

</div>
<div>

**시맨틱 검색용 (임베딩)**

- 노트 저장 직후 `AFTER_COMMIT` 비동기 **청킹**: 문단 분리·정규화 → **512토큰 / 50토큰 중첩** 슬라이딩 윈도우
- learning-ai에 배치 위임 → OpenAI `text-embedding-3-small` **1536차원**
- pgvector 저장 (HNSW `vector_cosine_ops`), 차원·개수 검증

**정제·안전**

- OWASP HTML Sanitizer로 XSS 제거
- BIGINT ↔ UUID 식별자 매핑으로 멱등 처리

</div>
</div>

---

###### 04-② 모델 개요

# 4개 모델이 만드는 학습 순환

<div class="cols" style="font-size:.9em; text-align:center">
<div class="box"><b>① 노트 작성</b><br/><span class="small">knowledge · Outbox 발행</span></div>
<p class="arrow">→</p>
<div class="box"><b>② AI 카드 생성</b><br/><span class="small">learning-ai · Claude</span></div>
<p class="arrow">→</p>
<div class="box"><b>③ 간격 반복 복습</b><br/><span class="small">learning-card · SM-2</span></div>
<p class="arrow">→</p>
<div class="box"><b>④ XP·레벨·배지</b><br/><span class="small">engagement · 알림 환류</span></div>
<p class="arrow">→</p>
<div class="box"><b>⑤ 재발견</b><br/><span class="small">하이브리드 검색·그래프</span></div>
</div>

<p style="text-align:center" class="small">⑤ → ① 다시 노트로 — 전 구간 Kafka 이벤트로 비동기 연결, 전 이벤트 audit 기록</p>

| 모델 | 종류 | 역할 |
|---|---|---|
| **Claude 3.5 Sonnet** | 생성형 LLM | 노트 → 플래시카드(앞/뒤) 자동 생성, 폴백 gpt-4o-mini |
| **text-embedding-3-small** | 임베딩 (1536d) | 청크 의미 벡터화 → 코사인 유사도 |
| **BM25 + 코사인 + RRF** | 검색 랭킹 | 키워드·의미 랭킹 융합 |
| **SM-2 변형 (4등급)** | 복습 스케줄링 | 평가에 따라 다음 복습일·난이도 계수 산정 |

---

###### 04-③ 모델 선정 및 분석 (1/2)

# 생성 — Claude 직접 호출 · 복습 — SM-2 변형

<div class="cols">
<div>

**AI 카드 생성 (learning-ai)**

- **LangChain 없이 Anthropic SDK 직접 호출** — 의존성·블랙박스 최소화
- 프롬프트를 외부 파일 + **Jinja2 템플릿**으로 분리 관리
- 시스템 프롬프트: JSON-only 출력, 입력 언어 추종, 카드 3~10장
- 출력 스키마: `front`(≤200자) / `back`(≤500자), `AI_GENERATED` 타입
- temperature 1.0, max_tokens 1024

</div>
<div>

**복습 스케줄링 (learning-card)**

- Anki식 **4버튼 변형**: AGAIN / HARD / GOOD / EASY
- AGAIN: `EF=max(1.3, EF−0.2)`, interval 1일 리셋
- rating≥2: `EF += 0.1−(4−r)(0.08+(4−r)·0.02)`
- interval: GOOD `round(i·EF)` · EASY ×2 보너스
- 카드별 EF·interval·lapses·dueDate 상태 보존 (초기 EF 2.5)

</div>
</div>

> 선정 기준: 정확도 못지않게 **운영 가능성** — SDK 직접 제어, 프롬프트 형상관리, 결정적 스케줄링

---

###### 04-③ 모델 선정 및 분석 (2/2)

# 검색 — RRF 하이브리드 · 이벤트 — Avro + Outbox

<div class="cols">
<div>

**하이브리드 검색 (knowledge)**

- **키워드**: ES BM25, minimumShouldMatch 70%, 하이라이트
- **시맨틱**: learning-ai HTTP 위임, pgvector 코사인(임계 0.7)
- **RRF 융합**: `score += 1/(k + rank)`, **k=40**, 후보 ×5, `CompletableFuture` 병렬
- 시맨틱 실패 시 **키워드 단독 폴백** → 검색 가용성 보장

</div>
<div>

**이벤트 신뢰성 (전 서비스)**

- **Avro + Schema Registry, BACKWARD 호환 강제** / 내부 동기화는 JSON+DLQ
- 공통 메타 표준: `eventId`(멱등키)·`tenantId`·`occurredAt`
- **Transactional Outbox**: 쓰기 트랜잭션과 원자적 enqueue → 디스패처가 `FOR UPDATE SKIP LOCKED` + **claim-lease(30s)** 로 멀티워커·크래시 복구
- 활성 **8토픽** (3파티션·RF2·7일 보존·키 tenantId)

</div>
</div>

---

###### 04-④ 모델 평가 및 개선

# 발견 → 보완 — 피드백 반영 사례

| 발견된 문제 | 적용한 보완 | PR |
|---|---|---|
| 검색 동기화 컨슈머 미등록 → **ES 색인 0건** | search-sync consumer group 등록 → 색인 정상화 | knowledge #76 |
| 청크 임베딩이 **DB에 저장되지 않는** 경로 결함 | JDBC `cast(? as vector)` 직접 저장 + 1536d·개수 검증 | knowledge #79 |
| LLM 응답에 JSON 외 텍스트 혼입 → 카드 생성 실패 | 마크다운 펜스 제거 → `[`~`]` 추출 → Pydantic 검증 **파싱 견고화** | learning-ai #71 |
| OpenAPI 문서 500 오류 | 문서 생성 설정 교정 | knowledge #70 |
| 관리자 화면 mock 데이터 동작 | 쿼터·피처플래그·레이트리밋 **실 API 연동** | frontend #51 |

**공통 견고화** — 전 컨슈머 `eventId` 멱등 처리 · DLQ(`note.created.dlq`) 격리 · 시맨틱 폴백 · Outbox 만료 리스 재클레임으로 at-least-once 흡수

---

###### 04-④ 운영 증명 (1/2)

# 성능 SLA — staging 실측

| # | 항목 | 목표 | 실측 | 판정 |
|---|---|---|---|---|
| P1 | 핵심 API P95 | <200ms | 로그인 **79.7ms** · 신고 15.3ms | ✅ |
| P2 | Kafka 발행→소비→DB | <5s | **~1.42s** | ✅ |
| P3 | 검색 레이턴시 | <2s | 0.012s(직접) · 0.021s(gateway) | ✅ 레이턴시 |
| P4 | E2E 체인 (복습→XP→레벨업→audit) | <10s | **1.31s** | ✅ |
| P5 | audit 적재 | <30s | **1.31s** | ✅ |
| P6 | AI 카드 생성 | <30s | 측정 보류 (운영 키·스키마 갭) | ⏸ |
| P7 | FCM 발송 성공률 | >95% | **10/10 = 100%** (실 웹 토큰) | ✅ |

> 측정 환경: AWS EKS staging, 실 MSK·RDS — **5/7 충족**, P3 기능(인덱서)·P6 체인은 개선 과제로 식별

---

###### 04-④ 운영 증명 (2/2)

# Staging 장애 복구 — "운영을 경험했다"

```text
06-11 02:44  gitops bring-up 중단 — bastion IAM에 eks:DescribeCluster 결여 (근본 원인 식별)
      ↓      로컬 SSM 터널 + bring-up.sh --from tunnel 로 멱등 재개 (argocd→eso→…→observability)
      ↓      ES nori CrashLoop(데이터 디렉터리 권한) → 파드 재생성으로 fsGroup chown → green
      ↓      서비스 ECR 레포 7종 부재 발견 → 선생성 → owner CI 이미지 push 재개
17:15        ArgoCD 16/16 Synced/Healthy (dev 9 + staging 7) — 24h 안정 기준점 수립
06-11 저녁   P0 회귀(FR-ALL-302) PASS — 라이브 가입→engagement 소비·audit 적재, poison 0건
06-12        Prometheus·Grafana·Loki 관측 + 알림 튜닝 → 24h 안정 사인오프
```

- 장애를 **근본 원인(IAM·권한·레지스트리)** 까지 추적하고 **재발 방지를 이슈·IaC로 환류** (gitops #182·#194)
- EKS 매니지드 컨트롤플레인 false-positive 알림 룰 비활성화 — **firing = Watchdog만** 목표
- 인프라 전체가 Terraform·ArgoCD 코드라서 **`bring-up.sh` 하나로 재현 가능**

---

###### 04-⑤ 시연

# 데모 — 학습 순환 한 바퀴 (5분)

| 구간 | 시연 내용 | 확인 포인트 |
|---|---|---|
| ① 가입·로그인 (40s) | 신규 가입 → JWT 발급 | `user-registered` 이벤트 → 프로필 자동 생성 |
| ② 노트 작성 (50s) | Markdown + `[[위키링크]]` → 그래프 뷰 | 백링크·PageRank 시각화 |
| ③ AI 카드 (50s) | 노트 저장 → 자동 생성된 플래시카드 확인 | `note-created` → Claude 생성 체인 |
| ④ 복습 (60s) | SM-2 복습 세션 → 4버튼 평가 | XP +10 → 레벨업 → 알림 환류 |
| ⑤ 검색 (40s) | 키워드 vs 시맨틱 vs **하이브리드** 비교 | RRF 융합 랭킹·하이라이트 |
| ⑥ 운영 화면 (40s) | Grafana 대시보드·audit 로그 | 방금 발생한 이벤트가 메트릭·감사에 반영 |

> 시연 영상: **AWS EKS staging 환경 실측 녹화** (5~10분, 기능별 음성 소개 포함, 별도 파일 제출)

---

###### 05. 자체 평가

# 기획 의도 대비 달성도 — {{N}}/10

| 목표 | 결과 | 달성 |
|---|---|---|
| G1 PKM-SRS 통합 워크플로우 | 노트→카드→복습 순환 전 구간 구현·E2E 검증 | ✅ |
| G2 AI 카드 자동 생성 | Claude 파이프라인 + 파싱 견고화 + DLQ (운영 키 주입 과제 잔존) | 🟡 |
| G3 지식 그래프 | 위키링크·백링크·PageRank·2D 시각화 | ✅ |
| G4 하이브리드 시맨틱 검색 | BM25×임베딩 RRF 융합 + 폴백 (정확도 정량 측정은 과제) | 🟡 |
| G5 크로스 플랫폼 | Flutter 단일 코드베이스 Web/iOS/Android | ✅ |
| G6 SaaS 수익화 | Stripe 결제·Freemium 4단계·멀티테넌트 | ✅ |

**+ 계획에 없던 성취** — AWS EKS staging **실 운영**: ArgoCD 16/16 Healthy, SLA 실측 5/7 충족, 장애 복구·24h 안정 사인오프

<p class="small">※ 점수·팀 의견은 발표 전 팀 회고에서 확정</p>

---

###### 05. 자체 평가

# 개선·보완할 점

| 항목 | 현황 | 개선 방향 |
|---|---|---|
| 사용자 식별자 모델 | platform UUID ↔ 일부 서비스 Long 해시 혼재 | **전 서비스 UUID 정본 통일** (진행 중) |
| P6 AI 카드 체인 | 운영 환경 실 키·스키마 정렬 미완 | 키 주입 + ReviewCompleted 정본 정렬 후 SLA 재측정 |
| 검색 정확도 | 레이턴시만 실측, MRR@10 미측정 | 골든셋 구축 → 정량 평가 |
| Avro 버전 드리프트 | 서비스 간 1.11.3/7.5.0 vs 1.12.0/7.7.0 | 정본 정렬 + CI 호환성 검증 전 서비스 확대 |
| Outbox 재시도 | 무한 재시도 (상한 없음) | max-attempt + DLQ 상한 도입 |
| 잔여 기능 | Streak 스텁 · S3 첨부 미구현 · 리더보드 DB 정렬 | 차기 스프린트 반영 |

---

###### 05. 자체 평가

# 성과와 소감

<div class="cols">
<div>

**잘한 점**

- **정공법 아키텍처** — ADR로 결정을 기록하고 MSA·이벤트 드리븐·Outbox·CQRS를 끝까지 구현
- **운영까지 완주** — EKS·GitOps 실 배포, SLA 실측, 장애 복구, 관측성(Prometheus·Grafana·Loki)
- **협업 체계** — 7인 멀티레포·크로스리뷰·5종 문서·대시보드로 5주 스프린트 완수
- 발견한 결함을 **이슈→PR→회귀 검증**으로 닫는 사이클 정착

</div>
<div>

**아쉬운 점**

- AI 체인의 운영 환경 검증을 발표 주까지 끌고 옴 — 외부 의존(키·스키마)은 더 일찍
- 식별자 모델 통일을 설계 단계에서 확정하지 못해 후반 비용 발생
- 검색 품질의 정량 평가(골든셋) 미완

**경력 연계** — 백엔드·인프라·AI 각자 트랙에서 **현업 표준 도구체인을 실전 경험**

</div>
</div>

<p style="text-align:center; margin-top:24px"><b>감사합니다 — Q&A</b></p>
