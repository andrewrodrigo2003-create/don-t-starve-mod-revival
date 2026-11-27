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
                    "GLOBAL.DAMAGETYPES = {}\n", encoding="utf-8"
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
                    "AddStategraphActionHandler('wilson', ActionHandler(ACTIONS.ATTACK, 'attack'))\n",
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
                    "AddComponentPostInit('combat', function(self) end)\n",
                    encoding="utf-8",
                )
            report = MODULE.audit(root)
            self.assertTrue(any(
                c["kind"] == "component_postinit"
                and c["target"] == "combat"
                and c["severity"] == "informational"
                for c in report["potential_cross_mod_conflicts"]
            ))



    def test_modinfo_priority_and_dependencies_are_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            definitions = {
                "workshop-alpha": ('name = "Alpha"\npriority = 40\nmod_dependencies = {"workshop-base"}\n'),
                "workshop-beta": ('name = "Beta"\npriority = -5\n'),
            }
            for mod, modinfo in definitions.items():
                folder = root / mod
                folder.mkdir()
                (folder / "modinfo.lua").write_text(modinfo, encoding="utf-8")
                (folder / "modmain.lua").write_text("GLOBAL.DAMAGETYPES = {}\n", encoding="utf-8")
            report = MODULE.audit(root)
            metadata = {item["mod_id"]: item for item in report["mod_metadata"]}
            self.assertEqual(metadata["workshop-alpha"]["name"], "Alpha")
            self.assertEqual(metadata["workshop-alpha"]["priority"], 40)
            self.assertEqual(metadata["workshop-alpha"]["mod_dependencies"], ["workshop-base"])
            conflict = next(
                c for c in report["potential_cross_mod_conflicts"]
                if c["kind"] == "global_assignment"
            )
            self.assertEqual(conflict["mod_details"]["workshop-beta"]["priority"], -5)

    def test_single_mod_zip_does_not_report_own_files_as_cross_mod(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / "single-mod.zip"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.writestr("modmain.lua", "GLOBAL.DAMAGETYPES = {}\n")
                zf.writestr("scripts/extra.lua", "GLOBAL.DAMAGETYPES = {}\n")
            report = MODULE.audit(archive)
            self.assertEqual(report["potential_cross_mod_conflicts"], [])

    def test_lua_comments_do_not_create_conflict_candidates(self):
        source = "-- AddComponentPostInit('combat', fn)\n"
        source += "AddPrefabPostInit('lucy', fn) -- GLOBAL.DAMAGETYPES = {}\n"
        found = MODULE.extract_registration_candidates("modmain.lua", source)
        self.assertEqual([(x["kind"], x["target"]) for x in found], [("prefab_postinit", "lucy")])


    def test_lua_long_bracket_strings_do_not_create_hook_candidates(self):
        source = (
            'local documentation = [=[\n'
            "AddAction('fake_action') -- this is string content\n"
            "AddComponentPostInit('fake_component', fn)\n"
            "]=]\n"
            "AddAction('real_action')\n"
        )
        found = MODULE.extract_registration_candidates("modmain.lua", source)
        self.assertEqual(
            [(item["kind"], item["target"]) for item in found],
            [("action_definition", "real_action")],
        )

    def test_lua_long_bracket_strings_support_equals_levels(self):
        source = 'local text = [==[ -- AddAction("fake") ]==]\nAddAction("real")'
        found = MODULE.extract_registration_candidates("modmain.lua", source)
        self.assertEqual([item["target"] for item in found], ["real"])


    def test_lua_signal_scan_ignores_comments_and_short_strings(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "modmain.lua").write_text(
                "-- debug.getregistry() is documentation\n"
                "local note = 'debug.getregistry() is only text'\n"
                'local other = "DoPeriodicTask(1, fn)"\n'
                "debug.getregistry() -- comment: debug.getregistry()\n",
                encoding="utf-8",
            )
            report = MODULE.audit(root)
            matches = [
                item for item in report["signals"]
                if item["category"] == "dynamic_code_or_debug"
            ]
            self.assertEqual(len(matches), 1)
            self.assertEqual(matches[0]["line"], 4)
            self.assertEqual(
                matches[0]["snippet"],
                "debug.getregistry() -- comment: debug.getregistry()",
            )
            self.assertEqual(matches[0]["evidence"], matches[0]["snippet"])
            self.assertEqual(matches[0]["confidence"], "low")
            self.assertEqual(matches[0]["estimated_severity"], "context_dependent")
            self.assertEqual(matches[0]["evidence_type"], "textual_indicator")
            self.assertIn("category", matches[0])

    def test_lua_signal_scan_ignores_long_strings_and_comments(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "modmain.lua").write_text(
                "--[==[ debug.getregistry()\n"
                "DoPeriodicTask(1, fn)\n"
                "open_list = {}\n"
                "]==]\n"
                "local docs = [=[\n"
                "debug.getregistry()\n"
                "AddPrefabPostInit('fake', fn)\n"
                "]=]\n"
                "debug.getregistry()\n",
                encoding="utf-8",
            )
            report = MODULE.audit(root)
            matches = [
                item for item in report["signals"]
                if item["category"] == "dynamic_code_or_debug"
            ]
            self.assertEqual(len(matches), 1)
            self.assertEqual(matches[0]["line"], 9)

    def test_lua_mask_preserves_offsets_lines_and_code_after_literals(self):
        source = (
            "-- fake debug.getregistry()\n"
            "local short = 'escaped \\' quote and fake debug.getregistry()'\n"
            "local long = [==[ DoPeriodicTask(1, fn) ]==]\n"
            "debug.getregistry()\n"
        )
        masked = MODULE.mask_lua_noncode(source)
        self.assertEqual(len(masked), len(source))
        self.assertEqual(masked.count("\n"), source.count("\n"))
        self.assertNotIn("debug.getregistry()", masked.splitlines()[0])
        self.assertNotIn("debug.getregistry()", masked.splitlines()[1])
        self.assertNotIn("DoPeriodicTask", masked.splitlines()[2])
        self.assertIn("debug.getregistry()", masked.splitlines()[3])

    def test_lua_long_comment_and_string_delimiters_do_not_leak(self):
        source = (
            "--[=[ text ]==] debug.getregistry()\n"
            "still comment DoPeriodicTask(1, fn) ]=]\n"
            "local text = [==[ -- not a comment ]=] debug.getregistry() ]==]\n"
            "debug.getregistry()\n"
        )
        masked = MODULE.mask_lua_noncode(source)
        self.assertNotIn("debug.getregistry()", "\n".join(masked.splitlines()[:3]))
        self.assertIn("debug.getregistry()", masked.splitlines()[3])

    def test_non_lua_text_keeps_existing_scanning_behavior(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "readme.md").write_text(
                "debug.getregistry()\n", encoding="utf-8"
            )
            report = MODULE.audit(root)
            self.assertTrue(any(
                item["category"] == "dynamic_code_or_debug"
                for item in report["signals"]
            ))


    def test_registration_candidates_include_conservative_evidence_metadata(self):
        candidates = MODULE.extract_registration_candidates(
            "modmain.lua",
            "AddPrefabPostInit('lucy', function(inst)\\n    return inst\\nend)\\n",
        )
        self.assertTrue(candidates)
        finding = candidates[0]
        for key in (
            "path", "line", "kind", "rule", "evidence", "confidence",
            "estimated_severity", "explanation", "suggested_fix", "limitations",
        ):
            self.assertIn(key, finding)
        self.assertEqual(finding["path"], "modmain.lua")
        self.assertEqual(finding["line"], 1)
        self.assertEqual(finding["confidence"], "low")
        self.assertEqual(finding["evidence_type"], "textual_indicator")


if __name__ == "__main__":
    unittest.main()
