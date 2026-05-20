-- V001__test_users.sql
-- E2E 테스트용 유저 시드 데이터
-- Docker Compose 로컬 환경 (synapse DB) 기준

-- Tenant 1: 기본 테스트 테넌트
INSERT INTO platform.users (id, email, tenant_id, created_at)
VALUES
  ('e2e-user-01', 'alice@test.synapse.dev', 'tenant-e2e-001', '2026-05-20 09:00:00'),
  ('e2e-user-02', 'bob@test.synapse.dev',   'tenant-e2e-001', '2026-05-20 09:00:00')
ON CONFLICT (id) DO NOTHING;

-- Tenant 2: 멀티테넌시 테스트
INSERT INTO platform.users (id, email, tenant_id, created_at)
VALUES
  ('e2e-user-03', 'carol@test.synapse.dev', 'tenant-e2e-002', '2026-05-20 09:00:00')
ON CONFLICT (id) DO NOTHING;
