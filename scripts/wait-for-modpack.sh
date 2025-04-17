#!/bin/sh
set -e

READY_FILE="/modpack/.ready-${SERVER_WORLDNAME}"

echo "[wait-for-modpack] Waiting for modpack install for world: $SERVER_WORLDNAME"

while [ ! -f "$READY_FILE" ]; do
  sleep 1
done

echo "[wait-for-modpack] Modpack is ready. Starting Minecraft..."
exec /start
