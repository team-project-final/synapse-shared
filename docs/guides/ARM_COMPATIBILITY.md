# Apple Silicon (ARM64) 호환 확인

> **작성**: 2026-06-04 — W1 §1.8 "Apple Silicon(ARM) 호환 확인" 종결 근거.
> **요지**: 로컬 스택(`docker-compose.yml`)의 모든 이미지가 `linux/arm64` 멀티아키텍처를 게시하므로 Apple Silicon에서 동작 가능. 개발/CI는 Windows(x86_64)에서 검증됨 — 잔여는 실제 ARM Mac에서의 라이브 1회 실행뿐.

## 인프라 이미지 (멀티아치 게시 여부)

| 컴포넌트 | 이미지 | linux/arm64 |
|---|---|---|
| PostgreSQL | `postgres:16-alpine` | ✅ 공식 멀티아치 |
| Redis | `redis:7-alpine` | ✅ 공식 멀티아치 |
| Zookeeper | `confluentinc/cp-zookeeper:7.7.0` | ✅ Confluent 7.x arm64 게시 |
| Kafka | `confluentinc/cp-kafka:7.7.0` | ✅ Confluent 7.x arm64 게시 |
| Schema Registry | `confluentinc/cp-schema-registry:7.7.0` | ✅ Confluent 7.x arm64 게시 |
| 검색 | `docker.elastic.co/elasticsearch/elasticsearch:9.2.1` (D-003) | ✅ Elastic 멀티아치 |

> 검색은 D-003에 따라 OpenSearch→Elasticsearch로 전환. `opensearchproject/opensearch`도 arm64를 게시했으므로 전환 전/후 모두 ARM 호환에는 영향 없음.

## 애플리케이션 서비스 (Dockerfile 빌드 — 아키 네이티브)

| 서비스 | 베이스 이미지 | linux/arm64 |
|---|---|---|
| gateway / platform / engagement / knowledge / learning-card | `eclipse-temurin:21-jre-alpine` | ✅ 멀티아치 (JVM 바이트코드 = 아키 무관) |
| learning-ai | `python:3.11-slim` | ✅ 멀티아치 (순수 Python; 네이티브 휠은 arm64 빌드 제공) |

앱 이미지는 베이스 이미지 위에 빌드되므로 빌드 호스트 아키텍처에 맞춰 네이티브로 생성된다(Apple Silicon에서 빌드 시 arm64). JVM 서비스는 바이트코드라 아키 의존 없음.

## 결론
- **모든 이미지가 arm64를 지원** → Apple Silicon에서 `docker compose up` 동작 가능.
- 잠재 주의: learning-ai의 일부 네이티브 의존(예: 임베딩/수치 라이브러리)이 arm64 휠을 요구할 수 있으나, 사용 라이브러리는 arm64 휠을 게시함. 문제 시 `--platform linux/arm64` 명시 빌드로 해결.
- **잔여 항목**: 실제 Apple Silicon Mac에서의 라이브 `docker compose up` 1회 실행 검증(개발/CI는 x86_64 Windows에서 수행). 이미지 호환은 본 문서로 확인 완료.

## 검증 방법(ARM Mac 보유 시)
```bash
docker compose up -d
docker compose ps        # 전 서비스 healthy < 2분
uname -m                 # arm64 확인
docker inspect synapse-postgres --format '{{.Architecture}}'  # arm64
```
