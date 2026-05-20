-- V002__test_notes.sql
-- E2E 테스트용 노트 시드 데이터

INSERT INTO knowledge.notes (id, user_id, tenant_id, title, content, created_at)
VALUES
  ('e2e-note-01', 'e2e-user-01', 'tenant-e2e-001',
   'Kafka Basics', 'Introduction to Apache Kafka event streaming.',
   '2026-05-20 09:01:00'),
  ('e2e-note-02', 'e2e-user-01', 'tenant-e2e-001',
   'Distributed Systems', 'CAP theorem and consistency models.',
   '2026-05-20 09:01:00')
ON CONFLICT (id) DO NOTHING;
