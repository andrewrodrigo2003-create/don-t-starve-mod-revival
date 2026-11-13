from pathlib import Path

root = Path("dst-mods/metals_and_reforged")
actions = (root / "initialise/modded_actions.lua").read_text(encoding="utf-8")
module = (root / "scripts/mam/deconstruction.lua").read_text(encoding="utf-8")
prefab = (root / "scripts/prefabs/metallurgy_reference_book.lua").read_text(encoding="utf-8")
screen = (root / "scripts/screens/metallurgybookscreen.lua").read_text(encoding="utf-8")
screen = (root / "scripts/screens/metallurgybookscreen.lua").read_text(encoding="utf-8")
modmain = (root / "modmain.lua").read_text(encoding="utf-8")
recipes = (root / "initialise/modded_recipes.lua").read_text(encoding="utf-8")
actions = (root / "initialise/modded_actions.lua").read_text(encoding="utf-8")

assert 'AddAction("MAM_DECONSTRUCT_METAL"' in actions
assert 'entity.prefab == "warworkbench"' in actions
assert "recipe.max_batch" in screen
assert "Max input batch" in screen
assert "can_fit_staged_outputs" in actions
assert 'BASE_RECOVERY = 0.75' in module
assert 'wilson = { all = 1 }' in module
assert 'winona = { nonmagical = 1 }' in module
assert 'waxwell = { shadow = 1 }' in module
assert 'local function character_rate(character, material)' in module
assert 'return MAMDeconstruction.BASE_RECOVERY' in module
assert 'simplebook' in prefab and 'components.simplebook.onreadfn' in prefab
assert 'smelting_products' in screen
assert 'metallurgy_reference_book' in modmain
assert 'AddRecipe2("metallurgy_reference_book"' in modmain
assert 'AddComponent("prototyper")' not in prefab
assert 'AddComponent("finiteuses")' not in prefab

assert 'MAMRecipeGuard.set_station(name, TECH.ALCHEMY_ONE, "CRAFTING_STATION")' in recipes
for name in (
    "birdcage", "dragonflychest", "compass", "razor", "lightning_rod",
    "goldenaxe", "goldenpickaxe", "goldenshovel", "golden_farm_hoe",
    "armormarble", "armordragonfly", "ruinshat", "armorruins",
    "multitool_axe_pickaxe", "winterometer", "rainometer", "nightlight",
    "portablecookpot_item", "portableblender_item", "portablespicer_item",
    "glasscutter", "archive_resonator_item", "moondial", "moonrockcrater",
    "moonglassaxe",
):
    assert f'"{name}"' in recipes, f"metal recipe not migrated to War Bench: {name}"
# These are crafted products, equipment, tools or structures, not raw MAM
# materials. Their recipes may be migrated to the War Bench, but they must
# never become eligible for the material-only deconstruction action.
for name in (
    "birdcage", "dragonflychest", "compass", "razor", "lightning_rod",
    "goldenaxe", "goldenpickaxe", "goldenshovel", "golden_farm_hoe",
    "armormarble", "armordragonfly", "ruinshat", "armorruins",
    "multitool_axe_pickaxe", "winterometer", "rainometer", "nightlight",
    "portablecookpot_item", "portableblender_item", "portablespicer_item",
    "glasscutter", "archive_resonator_item", "moondial", "moonrockcrater",
    "moonglassaxe",
):
    assert f"    {name} = {{" not in module, f"non-material must remain unsupported: {name}"
assert 'if plan == nil then' in actions
assert 'if plan == nil or #plan == 0 then' not in actions, "zero-return roll must consume the input"

print("PASS: deconstruction action and read-only guide wiring")
