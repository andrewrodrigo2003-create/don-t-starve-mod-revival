import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "tools" / "dst_mod_audit.py"
SPEC = importlib.util.spec_from_file_location("dst_mod_audit", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

class DstModAuditTests(unittest.TestCase):
    def test_directory_inventory_and_api_signals(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "modmain.lua").write_text(
                "AddPrefabPostInit('lucy', function(inst)\n"
                "    inst.components.aoespell:SetSpellFn(fn)\n"
                "end)\n",
                encoding="utf-8",
            )
            report = MODULE.audit(root)
            self.assertEqual(report["file_count"], 1)
            self.assertEqual(report["lua_file_count"], 1)
            categories = {s["category"] for s in report["signals"]}
            self.assertIn("spell_api", categories)
            self.assertIn("prefab_component_hooks", categories)
            self.assertFalse(report["executed_scanned_code"])

    def test_zip_is_read_without_extracting(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / "sample.zip"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.writestr("scripts/modmain.lua", "SetAltAttack(function() end)\n")
                zf.writestr("../outside.lua", "os.execute('not-run')\n")
            report = MODULE.audit(archive)
            self.assertEqual(report["file_count"], 1)
            self.assertTrue(any(s["category"] == "weapon_projectile_hooks" for s in report["signals"]))
            self.assertTrue(any("unsafe archive path" in e["error"] for e in report["read_errors"]))

    def test_directory_symlink_is_skipped(self):
        with tempfile.TemporaryDirectory() as tmp, tempfile.TemporaryDirectory() as outside:
            root = Path(tmp)
            secret = Path(outside) / "outside.lua"
            secret.write_text("os.execute('must not be read')", encoding="utf-8")
            link = root / "linked.lua"
            link.symlink_to(secret)
            report = MODULE.audit(root)
            self.assertEqual(report["file_count"], 0)
            self.assertTrue(any(e["error"] == "symbolic link skipped" for e in report["read_errors"]))

    def test_zip_oversized_entry_is_skipped_before_read(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / "oversized.zip"
            with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as zf:
                # Highly compressible data exercises the ratio guard without extraction.
                zf.writestr("large.lua", b" " * (MODULE.MAX_ZIP_COMPRESSION_RATIO * 1024))
            report = MODULE.audit(archive)
            self.assertEqual(report["file_count"], 0)
            self.assertTrue(any("compression-ratio" in e["error"] for e in report["read_errors"]))

    def test_non_lua_text_is_scanned_and_hash_is_stable(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "modinfo.lua").write_text("name = 'Example'\n", encoding="utf-8")
            report1 = MODULE.audit(root)
            report2 = MODULE.audit(root)
            self.assertEqual(report1["files"][0]["sha256"], report2["files"][0]["sha256"])


    def test_cross_mod_global_override_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for mod in ("workshop-alpha", "workshop-beta"):
                folder = root / mod
                folder.mkdir()
                (folder / "modmain.lua").write_text(
                    "GLOBAL.DAMAGETYPES = {}\\n", encoding="utf-8"
                )
            report = MODULE.audit(root)
            conflicts = report["potential_cross_mod_conflicts"]
            self.assertTrue(any(
                c["kind"] == "global_assignment"
                and c["target"] == "DAMAGETYPES"
                and c["severity"] == "high"
                and set(c["mods"]) == {"workshop-alpha", "workshop-beta"}
                for c in conflicts
            ))

    def test_duplicate_stategraph_handler_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for mod in ("character-one", "combat-overhaul"):
                folder = root / mod
                folder.mkdir()
                (folder / "modmain.lua").write_text(
                    "AddStategraphActionHandler('wilson', ActionHandler(ACTIONS.ATTACK, 'attack'))\\n",
                    encoding="utf-8",
                )
            report = MODULE.audit(root)
            self.assertTrue(any(
                c["kind"] == "stategraph_action_handler"
                and c["target"] == "wilson::ATTACK"
                and c["severity"] == "high"
                for c in report["potential_cross_mod_conflicts"]
            ))

    def test_component_postinit_overlap_is_informational(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for mod in ("mod-a", "mod-b"):
                folder = root / mod
                folder.mkdir()
                (folder / "modmain.lua").write_text(
                    "AddComponentPostInit('combat', function(self) end)\\n",
                    encoding="utf-8",
                )
            report = MODULE.audit(root)
            self.assertTrue(any(
                c["kind"] == "component_postinit"
                and c["target"] == "combat"
                and c["severity"] == "informational"
                for c in report["potential_cross_mod_conflicts"]
            ))

    def test_lua_comments_do_not_create_conflict_candidates(self):
        source = "-- AddComponentPostInit('combat', fn)\\n"
        source += "AddPrefabPostInit('lucy', fn) -- GLOBAL.DAMAGETYPES = {}\\n"
        found = MODULE.extract_registration_candidates("modmain.lua", source)
        self.assertEqual([(x["kind"], x["target"]) for x in found], [("prefab_postinit", "lucy")])


if __name__ == "__main__":
    unittest.main()
