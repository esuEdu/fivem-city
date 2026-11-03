#!/bin/bash
# Writes server-data/secrets.cfg from environment variables, then starts FXServer.
# When secrets.cfg is mounted from the host (local dev) and CFX_LICENSE_KEY is
# not set, the existing file is used as-is.
set -euo pipefail

SECRETS=/server-data/secrets.cfg

if [ -n "${CFX_LICENSE_KEY:-}" ]; then
  : "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
  cat > "$SECRETS" <<EOF
sv_licenseKey "${CFX_LICENSE_KEY}"
set steam_webApiKey "${STEAM_WEBAPIKEY:-none}"
set mysql_connection_string "mysql://root:${MYSQL_ROOT_PASSWORD}@${MYSQL_HOST:-mariadb}:3306/${MYSQL_DATABASE:-fivem_city}?charset=utf8mb4"
EOF
elif [ ! -f "$SECRETS" ]; then
  echo "No secrets: set CFX_LICENSE_KEY and MYSQL_ROOT_PASSWORD, or mount server-data/secrets.cfg" >&2
  exit 1
fi

exec bash /opt/fxserver/run.sh "$@"
