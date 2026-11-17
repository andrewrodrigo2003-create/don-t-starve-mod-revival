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


    def test_forge_preview_and_forecast_button_have_two_locales(self):
        preview = (MOD / "initialise" / "modded_ui_forecast.lua").read_text(encoding="utf-8")
        forecast = (MOD / "scripts" / "mam" / "forecast.lua").read_text(encoding="utf-8")
        self.assertIn('local MAMConfig = require("mam/config")', preview)
        self.assertIn('L("PRÉVIA DA FORJA", "FORGE PREVIEW")', preview)
        self.assertIn('L("Nenhum resultado válido", "No valid result")', preview)
        self.assertIn('L("Pronto para coletar", "Ready to collect")', preview)
        self.assertIn('L("Fundir", "Smelt")', forecast)
        self.assertIn('L("Coletar", "Harvest")', forecast)
        self.assertIn('L("Carga mista", "Mixed load")', forecast)
        self.assertIn('L("Produzirá: ", "Will produce: ")', forecast)
        self.assertNotIn('return "Smelt"', forecast)

    def test_station_and_storage_texts_are_not_overwritten_after_localization(self):
        strings = (MOD / "initialise" / "modded_strings.lua").read_text(encoding="utf-8")
        main = (MOD / "modmain.lua").read_text(encoding="utf-8")
        for key in ("WARWORKBENCH", "CRAFTBOOK", "MARBLE_CHEST", "COLD_SAFE", "METAL_STORAGE_CHEST"):
            self.assertIn(key + " =", strings)
            for prefix in ("STRINGS.NAMES.", "STRINGS.RECIPE_DESC.", "STRINGS.CHARACTERS.GENERIC.DESCRIBE."):
                self.assertNotIn(prefix + key + " =", main)
        self.assertIn("filter_text = STRINGS.NAMES.WARWORKBENCH", main)
        self.assertIn("filter_text = STRINGS.NAMES.CRAFTBOOK", main)
        self.assertLess(main.index('modimport("initialise/modded_strings.lua")'),
                        main.index('AddPrototyperDef("warworkbench"'))
        self.assertNotIn('AddRecipe2("metal_storage_chest"', main)

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
