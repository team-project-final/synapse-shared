# synapse-shared

Synapse — shared Avro schemas + common library

## Quick Start (Local Dev)

### 사전 요구

- Docker Desktop (메모리 8GB 이상 할당)
- Java 21 (Temurin)

### 실행

```bash
cp .env.example .env
docker compose up -d
```

전체 서비스가 healthy 상태가 될 때까지 약 1-2분 소요.

### 포트 매핑

| 서비스 | 포트 |
|--------|:----:|
| PostgreSQL | 5432 |
| Redis | 6379 |
| Kafka | 9092 |
| Schema Registry | 8086 |
| OpenSearch | 9200 |
| platform-svc | 8081 |
| engagement-svc | 8082 |
| knowledge-svc | 8083 |
| learning-card-svc | 8084 |
| learning-ai-svc | 8090 |

### 종료

```bash
docker compose down        # 컨테이너 종료
docker compose down -v     # 컨테이너 + 볼륨 삭제
```

## Avro Schemas

`src/main/avro/` 디렉토리에 도메인별 Avro 스키마가 있다.

### 빌드

```bash
./gradlew clean build
```

### 스키마 호환성 검증

Schema Registry가 실행 중일 때:

```bash
SCHEMA_REGISTRY_URL=http://localhost:8086 ./gradlew testSchemasTask
```

## CI/CD

| 워크플로 | 트리거 | 동작 |
|----------|--------|------|
| `ci-java.yml` | PR → main | Gradle build + Modulith verify |
| `schema-check.yml` | PR (*.avsc 변경) | Avro 스키마 호환성 검증 |
| `mirror.yml` | push main | synapse-mirror 자동 동기화 |
