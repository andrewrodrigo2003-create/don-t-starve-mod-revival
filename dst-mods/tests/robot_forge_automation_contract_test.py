from pathlib import Path

root = Path("dst-mods/metals_and_reforged")
modinfo = (root / "modinfo.lua").read_text(encoding="utf-8")
config = (root / "scripts/mam/config.lua").read_text(encoding="utf-8")
component = (root / "scripts/components/smelter.lua").read_text(encoding="utf-8")
prefab = (root / "scripts/prefabs/metal_smelter.lua").read_text(encoding="utf-8")

assert 'name = "mam_robot_smelting"' in modinfo
assert 'default = 0' in modinfo[modinfo.index('name = "mam_robot_smelting"'):]
assert 'mam_robot_smelting   = 0' in config
assert 'mam_robot_smelting' in config[config.index('local ALLOWED'):]

assert 'has_active_collector_robot' in component
assert '"storagerobot"' in component
assert 'robot.prefab ~= "winona_storage_robot"' in component
assert 'smelting.IsSmelterIngredient(item.prefab)' in component
assert 'container.type == "chest" or container.type == "pack"' in component
assert 'TryStartRobotBatch' in component
assert 'TryAutoHarvestToStorage' in component
assert 'CanAcceptCount(template, remaining)' in component
assert 'self:StartSmelting(nil, local_plan)' in component
assert 'GetNearby' not in component
assert 'TryAutoHarvestToStorage()' in prefab
print("PASS: opt-in robot-fed smelting and output storage contracts")
