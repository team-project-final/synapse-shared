-- E2E 서비스별 데이터베이스 분리 (rule 11 data-sovereignty + flyway_schema_history 충돌 방지)
-- postgres 컨테이너 최초 기동(빈 볼륨)에서만 실행됨 — 재생성: docker compose down -v
CREATE DATABASE synapse_platform OWNER synapse;
CREATE DATABASE synapse_engagement OWNER synapse;
CREATE DATABASE synapse_knowledge OWNER synapse;
CREATE DATABASE synapse_learning OWNER synapse;
CREATE DATABASE synapse_ai OWNER synapse;
