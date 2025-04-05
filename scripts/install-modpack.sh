#!/bin/sh
set -e

# Install tools if needed
apk add --no-cache jq wget unzip > /dev/null

MODPACK_DIR=/modpack
TEMP_DIR="$MODPACK_DIR/temp"
MRPACK_PATH="$MODPACK_DIR/pack.mrpack"
READY_FILE="$MODPACK_DIR/.ready-${SERVER_WORLDNAME}"
DATA_DIR=/data

# Skip if already done
if [ -f "$READY_FILE" ]; then
  echo "✅ Modpack already installed for world: $SERVER_WORLDNAME"
  exit 0
fi

cd "$MODPACK_DIR"

echo "Cleaning modpack install directories..."
rm -rf "$TEMP_DIR" "$MODPACK_DIR/mods"
mkdir -p "$TEMP_DIR" "$MODPACK_DIR/mods"

echo "Downloading modpack from $MODRINTH_URL..."
wget -q -O "$MRPACK_PATH" "$MODRINTH_URL"

echo "Extracting .mrpack..."
unzip -q "$MRPACK_PATH" -d "$TEMP_DIR"

# Detect index file
INDEX_JSON="$TEMP_DIR/modrinth.index.json"
[ ! -f "$INDEX_JSON" ] && INDEX_JSON="$TEMP_DIR/index.json"

if [ ! -f "$INDEX_JSON" ]; then
  echo "❌ ERROR: No index file (modrinth.index.json or index.json) found!"
  exit 1
fi

echo "Using index file: $(basename "$INDEX_JSON")"
echo "Downloading server-required mods..."

# Filter: exclude known client-only mods even if marked "server: required"
CLIENT_ONLY_MODS="cobblemon-ui-tweaks|interactic"

jq -c '.files[] | select(.env.server == "required")' "$INDEX_JSON" | while read -r entry; do
  FILE_PATH=$(echo "$entry" | jq -r '.path')

  if echo "$FILE_PATH" | grep -Eiq "$CLIENT_ONLY_MODS"; then
    echo "❌ Skipping client-only mod: $FILE_PATH"
    continue
  fi

  FILE_URL=$(echo "$entry" | jq -r '.downloads[0]')
  DEST_PATH="$MODPACK_DIR/$FILE_PATH"

  if [ -n "$FILE_URL" ]; then
    echo "✅ Downloading: $FILE_PATH"
    mkdir -p "$(dirname "$DEST_PATH")"
    wget -q -O "$DEST_PATH" "$FILE_URL"
  else
    echo "⚠️  WARNING: No URL found for $FILE_PATH"
  fi
done

# Copy optional override folders
[ -d "$TEMP_DIR/overrides/config" ] && cp -r "$TEMP_DIR/overrides/config" "$MODPACK_DIR/config" && echo "📁 Copied config folder."
[ -d "$TEMP_DIR/overrides/resourcepacks" ] && cp -r "$TEMP_DIR/overrides/resourcepacks" "$MODPACK_DIR/resourcepacks" && echo "📁 Copied resourcepacks folder."
[ -d "$TEMP_DIR/overrides/datapacks" ] && cp -r "$TEMP_DIR/overrides/datapacks" "$MODPACK_DIR/datapacks" && echo "📁 Copied datapacks folder."

echo "📦 Copying mods to /data/mods..."
mkdir -p "$DATA_DIR/mods"
rm -rf "$DATA_DIR/mods/*"
cp -r "$MODPACK_DIR/mods/"* "$DATA_DIR/mods/"

echo "✅ Modpack install complete for world: $SERVER_WORLDNAME"
echo "📚 Downloaded $(find "$MODPACK_DIR/mods" -name '*.jar' | wc -l) mod JARs."
touch "$READY_FILE"

tree -a -F > file_structure.txt
