-- V003__test_cards.sql
-- E2E 테스트용 플래시카드 시드 데이터

INSERT INTO learning.cards (id, note_id, user_id, tenant_id, front, back, next_review_at, created_at)
VALUES
  ('e2e-card-01', 'e2e-note-01', 'e2e-user-01', 'tenant-e2e-001',
   'What is Kafka?', 'A distributed event streaming platform.',
   '2026-05-21 09:00:00', '2026-05-20 09:01:00'),
  ('e2e-card-02', 'e2e-note-01', 'e2e-user-01', 'tenant-e2e-001',
   'What is a Kafka topic?', 'A category/feed name to which records are published.',
   '2026-05-21 09:00:00', '2026-05-20 09:01:00'),
  ('e2e-card-03', 'e2e-note-02', 'e2e-user-01', 'tenant-e2e-001',
   'What is CAP theorem?', 'A distributed system can only guarantee 2 of 3: Consistency, Availability, Partition tolerance.',
   '2026-05-21 09:00:00', '2026-05-20 09:01:00')
ON CONFLICT (id) DO NOTHING;
