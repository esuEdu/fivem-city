#!/usr/bin/env bash
# Downloads the third-party resources the server depends on into resources/.
# Re-run to update everything to the latest release.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="$ROOT/resources"
TMP="$ROOT/.tmp"

mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

# name|target group|release zip url
RELEASES=(
  "oxmysql|[ox]|https://github.com/communityox/oxmysql/releases/latest/download/oxmysql.zip"
  "ox_lib|[ox]|https://github.com/communityox/ox_lib/releases/latest/download/ox_lib.zip"
  "ox_target|[ox]|https://github.com/communityox/ox_target/releases/latest/download/ox_target.zip"
  "ox_inventory|[ox]|https://github.com/communityox/ox_inventory/releases/latest/download/ox_inventory.zip"
  "qbx_core|[qbx]|https://github.com/Qbox-project/qbx_core/releases/latest/download/qbx_core.zip"
)

# name|target group|git repo
REPOS=(
  "pma-voice|[voice]|https://github.com/AvarianKnight/pma-voice.git"
)

install_release() {
  local name="$1" group="$2" url="$3"
  echo "-> $name"
  curl -fsSL "$url" -o "$TMP/$name.zip"
  rm -rf "$RES/$group/$name"
  mkdir -p "$RES/$group"
  unzip -q "$TMP/$name.zip" -d "$RES/$group"
}

install_repo() {
  local name="$1" group="$2" repo="$3"
  echo "-> $name"
  rm -rf "$RES/$group/$name"
  mkdir -p "$RES/$group"
  git clone -q --depth 1 "$repo" "$RES/$group/$name"
  rm -rf "$RES/$group/$name/.git"
}

# Default cfx resources (chat, spawnmanager, mapmanager, ...)
echo "-> cfx-server-data"
git clone -q --depth 1 https://github.com/citizenfx/cfx-server-data.git "$TMP/cfx-server-data"
rm -rf "$RES/[cfx-default]"
cp -R "$TMP/cfx-server-data/resources" "$RES/[cfx-default]"

for entry in "${RELEASES[@]}"; do
  IFS='|' read -r name group url <<< "$entry"
  install_release "$name" "$group" "$url"
done

for entry in "${REPOS[@]}"; do
  IFS='|' read -r name group repo <<< "$entry"
  install_repo "$name" "$group" "$repo"
done

echo "Done. Import resources/[qbx]/qbx_core/qbx_core.sql into your database if this is a fresh install."
