from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "dst-mods" / "metals_and_reforged"
BALANCE = ROOT / "docs" / "design" / "CRAFTING_BALANCE_AUDIT_2.9.7.md"


def signature(body):
    parts = re.findall(r'Ingredient\("([^"]+)",\s*([0-9.]+)', body)
    return " + ".join(f"{name}×{amount}" for name, amount in parts)


def table_recipes(source):
    found = {}
    pattern = re.compile(
        r'\{\s*name\s*=\s*"([^"]+)"\s*,\s*ingredients\s*=\s*\{([^}]*)\}\s*\}',
        re.S,
    )
    for match in pattern.finditer(source):
        found[match.group(1)] = signature(match.group(2))
    return found


def addrecipe_calls(source):
    found = {}
    pattern = re.compile(r'AddRecipe2\(\s*"([^"]+)"\s*,\s*\{([^}]*)\}', re.S)
    for match in pattern.finditer(source):
        found[match.group(1)] = signature(match.group(2))
    return found


class CraftingBalanceCoverageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.balance = BALANCE.read_text(encoding="utf-8")
        cls.modded = (MOD / "initialise" / "modded_recipes.lua").read_text(encoding="utf-8")
        cls.craftbook = (MOD / "initialise" / "modded_craftbook.lua").read_text(encoding="utf-8")
        cls.modmain = (MOD / "modmain.lua").read_text(encoding="utf-8")

    def assert_recipe_row(self, name, cost):
        expected = f"| `{name}` | `{cost}` |"
        self.assertIn(expected, self.balance, f"Missing or stale balance row for {name}: {cost}")

    def test_all_vanilla_overrides_have_exact_balance_rows(self):
        recipes = table_recipes(self.modded)
        self.assertEqual(len(recipes), 21, "Vanilla override inventory changed; audit every new recipe")
        for name, cost in recipes.items():
            self.assert_recipe_row(name, cost)

    def test_all_mam_owned_recipes_have_exact_balance_rows(self):
        recipes = {}
        recipes.update(addrecipe_calls(self.modded))
        recipes.update(addrecipe_calls(self.modmain))
        recipes.update(addrecipe_calls(self.craftbook))
        self.assertEqual(len(recipes), 25, "MAM-owned recipe inventory changed; update the matrix")
        for name, cost in recipes.items():
            self.assert_recipe_row(name, cost)

    def test_all_craftbook_migrations_have_exact_balance_rows(self):
        recipes = table_recipes(self.craftbook)
        self.assertEqual(len(recipes), 35, "Craftbook migration inventory changed; update the matrix")
        for name, cost in recipes.items():
            self.assert_recipe_row(name, cost)

    def test_mad_scientist_lab_is_available_outside_hallowed_nights(self):
        guard = (MOD / "scripts" / "mam" / "recipe_guard.lua").read_text(encoding="utf-8")
        self.assertRegex(
            self.modded,
            r'MAMRecipeGuard\.set_station\(\s*"madscience_lab",\s*TECH\.NONE,\s*"STRUCTURES"',
        )
        self.assertIn("remove_special_event = true", self.modded)
        self.assertIn('clear_hint_msg_if = "NEEDSHALLOWED_NIGHTS"', self.modded)
        self.assertIn("function M.set_station(name, tech, filter, options)", guard)
        self.assertIn("options.remove_special_event == true", guard)
        self.assertIn("recipe.hint_msg == options.clear_hint_msg_if", guard)
        self.assertIn("recipe.hint_msg = nil", guard)

    def test_tool_gated_vanilla_recipes_are_documented(self):
        required = (
            "| `boards` | `log×4` |",
            "| `woodie_boards` | `log×3 + lucy×0` |",
            "| `boards_bunch` | `log×20` |",
            "| `cutstone` | `rocks×3` |",
            "| `cutstone_bunch` | `rocks×15` |",
        )
        for row in required:
            self.assertIn(row, self.balance)

    def test_every_override_has_a_guarded_vanilla_baseline(self):
        guard = (MOD / "scripts" / "mam" / "recipe_guard.lua").read_text(encoding="utf-8")
        for recipe in table_recipes(self.modded):
            self.assertRegex(guard, rf"(?m)^\s*{re.escape(recipe)}\s*=",
                             f"Missing vanilla baseline/guard coverage for {recipe}")

    def test_overlapping_gold_tags_are_not_counted_as_separate_items(self):
        smelting = (MOD / "scripts" / "smelting.lua").read_text(encoding="utf-8")
        products = (MOD / "scripts" / "smelting_products.lua").read_text(encoding="utf-8")
        harness = (ROOT / "dst-mods" / "tests" / "smelting_module_harness.lua").read_text(encoding="utf-8")
        self.assertIn('{"goldnugget"},', smelting)
        self.assertIn('{gold = 1, metal = 1}', smelting)
        self.assertIn('tags.gold >= 3 and tags.metal and tags.metal >= 3', products)
        self.assertIn('assert_consumption("gold batch", gold, { goldnugget = 6 }, {})', harness)
        self.assertIn("3 gold nuggets (as mesmas 3 unidades satisfazem gold e metal)", self.balance)

    def test_moonglass_lunar_tag_matches_the_consumed_moonrock(self):
        smelting = (MOD / "scripts" / "smelting.lua").read_text(encoding="utf-8")
        products = (MOD / "scripts" / "smelting_products.lua").read_text(encoding="utf-8")
        harness = (ROOT / "dst-mods" / "tests" / "smelting_module_harness.lua").read_text(encoding="utf-8")
        self.assertIn('{moonglass = 2, moon = 1}', smelting)
        self.assertIn('moonglass_ingot   = { tags = { moonglass = 2, moon = 1 } }', products)
        self.assertIn('assert_consumption("moonglass batch", moon,', harness)
        self.assertIn('moonglass = 4, moonrocknugget = 2', harness)
        self.assertIn("tag moon do lingote agora corresponde a 1 moonrocknugget", self.balance)

    def test_mad_scientist_lab_provides_the_mam_alchemy_tree(self):
        tech = (MOD / "scripts" / "mam" / "tech.lua").read_text(encoding="utf-8")
        main = (MOD / "modmain.lua").read_text(encoding="utf-8")
        self.assertIn("local madscience_tree = TUNING.PROTOTYPER_TREES.MADSCIENCE", tech)
        self.assertIn("madscience_tree.ALCHEMY = math.max", tech)
        self.assertIn("vanilla MADSCIENCE prototyper tree", tech)
        self.assertIn('AddRecipe2("metallurgy_reference_book"', main)
        self.assertIn("TECH.ALCHEMY_ONE", main)
        self.assertIn("Mad Scientist Lab", self.balance)
        self.assertIn("preserva a árvore vanilla MADSCIENCE", self.balance)

    def test_jagged_armor_power_is_documented_against_thulecite(self):
        jagged = (MOD / "scripts" / "prefabs" / "jagged_armor.lua").read_text(encoding="utf-8")
        main = (MOD / "modmain.lua").read_text(encoding="utf-8")
        self.assertIn("InitCondition(1500, 0.85)", jagged)
        self.assertIn("walkspeedmult = 1.1", jagged)
        self.assertIn('AddRecipe2("jagged_armor"', main)
        self.assertIn("1.765", self.balance)
        self.assertIn("Thulecite Suit", self.balance)
        self.assertIn("1500 de condição, 85% de absorção e +10%", self.balance)

    def test_adamantium_cost_is_composed_from_nightmare_fuel_and_named_iron(self):
        smelting = (MOD / "scripts" / "smelting.lua").read_text(encoding="utf-8")
        products = (MOD / "scripts" / "smelting_products.lua").read_text(encoding="utf-8")
        harness = (ROOT / "dst-mods" / "tests" / "smelting_module_harness.lua").read_text(encoding="utf-8")
        self.assertIn("{iron = 2, steel = 1, metal = 1}", smelting)
        self.assertIn("tags.steel and tags.steel >= 3 and names.iron_ingot", products)
        self.assertIn("adamantium_ingot  = { tags = { steel = 3 }, names = { iron_ingot = 1 }", products)
        self.assertIn('assert_consumption("adamantium batch", adamantium', harness)
        self.assertIn("6 nightmarefuel + 2 iron_ingot", self.balance)

    def test_equipment_balance_ports_are_in_the_current_line(self):
        recipes = table_recipes(self.modded)
        self.assertEqual(recipes.get("armormarble"), "marble×6 + rope×2 + iron_ingot×1")
        forkstick = (MOD / "scripts" / "prefabs" / "forkstick.lua").read_text(encoding="utf-8")
        harpoon = (MOD / "scripts" / "prefabs" / "donharpoon.lua").read_text(encoding="utf-8")
        self.assertIn("SetDamage(TUNING.SPEAR_DAMAGE)", forkstick)
        self.assertNotRegex(forkstick, r"SetDamage\(\s*math\.random")
        self.assertIn("HARPOON_DAMAGE = 68", harpoon)
        self.assertIn("HARPOON_USES = 100", harpoon)
        self.assertIn('\"armormarble\"', self.modded)
        self.assertIn("MAMRecipeGuard.set_station(name, TECH.ALCHEMY_ONE", self.modded)
        jagged_line = next(line for line in self.modmain.splitlines() if 'AddRecipe2(\"jagged_armor\"' in line)
        self.assertIn("TECH.MAM_FORGE_ONE", jagged_line)

    def test_ore_acquisition_paths_and_legacy_gold_alias_are_documented(self):
        worldgen = (MOD / "modworldgenmain.lua").read_text(encoding="utf-8")
        modmain = (MOD / "modmain.lua").read_text(encoding="utf-8")
        goldore = (MOD / "scripts" / "prefabs" / "goldore.lua").read_text(encoding="utf-8")
        drops = (MOD / "initialise" / "modded_drops.lua").read_text(encoding="utf-8")
        newrocks = (MOD / "scripts" / "prefabs" / "newrocks.lua").read_text(encoding="utf-8")
        self.assertIn('"goldore"', modmain)
        self.assertIn('return Prefab("gold_ore", fn, assets)', goldore)
        self.assertIn('SpawnPrefab("goldnugget")', goldore)
        self.assertIn("countprefabs.gold_ore = math.random(5)", worldgen)
        self.assertIn("local SHRUB_IRON_BY_STAGE = { [2] = 1, [3] = 2 }", drops)
        self.assertIn("local previous = lootdropper.lootsetupfn", drops)
        self.assertIn("previous(dropper)", drops)
        self.assertIn('Prefab("spikyrock"', newrocks)
        self.assertNotIn("spikyrock =", worldgen)
        self.assertIn("não é um prefab ausente", self.balance)

    def test_storage_capacity_and_cold_safe_fridge_contract(self):
        modmain = (MOD / "modmain.lua").read_text(encoding="utf-8")
        marble_chest = (MOD / "scripts" / "prefabs" / "marble_chest.lua").read_text(encoding="utf-8")
        cold_safe = (MOD / "scripts" / "prefabs" / "cold_safe.lua").read_text(encoding="utf-8")
        self.assertIn("for y = 3, -1, -1 do", modmain)
        self.assertIn("for x = -1, 3 do", modmain)
        self.assertIn("params.marble_chest = makeChest()", modmain)
        self.assertIn("params.cold_safe = makeChest()", modmain)
        self.assertIn('inst:AddTag("chest")', marble_chest)
        self.assertIn('inst:AddTag("fridge")', cold_safe)
        self.assertIn("function params.cold_safe.itemtestfn", modmain)
        self.assertIn('item:HasTag("icebox_valid")', modmain)
        self.assertIn('item:HasTag("fresh")', modmain)
        self.assertIn("25 slots", self.balance)
        self.assertIn("não é obrigatório para uma geladeira simples", self.balance)

    def test_other_equipment_stats_and_shears_use_consumption(self):
        halberd = (MOD / "scripts" / "prefabs" / "halberd.lua").read_text(encoding="utf-8")
        scepter = (MOD / "scripts" / "prefabs" / "scepter.lua").read_text(encoding="utf-8")
        shears = (MOD / "scripts" / "prefabs" / "shears.lua").read_text(encoding="utf-8")
        hats = (MOD / "scripts" / "prefabs" / "tfwp_hats.lua").read_text(encoding="utf-8")
        main = (MOD / "modmain.lua").read_text(encoding="utf-8")
        hooks = (MOD / "initialise" / "modded_shearsharvest.lua").read_text(encoding="utf-8")
        self.assertIn("HALBERD_DAMAGE = 51", halberd)
        self.assertIn("HALBERD_USES = 150", halberd)
        self.assertIn("SetAction(ACTIONS.CHOP, 7)", halberd)
        self.assertIn("dapperness = -0.25", halberd)
        self.assertIn("walkspeedmult = 0.85", halberd)
        self.assertIn("DoDelta(-2)", halberd)
        self.assertIn("SetDamage(32)", scepter)
        self.assertIn("SetRange(1.6)", scepter)
        self.assertIn("walkspeedmult = TUNING.CANE_SPEED_MULT", scepter)
        self.assertIn("SetRadius(6)", scepter)
        self.assertIn("InitializeFuelLevel(TUNING.TOPHAT_PERISHTIME*0.5)", scepter)
        self.assertIn("SetDamage(17)", shears)
        self.assertIn("SetMaxUses(500)", shears)
        self.assertIn("SetConsumption(ACTIONS.AREAPICK, 1)", shears)
        self.assertIn("SetRadius(4)", shears)
        self.assertIn("local mods = {damage = 1.15, movement = 1.10}", hats)
        self.assertIn('luxury_nox_helm = {build = "crowndamager", armor = {1250, 0.85}}', hats)
        self.assertIn('AddRecipe2("tfwp_luxury_nox_helm_hat"', main)
        self.assertIn('AddRecipe2("halberd"', main)
        self.assertIn('AddRecipe2("scepter"', main)
        self.assertIn('AddRecipe2("shears"', main)
        self.assertIn("TUNING.SHEARS.HARVEST_RADIUS + 2", hooks)
        self.assertIn("1 uso por ação AREAPICK concluída", self.balance)
        self.assertIn("Nox Helm", self.balance)

    def test_archive_resonator_deconstruction_refund_matches_mam_recipe(self):
        modded = (MOD / "initialise" / "modded_recipes.lua").read_text(encoding="utf-8")
        guard = (MOD / "scripts" / "mam" / "recipe_guard.lua").read_text(encoding="utf-8")
        self.assertIn('AddRecipePostInit("archive_resonator"', modded)
        self.assertIn("recipe.is_deconstruction_recipe", modded)
        self.assertIn('Ingredient("moonglass_ingot", 1)', modded)
        self.assertIn('Ingredient("thulecite", 1)', modded)
        self.assertIn("50% de reembolso do lingote", self.balance)
        self.assertIn("estado de aprendizado/blueprint não é alterado", self.balance)
        station_fn = guard.split("function M.set_station", 1)[1].split("\nfunction M.", 1)[0]
        self.assertIn("recipe.level = new_level", station_fn)
        self.assertNotIn("recipe.nounlock", station_fn)
        self.assertNotIn("recipe.builder_tag", station_fn)

    def test_optional_forge_pack_recipe_disable_switches_are_honored(self):
        modmain = (MOD / "modmain.lua").read_text(encoding="utf-8")
        modinfo = (MOD / "modinfo.lua").read_text(encoding="utf-8")
        forgepack = (MOD / "initialise" / "modded_forgepack.lua").read_text(encoding="utf-8")
        self.assertIn('GetModConfigData("legacy_forge_weapon_abilities") and GetModConfigData("forge_weapons")', modmain)
        for weapon in ("FORGINGHAMMER", "PITHPIKE", "SPIRALSPEAR", "BLACKSMITH_EDGE"):
            self.assertIn(f"if not TUNING.THE_FORGE_ITEM_PACK.{weapon}.DISABLE_RECIPE then", modmain)
            self.assertIn(f"{weapon}.DISABLE_RECIPE = GetModConfigData", forgepack)
        def option_block(option_name):
            option_at = modinfo.index(f'name = "{option_name}"')
            next_entry = re.search(
                r'\n[ \t]{0,4}\},[ \t\r]*\n[ \t]{0,4}\{',
                modinfo[option_at:],
            )
            self.assertIsNotNone(next_entry, f"Could not delimit config option {option_name}")
            return modinfo[option_at:option_at + next_entry.start()]

        self.assertIn("default = false", option_block("legacy_forge_weapon_abilities"))
        self.assertIn("default = false", option_block("forge_weapons"))
        self.assertIn('GetModConfigData("FORGING_HAMMER_DURABILITY", 0)', forgepack)
        self.assertIn("DURABILITY.AMOUNT > 0", forgepack)
        self.assertIn("SetMaxUses", forgepack)
        self.assertIn("SetConsumption(", forgepack)
        self.assertIn("20/25/30/30", self.balance)
        self.assertIn("receitas opcionais desativadas por padrão", self.balance)

    def test_cumulative_first_war_workbench_budget_is_documented(self):
        for value in ("23 iron-value", "6 copper-value", "9 cutstone", "5 charcoal"):
            self.assertIn(value, self.balance)


    def test_ironrock_expected_yield_and_worldgen_distribution_are_documented(self):
        rocks = (MOD / "scripts" / "prefabs" / "newrocks.lua").read_text(encoding="utf-8")
        worldgen = (MOD / "modworldgenmain.lua").read_text(encoding="utf-8")
        block = re.search(r"SetSharedLootTable\(\s*'ironrock',\s*\{([\s\S]*?)\}\s*\)", rocks)
        self.assertIsNotNone(block, "Missing ironrock shared loot table")
        chances = [float(x) for x in re.findall(r"\{\s*'iron_ore'\s*,\s*([0-9.]+)\s*\}", block.group(1))]
        self.assertAlmostEqual(sum(chances), 2.5)
        self.assertGreaterEqual(len(re.findall(r"ironrock\s*=\s*0\.75", worldgen)), 7)
        self.assertIn("2,50 `iron_ore`", self.balance)
        self.assertIn("9,2 eventos de `ironrock`", self.balance)

    def test_acquisition_expectations_use_default_additive_drop_settings(self):
        config = (MOD / "scripts" / "mam" / "config.lua").read_text(encoding="utf-8")
        guard = (MOD / "scripts" / "mam" / "loot_guard.lua").read_text(encoding="utf-8")
        self.assertRegex(config, r"mam_extra_drops\s*=\s*1")
        self.assertRegex(config, r"mam_drops_mode\s*=\s*1")
        self.assertRegex(config, r"mam_drops_normalise\s*=\s*0")
        self.assertIn("lootdropper:AddChanceLoot(entry[1], entry[2])", guard)
        self.assertIn("Roll repetido do mesmo item é independente", self.balance)

    def test_balance_contract_is_in_ci(self):
        workflow = (ROOT / ".github" / "workflows" / "metals-and-more-lua-checks.yml").read_text(encoding="utf-8")
        self.assertIn("tests/test_mam_crafting_balance_contract.py", workflow)


if __name__ == "__main__":
    unittest.main()
