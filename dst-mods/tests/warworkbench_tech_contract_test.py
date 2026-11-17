from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MOD = ROOT / "dst-mods" / "metals_and_reforged"

main = (MOD / "modmain.lua").read_text(encoding="utf-8")
bench = (MOD / "scripts" / "prefabs" / "warworkbench.lua").read_text(encoding="utf-8")

assert 'require("mam/tech").Register()' in main
assert "recipe.level.MAM_FORGE = 0" in main
assert "TUNING.PROTOTYPER_TREES.MAM_FORGE_ONE" in bench

forge_recipes = (
    "jagged_armor",
    "tfwp_luxury_nox_helm_hat",
    "halberd",
    "scepter",
    "forkstick",
    "donharpoon",
    "forginghammer",
    "pithpike",
    "spiralspear",
    "blacksmith_edge",
    "forginghammerold",
    "pithpikeold",
    "blacksmith_edgeold",
)
for name in forge_recipes:
    recipe_line = next((line for line in main.splitlines() if f'AddRecipe2("{name}"' in line), None)
    assert recipe_line is not None, f"Missing recipe registration: {name}"
    assert "TECH.MAM_FORGE_ONE" in recipe_line, f"{name} must require the War Workbench"
    assert "TECH.ALCHEMY_ONE" not in recipe_line, f"{name} must not remain craftable at the Alchemy Engine"

assert 'AddRecipe2("warworkbench"' in main and "TECH.SCIENCE_TWO" in next(
    line for line in main.splitlines() if 'AddRecipe2("warworkbench"' in line
)
book_lines = main.splitlines()
book_start = next(i for i, line in enumerate(book_lines) if 'AddRecipe2("metallurgy_reference_book"' in line)
book_block = "\\n".join(book_lines[book_start:book_start + 6])
assert "TECH.ALCHEMY_ONE" in book_block

print("War Workbench recipe contract: all MAM metal weapons/armor are station-gated")
