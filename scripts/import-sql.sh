#!/usr/bin/env bash
# Creates the database tables the vendored resources need, in the MariaDB container of docker-compose.yml.
# Docker imports qbx_core.sql only when the database volume is first created, so run this after a fresh
# start and whenever resources with new tables are added. Safe to re-run: errors about tables or columns
# that already exist are skipped (--force) and no data is deleted.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="$ROOT/server-data/resources"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/docker-compose.yml}"

# Same order as the Qbox txAdmin recipe, plus qbx_properties' tables
FILES=(
  "$ROOT/server-data/sql/qbox.sql"
  "$RES/[qbx]/qbx_core/qbx_core.sql"
  "$RES/[qbx]/qbx_vehicles/vehicles.sql"
  "$RES/[qbx]/qbx_properties/property.sql"
  "$RES/[qbx]/qbx_properties/decorations.sql"
  "$RES/[qbx]/qbx_properties/property_garages.sql"
)

env_value() {
  grep -E "^$1=" "$ROOT/.env" | tail -n 1 | cut -d= -f2- | tr -d '\r'
}

PASSWORD="$(env_value MYSQL_ROOT_PASSWORD)"
DATABASE="$(env_value MYSQL_DATABASE)"

for file in "${FILES[@]}"; do
  echo "-> ${file#"$ROOT"/}"
  docker compose -f "$COMPOSE_FILE" exec -T -e MYSQL_PWD="$PASSWORD" mariadb \
    mariadb --force -uroot "${DATABASE:-fivem_city}" < "$file" || true
done

echo "Done. Restart the server so the resources see the new tables."
