#!/usr/bin/env bash
# Writes scripts/patches/<resource>.patch with ALL our changes to a vendored resource (upstream -> working tree), so
# install-resources.sh can re-apply them after an update. The committed copy already includes the old patch, so a plain
# `git diff` would only hold the new changes: this rebuilds the full patch on a clean checkout instead.
# Usage: bash scripts/make-patch.sh "server-data/resources/[qbx]/qbx_medical"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RES="${1:?Usage: bash scripts/make-patch.sh \"server-data/resources/[group]/<resource>\"}"
RES="${RES%/}"
NAME="$(basename "$RES")"
PATCH="scripts/patches/$NAME.patch"

if [ ! -d "$RES" ]; then
  echo "No such folder: $RES" >&2
  exit 1
fi

case "$RES" in
  *"[local]"*) echo "$RES is our own resource: edit it directly, no patch needed" >&2; exit 1 ;;
esac

TMP="$(mktemp -d)"
trap 'git worktree remove --force "$TMP" >/dev/null 2>&1 || rm -rf "$TMP"' EXIT

# A clean copy of the last commit: upstream + the current patch
git worktree add -q --detach "$TMP" HEAD

# Back to plain upstream, kept as a throwaway commit in the temporary checkout to diff against
if [ -f "$PATCH" ]; then
  git -C "$TMP" apply -R "$ROOT/$PATCH"
  git -C "$TMP" add -A -- "$RES"
  git -C "$TMP" -c user.name=make-patch -c user.email=make-patch@local commit -q --no-verify -m upstream
fi

# Bring in the edited files; the diff from upstream is the whole patch
rm -rf "${TMP:?}/$RES"
mkdir -p "$(dirname "$TMP/$RES")"
cp -R "$RES" "$TMP/$RES"
git -C "$TMP" add -A -- "$RES"
git -C "$TMP" diff --cached -- "$RES" > "$PATCH"

if [ ! -s "$PATCH" ]; then
  rm -f "$PATCH"
  echo "No changes from upstream in $RES: removed $PATCH"
  exit 0
fi

# The working tree is upstream + the patch, so undoing it must apply cleanly
git apply -R --check "$PATCH"
echo "Wrote $PATCH ($(grep -c '^diff --git' "$PATCH") files)"
