-- V005__test_learning_ai.sql
-- E2E 테스트용 AI 카드 생성 이력 시드 데이터

INSERT INTO learning.ai_generation_history (id, note_id, user_id, tenant_id, card_count, status, created_at)
VALUES
  ('e2e-aigen-01', 'e2e-note-01', 'e2e-user-01', 'tenant-e2e-001',
   5, 'COMPLETED', '2026-05-20 09:03:00'),
  ('e2e-aigen-02', 'e2e-note-02', 'e2e-user-01', 'tenant-e2e-001',
   3, 'COMPLETED', '2026-05-20 09:03:30')
ON CONFLICT (id) DO NOTHING;
