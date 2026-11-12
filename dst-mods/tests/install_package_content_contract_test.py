from pathlib import Path
import sys
import zipfile


archive = Path(sys.argv[1])
required = {
    "metals_and_reforged/modinfo.lua",
    "metals_and_reforged/modmain.lua",
    "metals_and_reforged/modicon.tex",
    "metals_and_reforged/modicon.xml",
    "metals_and_reforged/images/branding/metals_and_more_reforged_icon.png",
    "metals_and_reforged/scripts/prefabs/metal_smelter.lua",
    "metals_and_reforged/scripts/prefabs/metal_storage_chest.lua",
    "metals_and_reforged/scripts/prefabs/metallurgy_reference_book.lua",
    "metals_and_reforged/scripts/screens/metallurgybookscreen.lua",
    "metals_and_reforged/scripts/mam/deconstruction.lua",
    "metals_and_reforged/initialise/modded_ui_forecast.lua",
}
with zipfile.ZipFile(archive) as package:
    names = set(package.namelist())
    missing = sorted(required - names)
    assert not missing, f"install package is missing required files: {missing}"
    leaked = sorted(name for name in names if name.startswith("metals_and_reforged/tests/"))
    assert not leaked, f"test-only files leaked into install package: {leaked}"
    modinfo = package.read("metals_and_reforged/modinfo.lua").decode("utf-8")
    assert 'version = "2.9.6"' in modinfo, "unexpected package version"
    modmain = package.read("metals_and_reforged/modmain.lua").decode("utf-8")
    assert '"metal_storage_chest"' in modmain, "legacy metal chest prefab registration missing"
    assert '"metallurgy_reference_book"' in modmain, "metallurgy guide prefab missing"
    assert 'name = "mam_robot_smelting"' in modinfo, "robot forge automation option missing"
    assert 'name = "mam_metalschest"' not in modinfo, "retired chest option leaked into package"
    assert 'AddRecipe2("metallurgy_reference_book"' in modmain, "metallurgy guide recipe missing"
    assert 'AddRecipe2("metal_storage_chest"' not in modmain, "retired chest recipe leaked into package"
print("PASS: install package contains required runtime files and excludes test-only sources")
