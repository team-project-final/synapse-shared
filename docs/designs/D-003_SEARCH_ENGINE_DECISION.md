# D-003 — 검색 엔진 정합: Elasticsearch 채택 (OpenSearch → Elasticsearch 전환)

> **작성일**: 2026-06-04
> **작성자**: @team-lead
> **상태**: ✅ **결정 — Elasticsearch (Spring Data Elasticsearch / ES9 client) 채택** (2026-06-04, 팀장). gitops PR #114에서 확정. 환경 변수 통합: `ELASTICSEARCH_URIS`. 참조 계획: [2026-06-04-knowledge-search-elasticsearch-migration.md](../../synapse-gitops/docs/2026-06-04-knowledge-search-elasticsearch-migration.md)
> **관련**: [D-002_SCHEMA_FAMILY_DECISION](./D-002_SCHEMA_FAMILY_DECISION.md) · [EVENT_FLOW_MATRIX](../guides/EVENT_FLOW_MATRIX.md) · [EVENT_CONTRACT_STANDARD](../guides/EVENT_CONTRACT_STANDARD.md)

---

## 1. 문제

knowledge-svc의 검색 구현이 **OpenSearch를 대상으로 설계**됐으나, 애플리케이션 클라이언트(Spring Data Elasticsearch / ES9 native client)가 **OpenSearch 서버와 호환되지 않는다**. ES9 클라이언트는 product-check(제품 확인)을 수행하며, OpenSearch 서버를 만나면 연결을 거부한다(`product check rejected OpenSearch`). 동시에 인프라(gitops)는 OpenSearch→Elasticsearch로 마이그레이션이 완료(PR #114)됐으나, 로컬 개발 환경(`docker-compose.yml`)과 env 표준(`.env.example`)은 여전히 OpenSearch 이미지와 `OPENSEARCH_URL` 변수를 참조 중이다. 이 불일치가 로컬 E2E 검증을 차단한다.

## 2. 실측 (2026-06-04 직접 확인)

| 계층 | 이전 (OpenSearch) | 이후 (Elasticsearch) |
|------|-----------------|---------------------|
| **앱 클라이언트** | `spring-boot-starter-data-elasticsearch` (ES9 native client) | 동일 — 변경 없음 |
| **product-check** | ES9 client가 OpenSearch 서버를 거부 | ES9 client ↔ ES9 서버: 통과 |
| **로컬 컨테이너** | `opensearchproject/opensearch:2.11.0` | `docker.elastic.co/elasticsearch/elasticsearch:9.2.1` |
| **서비스명** | `opensearch` (compose) | `elasticsearch` (compose) |
| **env 변수** | `OPENSEARCH_URL=http://opensearch:9200` | `ELASTICSEARCH_URIS=http://elasticsearch:9200` |
| **인프라 (gitops)** | OpenSearch StatefulSet | Elasticsearch StatefulSet (PR #114 완료) |
| **AWS 관리형** | AWS OpenSearch Service 사용 가능 | AWS ES(Elasticsearch)는 v6까지만 지원 → **ES 8/9는 지원 불가** → 자체 호스팅 |

### 불일치 차원

1. **클라이언트·서버 불일치**: Spring Data Elasticsearch(ES9)는 OpenSearch 서버를 `product check`로 명시 거부. 상호 연결 불가.
2. **인프라·로컬 불일치**: gitops는 Elasticsearch로 완료됐으나 docker-compose는 OpenSearch 잔존.
3. **env 이름 불일치**: gitops가 `ELASTICSEARCH_URIS`를 표준으로 채택했으나 `.env.example`은 `OPENSEARCH_URL` 유지.
4. **문서 전체 불일치**: EVENT_FLOW_MATRIX, E2E_SCENARIOS_W3, KICKOFF, README 등에서 `opensearch`/`OpenSearch` 레이블이 남아 있어 신규 팀원에게 혼선.

## 3. 영향

| 계층 | 영향 |
|------|------|
| knowledge-svc (검색) | ES9 클라이언트 → ES9 서버 → product-check 통과, 연결 성립 |
| learning-ai | pgvector 사용(ES 무관). `ELASTICSEARCH_URIS` 환경 변수 **미부여** |
| 로컬 dev E2E | docker-compose ES 컨테이너로 교체 → knowledge-svc 종속 해소 |
| CI/CD | 변경 없음 (gitops PR #114에서 이미 완료) |
| 문서/가이드 | opensearch 레이블 → elasticsearch 레이블 정합 |

## 4. 선택지

### Option 1 — OpenSearch 유지 (기각)
- `spring-boot-starter-data-elasticsearch` 제거 → OpenSearch Java 클라이언트(`opensearch-rest-high-level-client` 또는 `opensearch-java`)로 교체.
- **기각 이유**: gitops PR #114에서 인프라를 이미 Elasticsearch로 마이그레이션 완료. 앱 코드도 Spring Data ES로 구현됨. 역방향 전환 비용이 더 크고 PR #114 결정을 뒤집어야 한다.

### Option 2 — Elasticsearch 전면 채택 (✅ 채택)
- 앱: Spring Data Elasticsearch / ES9 client 유지.
- 인프라: 자체 호스팅 ES StatefulSet(dev). AWS ES는 v6까지만 지원하므로 AWS 관리형 사용 불가.
- 로컬: `docker.elastic.co/elasticsearch/elasticsearch:9.2.1` 컨테이너.
- env: `ELASTICSEARCH_URIS=http://elasticsearch:9200`.
- **장점**: 이미 구현·인프라가 ES 기준이며, product-check 통과. 단일 스택으로 정합.
- **단점**: nori 한국어 분석기는 ES 기본 이미지에 포함되지 않음 → 커스텀 이미지(follow-up).

## 5. 결정 ✅

> **최종 결정(2026-06-04, 팀장): Option 2 — Elasticsearch 전면 채택.**
>
> - **앱 클라이언트**: `spring-boot-starter-data-elasticsearch` (ES9 native client), Spring Boot auto-configuration.
> - **env 표준**: `ELASTICSEARCH_URIS=http://elasticsearch:9200` (로컬), 클러스터 내부: `http://elasticsearch:9200`.
> - **로컬 컨테이너**: `docker.elastic.co/elasticsearch/elasticsearch:9.2.1`, `xpack.security.enabled=false`, `discovery.type=single-node`.
> - **인프라 (dev)**: 자체 호스팅 ES StatefulSet (gitops PR #114 완료). AWS 관리형 ES는 v8/9 미지원으로 사용 불가.
> - **learning-ai**: pgvector 사용. Elasticsearch URL 미부여.
> - **근거 문서**: gitops `2026-06-04-knowledge-search-elasticsearch-migration.md`.

## 6. 결론 — 변경 범위

| 파일 | 변경 내용 |
|------|---------|
| `docker-compose.yml` | `opensearch` 서비스 → `elasticsearch` (이미지 `9.2.1`, env `ES_JAVA_OPTS`, `xpack.security.enabled=false`, volume `elasticsearch-data`) |
| `.env.example` | `OPENSEARCH_URL` → `ELASTICSEARCH_URIS`, 섹션 코멘트 `OpenSearch` → `Elasticsearch` |
| `docs/guides/EVENT_FLOW_MATRIX.md` | Consumer 컬럼·Chain D 서술에서 `opensearch` → `knowledge-svc (ES indexer)` / `Elasticsearch` |
| `docs/guides/E2E_SCENARIOS_W3.md` | S4 시나리오·검증 단계 `opensearch` → `elasticsearch`/`Elasticsearch` |
| `scripts/kafka-e2e-test.sh` | S4 scenario 문자열 `opensearch` → `elasticsearch` |
| `docs/project-management/KICKOFF.md` | 기술 스택 표 `OpenSearch 8` → `Elasticsearch 9` |
| `README.md` | 포트 표 서비스명 `OpenSearch` → `Elasticsearch` |
| `docs/project-management/HANDOFF_SHARED.md` | Docker Compose 현황 `opensearch` → `elasticsearch` |
| `docs/guides/EVENT_CONTRACT_STANDARD.md` | `knowledge.note.note-updated-v1` 소비 주체 보충 — knowledge-svc ES indexer |
| **이 문서 (신규)** | D-003 ADR 등록 |

## 7. 후속 과제

1. **nori 플러그인**: Elasticsearch 기본 이미지에 미포함. 커스텀 Dockerfile(`FROM docker.elastic.co/elasticsearch/elasticsearch:9.2.1` + `elasticsearch-plugin install analysis-nori`)로 로컬/dev 이미지 빌드 → gitops 업데이트. (follow-up, W5 이전)
2. **knowledge-svc 앱 설정**: `application.yml`에서 `spring.elasticsearch.uris=${ELASTICSEARCH_URIS:http://localhost:9200}` 확인·적용.
3. **인덱스 매핑 재생성**: OpenSearch 인덱스 → Elasticsearch 인덱스 마이그레이션(dev 환경). 로컬은 볼륨 삭제(`docker compose down -v`) 후 재기동으로 클린 슬레이트.

## 8. 오픈

- nori 커스텀 이미지 빌드·gitops 반영 (W5 이전, knowledge 트랙 담당).
- knowledge-svc `SPRING_ELASTICSEARCH_URIS` vs `ELASTICSEARCH_URIS` env 이름 최종 확인 (앱 코드 우선 — gitops 기준 `ELASTICSEARCH_URIS`).
