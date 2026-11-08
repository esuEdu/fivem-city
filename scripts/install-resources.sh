#!/usr/bin/env bash
# Downloads the third-party resources the server depends on into resources/.
# Re-run to update everything to the latest release.
# The list follows the Qbox txAdmin recipe (github.com/Qbox-project/txAdminRecipe, qbox.yaml),
# without ox_inventory (city_inventory replaces it) and Renewed-Banking (city_economy + city_bank replace it).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="$ROOT/server-data/resources"
TMP="$ROOT/.tmp"

mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

# name|target group|release zip url (the zip holds a folder called <name>)
RELEASES=(
  "oxmysql|[ox]|https://github.com/communityox/oxmysql/releases/latest/download/oxmysql.zip"
  "ox_lib|[ox]|https://github.com/communityox/ox_lib/releases/latest/download/ox_lib.zip"
  "ox_target|[ox]|https://github.com/communityox/ox_target/releases/latest/download/ox_target.zip"
  "ox_doorlock|[ox]|https://github.com/overextended/ox_doorlock/releases/latest/download/ox_doorlock.zip"
  "qbx_core|[qbx]|https://github.com/Qbox-project/qbx_core/releases/latest/download/qbx_core.zip"
  "screencapture|[standalone]|https://github.com/itschip/screencapture/releases/latest/download/screencapture.zip"
  "illenium-appearance|[standalone]|https://github.com/iLLeniumStudios/illenium-appearance/releases/latest/download/illenium-appearance.zip"
  "Renewed-Weathersync|[standalone]|https://github.com/Renewed-Scripts/Renewed-Weathersync/releases/latest/download/Renewed-Weathersync.zip"
  "vehiclehandler|[standalone]|https://github.com/QuantumMalice/vehiclehandler/releases/latest/download/vehiclehandler.zip"
  "loadscreen|[standalone]|https://github.com/D4isDAVID/loadscreen/releases/latest/download/loadscreen.zip"
  "mana_audio|[standalone]|https://github.com/Manason/mana_audio/releases/latest/download/mana_audio.zip"
  "mm_radio|[voice]|https://github.com/qbox-project/mm_radio/releases/latest/download/mm_radio.zip"
)

# name|target group|git repo
REPOS=(
  "pma-voice|[voice]|https://github.com/AvarianKnight/pma-voice.git"
  "ox_fuel|[ox]|https://github.com/overextended/ox_fuel.git"
  "bob74_ipl|[standalone]|https://github.com/Bob74/bob74_ipl.git"
  "safecracker|[standalone]|https://github.com/qbox-project/safecracker.git"
  "mhacking|[standalone]|https://github.com/qbox-project/mhacking.git"
  "scully_emotemenu|[standalone]|https://github.com/Scullyy/scully_emotemenu.git"
  "ultra-voltlab|[standalone]|https://github.com/ultrahacx/ultra-voltlab.git"
  "MugShotBase64|[standalone]|https://github.com/BaziForYou/MugShotBase64.git"
  "pillbox|[assets]|https://github.com/Lorenc95/pillbox.git"
)

# Qbox resources, all from github.com/Qbox-project/<name>, into [qbx]
QBX_REPOS=(
  qbx_vehicles qbx_scoreboard qbx_vehiclesales qbx_houserobbery
  qbx_hud qbx_seatbelt qbx_management qbx_weed qbx_lapraces
  qbx_medical qbx_radialmenu qbx_properties qbx_vehiclekeys qbx_mechanicjob
  qbx_vineyard qbx_scrapyard qbx_towjob qbx_streetraces qbx_storerobbery qbx_spawn
  qbx_smallresources qbx_recyclejob qbx_diving qbx_divegear qbx_cityhall qbx_truckrobbery
  qbx_pawnshop qbx_taxijob qbx_busjob qbx_newsjob qbx_jewelery qbx_bankrobbery qbx_truckerjob
  qbx_garbagejob qbx_drugs qbx_idcard qbx_binoculars qbx_carwash qbx_fireworks qbx_density
  qbx_customs qbx_chat_theme
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

# Default cfx resources (spawnmanager, mapmanager, ...). FXServer's built-in chat replaces the old chat resource.
echo "-> cfx-server-data"
git clone -q --depth 1 https://github.com/citizenfx/cfx-server-data.git "$TMP/cfx-server-data"
rm -rf "$RES/[cfx-default]"
cp -R "$TMP/cfx-server-data/resources" "$RES/[cfx-default]"
rm -rf "$RES/[cfx-default]/[gameplay]/chat"

for entry in "${RELEASES[@]}"; do
  IFS='|' read -r name group url <<< "$entry"
  install_release "$name" "$group" "$url"
done

for entry in "${REPOS[@]}"; do
  IFS='|' read -r name group repo <<< "$entry"
  install_repo "$name" "$group" "$repo"
done

for name in "${QBX_REPOS[@]}"; do
  install_repo "$name" "[qbx]" "https://github.com/Qbox-project/$name.git"
done

# The recipe's own tables (appearance, banking, mail, doorlock), imported by scripts/import-sql.sh
echo "-> txAdminRecipe qbox.sql"
git clone -q --depth 1 https://github.com/Qbox-project/txAdminRecipe.git "$TMP/txAdminRecipe"
mkdir -p "$ROOT/server-data/sql"
cp "$TMP/txAdminRecipe/qbox.sql" "$ROOT/server-data/sql/qbox.sql"

# Same follow-up steps as the recipe
MUGSHOT="$RES/[standalone]/MugShotBase64"
mv "$MUGSHOT/MugShotBase64" "$TMP/MugShotBase64"
mv "$MUGSHOT/README.md" "$MUGSHOT/LICENSE.md" "$TMP/MugShotBase64/"
rm -rf "$MUGSHOT"
mv "$TMP/MugShotBase64" "$MUGSHOT"
cp "$ROOT/server-data/logo.png" "$RES/[standalone]/loadscreen/html/assets/logo.png"

# Item images from Qbox, added next to city_inventory's own (ours win on a name clash)
echo "-> qbx_invimages"
git clone -q --depth 1 https://github.com/Qbox-project/qbx_invimages.git "$TMP/qbx_invimages"
for image in "$TMP"/qbx_invimages/images/*.png; do
  target="$RES/[local]/city_inventory/web/images/$(basename "$image" | tr '[:upper:]' '[:lower:]')"
  [ -e "$target" ] || cp "$image" "$target"
done

# Local changes to third-party resources (e.g. qbx_core uses city_inventory instead of ox_inventory)
for patch in "$ROOT"/scripts/patches/*.patch; do
  echo "-> patch $(basename "$patch")"
  git -C "$ROOT" apply "$patch" || {
    echo "Could not apply $patch: the resource changed upstream. Update the patch by hand." >&2
    exit 1
  }
done

echo "Done. On an existing database, run scripts/import-sql.sh to create the tables these resources need."
