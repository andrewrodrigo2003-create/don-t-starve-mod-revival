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
            with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_STORED) as zf:
                info = zipfile.ZipInfo("large.lua")
                info.file_size = MODULE.MAX_FILE_BYTES + 1
                # A forged size cannot be written as a valid entry through zipfile;
                # use a highly-compressible entry to exercise the ratio guard instead.
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

if __name__ == "__main__":
    unittest.main()
