#!/usr/bin/env bash
# scripts/seed-test-data.sh
# Seed test data into PostgreSQL (Docker Compose local environment).
# Usage: bash scripts/seed-test-data.sh
set -euo pipefail

CONTAINER="${POSTGRES_CONTAINER:-synapse-postgres}"
DB="${POSTGRES_DB:-synapse}"
USER="${POSTGRES_USER:-synapse}"
SEED_DIR="src/test/resources/seed"

echo "=== Seeding test data into $DB ==="

for sql in "$SEED_DIR"/V*.sql; do
  filename=$(basename "$sql")
  echo "[SEED] Applying $filename ..."
  docker exec -i "$CONTAINER" psql -U "$USER" -d "$DB" < "$sql"
done

echo ""
echo "=== Seed complete. Verifying... ==="
echo ""

echo "[CHECK] platform.users:"
docker exec "$CONTAINER" psql -U "$USER" -d "$DB" -c \
  "SELECT id, email, tenant_id FROM platform.users WHERE id LIKE 'e2e-%';"

echo "[CHECK] knowledge.notes:"
docker exec "$CONTAINER" psql -U "$USER" -d "$DB" -c \
  "SELECT id, title, tenant_id FROM knowledge.notes WHERE id LIKE 'e2e-%';"

echo "[CHECK] learning.cards:"
docker exec "$CONTAINER" psql -U "$USER" -d "$DB" -c \
  "SELECT id, front, tenant_id FROM learning.cards WHERE id LIKE 'e2e-%';"

echo ""
echo "=== Done ==="
