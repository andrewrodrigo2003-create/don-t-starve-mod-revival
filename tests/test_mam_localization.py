from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "dst-mods" / "metals_and_reforged"


class LocalizationContractTests(unittest.TestCase):
    def test_language_setting_defaults_to_brazilian_portuguese(self):
        config = (MOD / "scripts" / "mam" / "config.lua").read_text(encoding="utf-8")
        modinfo = (MOD / "modinfo.lua").read_text(encoding="utf-8")
        self.assertIn('mam_language         = "ptbr"', config)
        self.assertIn('mam_language          = { ptbr = true, en = true }', config)
        self.assertIn('name = "mam_language"', modinfo)
        self.assertIn('default = "ptbr"', modinfo)

    def test_core_material_names_and_descriptions_have_two_locales(self):
        strings = (MOD / "initialise" / "modded_strings.lua").read_text(encoding="utf-8")
        for key in (
            "COPPER_DUST", "COPPER_ORE", "COPPER_INGOT",
            "IRON_DUST", "IRON_ORE", "IRON_INGOT",
            "GOLD_DUST", "GOLD_ORE", "GOLD_INGOT",
            "JUNK_DUST", "BRONZE_INGOT", "ADAMANTIUM_INGOT",
            "MOONGLASS_INGOT", "REDGEM_SHARD", "BLUEGEM_SHARD",
            "GREENGEM_SHARD", "YELLOWGEM_SHARD", "ORANGEGEM_SHARD",
            "PURPLEGEM_SHARD",
        ):
            self.assertIn(key + " =", strings)
        self.assertIn('return use_english and english or ptbr', strings)
        self.assertNotIn('"Copper Dust / Pó de cobre"', strings)

    def test_language_setting_is_loaded_before_strings(self):
        main = (MOD / "modmain.lua").read_text(encoding="utf-8")
        config_init = main.index("MAMConfig.Init(GetModConfigData)")
        strings_import = main.index('modimport("initialise/modded_strings.lua")')
        self.assertLess(config_init, strings_import)


    def test_metallurgy_guide_uses_selected_language_without_mixed_paragraphs(self):
        screen = (
            MOD / "scripts" / "screens" / "metallurgybookscreen.lua"
        ).read_text(encoding="utf-8")
        self.assertIn('local MAMConfig = require("mam/config")', screen)
        self.assertIn('L("Metalurgia", "Metalworking")', screen)
        self.assertIn('L("Desmontagem", "Deconstruction")', screen)
        self.assertIn('L("Anterior", "Previous")', screen)
        self.assertIn('L("Próxima", "Next")', screen)
        self.assertNotIn("Right-click a supported metal material or crafted metal item", screen)
        self.assertNotIn("Previous / Anterior", screen)
        self.assertNotIn("Next / Próxima", screen)

    def test_deconstruction_copy_matches_material_only_implementation(self):
        actions = (
            MOD / "initialise" / "modded_actions.lua"
        ).read_text(encoding="utf-8")
        screen = (
            MOD / "scripts" / "screens" / "metallurgybookscreen.lua"
        ).read_text(encoding="utf-8")
        self.assertIn('and "Dismantle" or "Desmontar"', actions)
        self.assertIn("MAMDeconstruction.IsSupported(inst.prefab)", actions)
        self.assertNotIn("supported_equipment", actions)
        self.assertIn("armaduras, ferramentas, equipamentos e estruturas não podem ser desmontados", screen)
        self.assertNotIn("Item durability scales equipment salvage", screen)



if __name__ == "__main__":
    unittest.main()
