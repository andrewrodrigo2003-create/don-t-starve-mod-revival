from pathlib import Path
import unittest
import struct


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
        self.assertIn('Asset("IMAGE", "images/inventoryimages/obsidian_workbench.tex")', modmain)
        self.assertIn('Asset("ATLAS", "images/inventoryimages/obsidian_workbench.xml")', modmain)
        self.assertTrue((MOD_ROOT / "images/inventoryimages/obsidian_workbench.tex").is_file())
        self.assertTrue((MOD_ROOT / "images/inventoryimages/obsidian_workbench.xml").is_file())

    def test_mod_icon_source_and_ktex_atlas_are_valid(self):
        source = MOD_ROOT / "images/branding/metals_and_more_reforged_icon.png"
        texture = MOD_ROOT / "modicon.tex"
        atlas = (MOD_ROOT / "modicon.xml").read_text(encoding="utf-8")

        data = source.read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", data[16:24]), (256, 256))
        self.assertTrue(texture.is_file())
        self.assertIn('filename="modicon.tex"', atlas)
        self.assertIn('u1="0" u2="1" v1="0" v2="1"', atlas)

    def test_warworkbench_animation_asset_is_present(self):
        prefab = (MOD_ROOT / "scripts/prefabs/warworkbench.lua").read_text(encoding="utf-8")
        self.assertIn('Asset("ANIM", "anim/workbench_obsidian.zip")', prefab)
        self.assertTrue((MOD_ROOT / "anim/workbench_obsidian.zip").is_file())


if __name__ == "__main__":
    unittest.main()
