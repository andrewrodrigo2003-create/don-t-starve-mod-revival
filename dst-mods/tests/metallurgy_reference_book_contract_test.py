from pathlib import Path

root = Path("dst-mods/metals_and_reforged")
actions = (root / "initialise/modded_actions.lua").read_text(encoding="utf-8")
module = (root / "scripts/mam/deconstruction.lua").read_text(encoding="utf-8")
prefab = (root / "scripts/prefabs/metallurgy_reference_book.lua").read_text(encoding="utf-8")
screen = (root / "scripts/screens/metallurgybookscreen.lua").read_text(encoding="utf-8")
modmain = (root / "modmain.lua").read_text(encoding="utf-8")

assert 'AddAction("MAM_DECONSTRUCT_METAL"' in actions
assert 'item.prefab == "warworkbench"' in actions
assert "can_fit_staged_outputs" in actions
assert 'BASE_RECOVERY = 0.75' in module
assert 'character == "wilson"' in module
assert 'character == "winona"' in module
assert 'character == "waxwell"' in module
assert 'simplebook' in prefab and 'components.simplebook.onreadfn' in prefab
assert 'smelting_products' in screen
assert 'metallurgy_reference_book' in modmain
assert 'AddRecipe2("metallurgy_reference_book"' in modmain
assert 'AddComponent("prototyper")' not in prefab
assert 'AddComponent("finiteuses")' not in prefab
print("PASS: deconstruction action and read-only guide wiring")
