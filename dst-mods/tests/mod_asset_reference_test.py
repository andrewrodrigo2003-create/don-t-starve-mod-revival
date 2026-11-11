from pathlib import Path
import unittest


MOD_ROOT = Path(__file__).resolve().parents[1] / "metals_and_reforged"


class ModAssetReferenceTests(unittest.TestCase):
    def test_warworkbench_minimap_asset_matches_registered_files(self):
        prefab = (MOD_ROOT / "scripts/prefabs/warworkbench.lua").read_text(encoding="utf-8")
        modmain = (MOD_ROOT / "modmain.lua").read_text(encoding="utf-8")

        self.assertIn('Asset("MINIMAP_IMAGE", "obsidian_workbench")', prefab)
        self.assertNotIn('Asset("MINIMAP_IMAGE", "workbench_obsidian")', prefab)
        self.assertIn('Asset("IMAGE", "minimap/obsidian_workbench.tex")', modmain)
        self.assertIn('Asset("ATLAS", "minimap/obsidian_workbench.xml")', modmain)
        self.assertTrue((MOD_ROOT / "minimap/obsidian_workbench.tex").is_file())
        self.assertTrue((MOD_ROOT / "minimap/obsidian_workbench.xml").is_file())

    def test_warworkbench_animation_asset_is_present(self):
        prefab = (MOD_ROOT / "scripts/prefabs/warworkbench.lua").read_text(encoding="utf-8")
        self.assertIn('Asset("ANIM", "anim/workbench_obsidian.zip")', prefab)
        self.assertTrue((MOD_ROOT / "anim/workbench_obsidian.zip").is_file())


if __name__ == "__main__":
    unittest.main()
