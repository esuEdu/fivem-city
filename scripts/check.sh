#!/usr/bin/env bash
# Checks our own resources without a game server: Lua syntax, UI JavaScript syntax, locale JSON, and the unit tests in
# tests/<resource>/. Needs luajit (or lua) and python3; node is optional (JS check is skipped without it).
# Usage: bash scripts/check.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL="$ROOT/server-data/resources/[local]"
failed=0

LUA="$(command -v luajit || command -v lua || true)"
NODE="$(command -v node || ls "$HOME"/.nvm/versions/node/*/bin/node 2>/dev/null | tail -1 || true)"

if [ -z "$LUA" ]; then
  echo "luajit or lua is needed (brew install luajit / apt install luajit)" >&2
  exit 1
fi

echo "== Lua syntax"
lua=0
while IFS= read -r -d '' file; do
  # FiveM's backtick hashes aren't plain Lua: swap them for strings before compiling
  if ! "$LUA" - "$file" <<< "local s = io.open(arg[1]):read('*a'):gsub('\`([^\`]+)\`', '\"%1\"'); assert((loadstring or load)(s, '@' .. arg[1]))"; then
    failed=1
  fi
  lua=$((lua + 1))
done < <(find "$LOCAL" -name '*.lua' -not -path '*/node_modules/*' -print0)
echo "$lua files checked"

echo "== UI JavaScript"
js=0
if [ -n "$NODE" ]; then
  while IFS= read -r -d '' file; do
    "$NODE" --check "$file" || failed=1
    js=$((js + 1))
  done < <(find "$LOCAL" -path '*/web/*' -name '*.js' -print0)
  echo "$js files checked"
else
  echo "node not found, skipped"
fi

echo "== Locale JSON"
while IFS= read -r -d '' file; do
  python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$file" || { echo "invalid JSON: $file"; failed=1; }
done < <(find "$LOCAL" -path '*/locales/*' -name '*.json' -print0)

echo "== Unit tests"
for dir in "$ROOT"/tests/*/; do
  resource="$(basename "$dir")"

  for test in "$dir"*.lua; do
    [ "$(basename "$test")" = harness.lua ] && continue

    if output="$(cd "$dir" && "$LUA" "$(basename "$test")" "$LOCAL/$resource" 2>&1)"; then
      echo "ok   $resource/$(basename "$test")"
    else
      echo "FAIL $resource/$(basename "$test")"
      echo "$output" | tail -5
      failed=1
    fi
  done
done

if [ "$failed" -ne 0 ]; then
  echo "Checks failed" >&2
  exit 1
fi

echo "All checks passed"
