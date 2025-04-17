#!/bin/sh
set -e

# ---- install-modpack.sh ---------------------------------------------------
# Installs a Modrinth .mrpack into /modpack, copies the server‑side bits into
# /data, fixes permissions so the MC runtime user can read everything, and
# marks completion with a world‑specific .ready flag.
# ---------------------------------------------------------------------------

apk add --no-cache jq wget unzip rsync > /dev/null

MODPACK_DIR=/modpack
TEMP_DIR="$MODPACK_DIR/temp"
MRPACK_PATH="$MODPACK_DIR/pack.mrpack"
READY_FILE="$MODPACK_DIR/.ready-${SERVER_WORLDNAME}"
DATA_DIR=/data

MC_UID=${MC_UID:-1000}
MC_GID=${MC_GID:-1000}

# ---------------------------------------------------------------------------
# Early‑exit if this world was already prepared
# ---------------------------------------------------------------------------
if [ -f "$READY_FILE" ]; then
  echo "✅ Modpack already installed for world: $SERVER_WORLDNAME"
  exit 0
fi

cd "$MODPACK_DIR"

echo "🧹 Cleaning previous temp / mods folders…"
rm -rf "$TEMP_DIR" "$MODPACK_DIR/mods"
mkdir -p "$TEMP_DIR" "$MODPACK_DIR/mods"

echo "⬇️  Downloading modpack from $MODRINTH_URL…"
wget -q -O "$MRPACK_PATH" "$MODRINTH_URL"

echo "📦 Extracting .mrpack…"
unzip -q "$MRPACK_PATH" -d "$TEMP_DIR"

# Detect the pack index
INDEX_JSON="$TEMP_DIR/modrinth.index.json"
[ ! -f "$INDEX_JSON" ] && INDEX_JSON="$TEMP_DIR/index.json"

if [ ! -f "$INDEX_JSON" ]; then
  echo "❌ ERROR: No index file (modrinth.index.json / index.json) found!"
  exit 1
fi

echo "📖 Using index file: $(basename "$INDEX_JSON")"
echo "🔗 Downloading server‑side mods…"

# Skip obvious client‑only jars even if the index marks them as server‑required
CLIENT_ONLY_MODS="cobblemon-ui-tweaks|interactic|ferritecore"

jq -c '.files[] | select(.env.server == "required")' "$INDEX_JSON" | while read -r entry; do
  FILE_PATH=$(echo "$entry" | jq -r '.path')

  if echo "$FILE_PATH" | grep -Eiq "$CLIENT_ONLY_MODS"; then
    echo "🚫 Skipping client‑only mod: $FILE_PATH"
    continue
  fi

  FILE_URL=$(echo "$entry" | jq -r '.downloads[0]')
  DEST_PATH="$MODPACK_DIR/$FILE_PATH"

  if [ -n "$FILE_URL" ]; then
    echo "   • $FILE_PATH"
    mkdir -p "$(dirname "$DEST_PATH")"
    wget -q -O "$DEST_PATH" "$FILE_URL"
  else
    echo "⚠️  No URL found for $FILE_PATH – skipped"
  fi
done

echo "✅ Finished downloading mods."

# ---------------------------------------------------------------------------
# Copy override folders from the pack
# ---------------------------------------------------------------------------
copy_override() {
  local SRC="$1" DST="$2" LABEL="$3"
  if [ -d "$SRC" ]; then
    echo "📁 Copying $LABEL override…"
    rsync -a "$SRC/" "$DST/"
  fi
}

copy_override "$TEMP_DIR/overrides/config"        "$MODPACK_DIR/config"        "config"
copy_override "$TEMP_DIR/overrides/resourcepacks" "$MODPACK_DIR/resourcepacks" "resourcepacks"

# Datapacks need special handling so we *never* create a nested datapacks/datapacks
if [ -d "$TEMP_DIR/overrides/datapacks" ]; then
  echo "📁 Copying datapacks override (flattened)…"
  mkdir -p "$MODPACK_DIR/datapacks"
  rsync -a "$TEMP_DIR/overrides/datapacks/" "$MODPACK_DIR/datapacks/"
fi

# ---------------------------------------------------------------------------
# Helper to squash accidental extra level of nesting
# ---------------------------------------------------------------------------
flatten_dp() {
  local TARGET="$1"
  if [ -d "$TARGET/datapacks" ]; then
    echo "⚙️  Flattening nested datapacks in $TARGET"
    rsync -a "$TARGET/datapacks/" "$TARGET/"
    rm -rf "$TARGET/datapacks"
  fi
}

# Flatten at source so every downstream copy inherits the fix
flatten_dp "$MODPACK_DIR"

# Remove macOS metadata files that pollute logs
find "$MODPACK_DIR/datapacks" -name '.DS_Store' -delete 2>/dev/null || true

# ---------------------------------------------------------------------------
# Push assets into live server directories
# ---------------------------------------------------------------------------
echo "🚚 Copying mods into live server dir…"
mkdir -p "$DATA_DIR/mods"
rm -rf "$DATA_DIR/mods"/*
rsync -a "$MODPACK_DIR/mods/" "$DATA_DIR/mods/"

echo "🚚 Copying configs…"
mkdir -p "$DATA_DIR/config"
rsync -a --ignore-existing "$MODPACK_DIR/config/" "$DATA_DIR/config/" 2>/dev/null || true

echo "🚚 Copying global datapacks…"
mkdir -p "$DATA_DIR/datapacks"
rsync -a "$MODPACK_DIR/datapacks/" "$DATA_DIR/datapacks/" 2>/dev/null || true
flatten_dp "$DATA_DIR/datapacks"
find "$DATA_DIR/datapacks" -name '.DS_Store' -delete 2>/dev/null || true

echo "🚚 Copying per‑world datapacks…"
WORLD_DP="$DATA_DIR/${SERVER_WORLDNAME}/datapacks"
mkdir -p "$WORLD_DP"
rsync -a "$MODPACK_DIR/datapacks/" "$WORLD_DP/" 2>/dev/null || true
flatten_dp "$WORLD_DP"
find "$WORLD_DP" -name '.DS_Store' -delete 2>/dev/null || true

# ---------------------------------------------------------------------------
# Permissions – cover *both* /data *and* /modpack so Fabric can read packs
# ---------------------------------------------------------------------------
echo "🔒 Fixing permissions to ${MC_UID}:${MC_GID} …"
chown -R "${MC_UID}:${MC_GID}" /data /modpack
chmod -R u+rwX,go+rX /data /modpack

# ---------------------------------------------------------------------------
# Diagnostics – optional tree snapshot
# ---------------------------------------------------------------------------
if command -v tree >/dev/null 2>&1; then
  tree -a -F > "$MODPACK_DIR/file_structure.txt"
  tree -a --dirsfirst -L 4 > "$MODPACK_DIR/folder_tree.txt"
fi

echo "🎉 Modpack install complete for world: $SERVER_WORLDNAME – $(find "$MODPACK_DIR/mods" -name '*.jar' | wc -l) mod jars ready."

# --- Enable spawn‑debug on first install ------------------------------------
CFG=/data/config/cobblemon/main.json
jq '.exportSpawnConfig = true' "$CFG" | sponge "$CFG"
echo "🔧   Set exportSpawnConfig=true (will generate Best‑Spawner config on first boot)"


touch "$READY_FILE"
