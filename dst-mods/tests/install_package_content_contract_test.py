from pathlib import Path
import sys
import zipfile


archive = Path(sys.argv[1])
required = {
    "metals_and_reforged/modinfo.lua",
    "metals_and_reforged/modmain.lua",
    "metals_and_reforged/scripts/prefabs/metal_smelter.lua",
    "metals_and_reforged/scripts/prefabs/metal_storage_chest.lua",
    "metals_and_reforged/initialise/modded_ui_forecast.lua",
}
with zipfile.ZipFile(archive) as package:
    names = set(package.namelist())
    missing = sorted(required - names)
    assert not missing, f"install package is missing required files: {missing}"
    leaked = sorted(name for name in names if name.startswith("metals_and_reforged/tests/"))
    assert not leaked, f"test-only files leaked into install package: {leaked}"
    modinfo = package.read("metals_and_reforged/modinfo.lua").decode("utf-8")
    assert 'version = "2.9.5"' in modinfo, "unexpected package version"
    assert 'name = "mam_metalschest"' in modinfo, "metal chest option missing from package"
    modmain = package.read("metals_and_reforged/modmain.lua").decode("utf-8")
    assert 'if MAMConfig.on("mam_metalschest") then' in modmain, "metal chest config gate missing"
    assert 'AddRecipe2("metal_storage_chest"' in modmain, "craftable metal chest recipe missing"
print("PASS: install package contains required runtime files and excludes test-only sources")
