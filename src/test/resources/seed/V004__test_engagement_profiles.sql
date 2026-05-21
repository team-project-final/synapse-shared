-- V004__test_engagement_profiles.sql
-- E2E 테스트용 engagement 프로필 + XP 시드 데이터

INSERT INTO engagement.user_profiles (user_id, tenant_id, display_name, xp_total, level, created_at)
VALUES
  ('e2e-user-01', 'tenant-e2e-001', 'Alice', 0, 1, '2026-05-20 09:00:00'),
  ('e2e-user-02', 'tenant-e2e-001', 'Bob',   150, 2, '2026-05-20 09:00:00'),
  ('e2e-user-03', 'tenant-e2e-002', 'Carol', 0, 1, '2026-05-20 09:00:00')
ON CONFLICT (user_id) DO NOTHING;

-- XP 이력 (review-completed 이벤트 검증용 — Bob에게 기존 XP 있음)
INSERT INTO engagement.xp_history (id, user_id, tenant_id, event_type, xp_amount, created_at)
VALUES
  ('e2e-xp-01', 'e2e-user-02', 'tenant-e2e-001', 'review-completed', 50, '2026-05-20 09:02:00'),
  ('e2e-xp-02', 'e2e-user-02', 'tenant-e2e-001', 'review-completed', 50, '2026-05-20 09:03:00'),
  ('e2e-xp-03', 'e2e-user-02', 'tenant-e2e-001', 'review-completed', 50, '2026-05-20 09:04:00')
ON CONFLICT (id) DO NOTHING;
