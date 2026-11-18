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

    def test_balance_contract_is_in_ci(self):
        workflow = (ROOT / ".github" / "workflows" / "metals-and-more-lua-checks.yml").read_text(encoding="utf-8")
        self.assertIn("tests/test_mam_crafting_balance_contract.py", workflow)


if __name__ == "__main__":
    unittest.main()
