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
