# 설계: Synapse Docs Portal — 통합 문서 사이트

> **작성일**: 2026-05-22
> **작성자**: @team-lead
> **상태**: 설계 완료, 구현 대기

---

## 1. 개요

### 목적

synapse-gitops(런북 20개)와 synapse-shared(문서 44개)의 마크다운 문서를 하나의 웹 포탈에서 검색/열람/요약할 수 있는 통합 문서 사이트를 구축한다.

### 배경

- 현재 64개 마크다운 파일(11,000줄)이 두 레포에 분산
- GitHub에서 직접 마크다운을 찾아보는 방식은 비효율적
- GitOps 작업 내역, AWS 인프라 설정, 레포 간 연결 구성, MSA 전체 구성을 한 곳에서 파악할 수 없음

### 기존 자산

- `synapse-gitops/site/` — Flutter Web 기반 Runbook Viewer (이미 배포)
  - 컴포넌트: MarkdownViewer, Sidebar, CodeBlock, Runbook 모델
  - 라우트: `/` (홈), `/runbook/:slug` (개별 런북), `/onboarding`
  - 데이터: `assets/runbooks/index.json` + 개별 `{slug}.json`

### 접근 방식

기존 gitops/site Flutter 프로젝트를 확장하여 shared 문서까지 통합. 새 프로젝트가 아닌 확장이므로 기존 컴포넌트 재사용, 배포 파이프라인 활용.

---

## 2. 콘텐츠 구조

### 카테고리 체계

| 카테고리 | ID | 소스 | 문서 수 | 설명 |
|----------|-----|------|:-------:|------|
| 인프라 | `infra` | gitops/docs/runbooks | ~20 | AWS, Terraform, EKS, ArgoCD 런북 |
| 가이드 | `guides` | shared/docs/guides | 5 | MSK, E2E, ArgoCD 검증, Staging, 체크리스트 |
| 프로젝트 관리 | `management` | shared/docs/project-management | ~15 | HANDOFF, WORKFLOW, HISTORY, TASK, KICKOFF |
| PRD/설계 | `prd` | shared/docs/prd + superpowers | ~11 | 주차별 PRD, 설계 문서, 구현 계획 |
| 규칙 | `rules` | shared/docs/rules | 15 | 보안, 기술, Kafka, 인증 등 표준 |
| 수정 요청 | `fix-requests` | shared/docs/fix-requests | 2 | 서비스별 수정 요청서 |

### 문서 JSON 스키마

```json
{
  "slug": "msk-topic-setup",
  "title": "MSK 토픽 생성 가이드",
  "category": "guides",
  "source": "synapse-shared",
  "tags": ["kafka", "msk", "infra"],
  "summary": "MSK 클러스터에 5개 토픽을 생성하는 절차. TLS 통신 확인 및 ACL 설정 포함.",
  "metadata": {
    "lastUpdated": "2026-05-21",
    "status": "active",
    "completionRate": null
  },
  "toc": [
    { "level": 2, "text": "사전 조건", "anchor": "사전-조건" },
    { "level": 2, "text": "환경별 브로커 주소", "anchor": "환경별-브로커-주소" }
  ],
  "body": "# MSK 토픽 생성 가이드\n..."
}
```

### 진행 상태 자동 추출

- WORKFLOW 파일의 `- [x]` / `- [ ]` 체크박스 파싱 → `completionRate` 계산
- HANDOFF 상태 테이블 파싱 → `status: done | in-progress | blocked`
- 색상 매핑: 0~30% 빨강, 30~70% 주황, 70~100% 녹색

---

## 3. 검색 시스템

### 빌드 시 역인덱스 생성

1. 모든 문서 마크다운 파싱
2. 한국어 토크나이징 (공백 분리 + 빈출 조사 제거: 은/는/이/가/을/를/의/에/로/와/과)
3. 토큰별 매핑: `{ slug, title, section, position }`
4. `search-index.json` 출력 (~200KB, 64문서 기준)

### 검색 기능

| 기능 | 구현 |
|------|------|
| 키워드 검색 | 역인덱스 매칭, 제목 가중치 x3 |
| 실시간 필터링 | 타이핑하면서 결과 즉시 갱신 (debounce 300ms) |
| 카테고리 필터 | 검색 결과를 카테고리별로 좁힘 |
| 검색 하이라이트 | 결과 스니펫에서 매칭 키워드 강조 |
| 최근 검색 | 로컬 스토리지에 최근 5개 저장 |

### 한계점 (의도적 축소)

- 시맨틱 검색(벡터) 없음 — 64개 문서에는 키워드 검색으로 충분
- 서버 없음 — 순수 클라이언트 사이드
- 한국어 형태소 분석기 없음 — 공백 분리 + 조사 제거 수준 (정확도 80%+)

---

## 4. AI 요약

### 빌드 시 사전 생성

```
빌드 스크립트 흐름:
  1. 각 문서 마크다운 읽기
  2. 문서 hash 계산 → 캐시와 비교
  3. 변경된 문서만 Claude API 호출 (Haiku 모델)
     프롬프트: "다음 기술 문서를 2~3줄로 요약해줘.
               핵심 목적, 대상, 결과물을 포함해."
  4. 응답을 {slug}.json의 "summary" 필드에 저장
  5. hash 캐시 갱신 (.summary-cache.json)
```

### 표시 방식

- 문서 상단에 "TL;DR" 카드로 표시 (접이식)
- 홈페이지 목록에서 제목 아래 요약 1줄 미리보기
- 검색 결과에서 요약을 스니펫으로 활용

### 비용

- 64문서 x 평균 200줄 x Haiku 1회 = ~$0.05 이하
- 캐시로 인해 변경분만 재생성 — 증분 비용 거의 0

---

## 5. 가독성 개선

### 5.1 자동 TOC (Table of Contents)

- 문서 내 `##`, `###` 헤딩 파싱
- 우측 사이드패널에 트리 형태로 표시
- 클릭 시 해당 섹션으로 스크롤
- 현재 읽고 있는 섹션 하이라이트 (scroll spy)

### 5.2 진행 상태 시각화

- WORKFLOW/HANDOFF 체크박스 → 프로그레스바 자동 변환
- 주차별 진행률 표시 (W1: 100%, W2: 100%, W3: 30%)
- DashboardPage에 전체 현황 종합

### 5.3 카테고리 필터 + 태그

- 홈페이지 카테고리 탭으로 1차 분류
- 태그 필터로 2차 필터링 (kafka, argocd, terraform, staging 등)
- 태그는 빌드 시 문서 내용에서 키워드 빈도 기반 상위 3~5개 자동 추출

---

## 6. 페이지 구조 + 라우트

### 라우트

| 경로 | 페이지 | 설명 |
|------|--------|------|
| `/` | HomePage | 카테고리 그리드 + 최근 업데이트 + 진행 상태 요약 |
| `/search` | SearchPage | 전문 검색 + 카테고리/태그 필터링 |
| `/docs/:category/:slug` | DocPage | 개별 문서 (TOC + 요약 카드 + 본문) |
| `/dashboard` | DashboardPage | W3 진행 상태, 서비스 상태, 미해결 항목 종합 |
| `/runbook/:slug` | RunbookPage | 기존 런북 (하위 호환 유지) |

### 파일 구조 (기존 gitops/site 확장)

```
synapse-gitops/site/
  lib/
    models/
      runbook.dart          ← 기존 유지
      doc.dart              ← 새로 추가 (통합 문서 모델)
      search_index.dart     ← 새로 추가 (검색 인덱스 모델)
    pages/
      home_page.dart        ← 확장 (카테고리 그리드 + 현황)
      runbook_page.dart     ← 기존 유지
      doc_page.dart         ← 새로 추가 (통합 문서 뷰어)
      search_page.dart      ← 새로 추가
      dashboard_page.dart   ← 새로 추가
    widgets/
      markdown_viewer.dart  ← 기존 유지
      sidebar.dart          ← 확장 (카테고리 + 검색)
      code_block.dart       ← 기존 유지
      toc_panel.dart        ← 새로 추가
      progress_bar.dart     ← 새로 추가
      summary_card.dart     ← 새로 추가
      search_bar.dart       ← 새로 추가
      tag_chip.dart         ← 새로 추가
  assets/
    runbooks/               ← 기존 유지
    docs/                   ← 새로 추가
      index.json
      search-index.json
      infra/*.json
      guides/*.json
      management/*.json
      prd/*.json
      rules/*.json
      fix-requests/*.json
  scripts/
    build_docs.dart         ← 새로 추가 (빌드 파이프라인)
    .summary-cache.json     ← 요약 캐시 (gitignore)
```

---

## 7. 디자인 시스템

`documents/DESIGN.md` 준수:

| 요소 | 값 |
|------|-----|
| 테마 | Warm Intellectual |
| 액센트 | Warm Amber `#D97706` |
| 디스플레이 폰트 | Fraunces (세리프) |
| 본문 폰트 | Plus Jakarta Sans |
| 코드 폰트 | Geist Mono |
| 배경 | Stone 50 `#FAFAF9` |
| 카드 | Stone 100 `#F5F5F4` + 미세 그림자 |

---

## 8. 빌드 파이프라인 상세

### 입력 소스

빌드 스크립트는 같은 workspace에 두 레포가 체크아웃된 환경을 전제한다:

```
C:\workspace\team-project-final\
  synapse-gitops\docs\runbooks\*.md   → ../../synapse-shared 상대 경로
  synapse-shared\docs\**\*.md         → 같은 workspace 내 상대 경로
```

CI에서는 GitHub Actions에서 두 레포를 체크아웃한 뒤 빌드 스크립트를 실행한다.

### 카테고리 자동 분류 규칙

| 소스 경로 | 카테고리 |
|-----------|----------|
| `gitops/docs/runbooks/*` | `infra` |
| `shared/docs/guides/*` | `guides` |
| `shared/docs/project-management/**` | `management` |
| `shared/docs/prd/*` + `shared/docs/superpowers/**` | `prd` |
| `shared/docs/rules/*` | `rules` |
| `shared/docs/fix-requests/*` | `fix-requests` |

### 태그 자동 추출

키워드 사전 기반 매칭 (빈도 불필요, 존재 여부만):

```
kafka, argocd, terraform, eks, rds, msk, redis, opensearch,
docker, helm, staging, dev, prod, security, tls, acl,
flyway, gradle, ci, cd, deploy, rollback, e2e, avro, schema
```

문서 본문에서 위 키워드가 3회 이상 등장하면 태그로 추가. 최대 5개.

---

## 9. 제약사항

- **서버 없음**: 순수 클라이언트 사이드 Flutter Web (GitHub Pages 또는 정적 호스팅)
- **AI API**: 빌드 시에만 사용 (런타임 호출 없음)
- **기존 호환**: `/runbook/:slug` 라우트 유지, 기존 런북 데이터 그대로 사용
- **성능**: search-index.json 200KB 이하 유지, 초기 로드 3초 이내

---

## 10. 성공 기준

- [ ] 64개 문서 전체 카테고리별로 열람 가능
- [ ] 키워드 검색으로 300ms 이내 결과 표시
- [ ] 모든 문서에 AI 요약 표시
- [ ] WORKFLOW/HANDOFF 진행 상태 자동 시각화
- [ ] 기존 런북 라우트 하위 호환 유지
- [ ] 디자인 시스템(DESIGN.md) 준수
