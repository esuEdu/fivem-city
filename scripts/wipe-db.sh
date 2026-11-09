#!/usr/bin/env bash
# Wipes everything players made (characters, items, money, cars, records, phone data, job progress) from the MariaDB
# container of docker-compose.yml, for a fresh test round. Server setup stays: bans, staff log and warnings, Builder
# props, mining points, doors, job outfits and houses. A full dump is saved in backups/ first.
#
# Usage: bash scripts/wipe-db.sh          (asks you to type WIPE)
#        bash scripts/wipe-db.sh --yes    (no question, for scripts)
#
# fxserver is stopped during the wipe and started again at the end. city_economy recreates its system accounts on start.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/docker-compose.yml}"

# Tables that are server setup, not player data
KEEP=(
  bans
  users
  city_staff_log
  city_staff_warnings
  city_builder_groups
  city_builder_hides
  city_builder_props
  city_mining_points
  ox_doorlock
  management_outfits
  properties
  properties_decorations
)

env_value() {
  grep -E "^$1=" "$ROOT/.env" | tail -n 1 | cut -d= -f2- | tr -d '\r'
}

PASSWORD="$(env_value MYSQL_ROOT_PASSWORD)"
DATABASE="$(env_value MYSQL_DATABASE)"
DATABASE="${DATABASE:-fivem_city}"

sql() {
  docker compose -f "$COMPOSE_FILE" exec -T -e MYSQL_PWD="$PASSWORD" mariadb mariadb -uroot -N "$DATABASE" "$@"
}

keep_list=""
for table in "${KEEP[@]}"; do keep_list="$keep_list,'$table'"; done
keep_list="${keep_list#,}"

TABLES="$(sql -e "SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE' AND table_name NOT IN ($keep_list) ORDER BY table_name")"

if [ -z "$TABLES" ]; then
  echo "Nothing to wipe in $DATABASE."
  exit 0
fi

echo "These tables in '$DATABASE' will be emptied:"
echo "$TABLES" | tr '\n' ' ' | fold -s -w 100
echo
echo
echo "Kept: ${KEEP[*]}"

if [ "${1:-}" != "--yes" ]; then
  read -r -p "Type WIPE to continue: " answer
  [ "$answer" = "WIPE" ] || { echo "Cancelled."; exit 1; }
fi

mkdir -p "$ROOT/backups"
BACKUP="$ROOT/backups/before-wipe-$(date +%Y%m%d-%H%M%S).sql"
echo "-> Backup: ${BACKUP#"$ROOT"/}"
docker compose -f "$COMPOSE_FILE" exec -T -e MYSQL_PWD="$PASSWORD" mariadb mariadb-dump -uroot "$DATABASE" > "$BACKUP"

echo "-> Stopping fxserver"
docker compose -f "$COMPOSE_FILE" stop fxserver

statements="SET FOREIGN_KEY_CHECKS = 0;"
while IFS= read -r table; do
  [ -n "$table" ] && statements="$statements TRUNCATE TABLE \`$table\`;"
done <<< "$TABLES"
statements="$statements SET FOREIGN_KEY_CHECKS = 1;"

echo "-> Wiping"
sql -e "$statements"

echo "-> Starting fxserver"
docker compose -f "$COMPOSE_FILE" start fxserver

echo "Done. To undo: docker compose exec -T mariadb sh -c 'mariadb -uroot -p\"\$MARIADB_ROOT_PASSWORD\" \"\$MARIADB_DATABASE\"' < ${BACKUP#"$ROOT"/}"
