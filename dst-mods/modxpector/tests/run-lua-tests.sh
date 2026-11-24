#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
LUA_BIN="${LUA_BIN:-lua5.1}"
export DST_RUNTIME_ROOT="$ROOT"
for test_file in \
  dst-mods/modxpector/tests/test_modxpector_embedded_ai.lua \
  dst-mods/modxpector/tests/test_modxpector_world_inventory.lua \
  dst-mods/modxpector/tests/test_modxpector_runtime_observer.lua \
  dst-mods/modxpector/tests/test_modxpector_community_events.lua \
  dst-mods/modxpector/tests/test_modxpector_config.lua \
  dst-mods/modxpector/tests/test_modxpector_current_modules.lua \
  dst-mods/modxpector/tests/test_modxpector_ui_static.lua \
  dst-mods/modxpector/tests/test_modxpector_mod_bootstrap.lua \
  dst-mods/modxpector/tests/test_modxpector_virtual_player_live.lua \
  dst-mods/modxpector/tests/test_modxpector_virtual_player_attack_repeat.lua
do
  echo "== $test_file =="
  "$LUA_BIN" "$test_file"
done
