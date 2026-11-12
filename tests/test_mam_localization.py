from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
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


if __name__ == "__main__":
    unittest.main()
