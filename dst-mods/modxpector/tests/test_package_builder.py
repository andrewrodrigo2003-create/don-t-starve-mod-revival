import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path


BUILDER_PATH = Path(__file__).resolve().parents[1] / "tools" / "build_package.py"
SPEC = importlib.util.spec_from_file_location("modxpector_build_package", BUILDER_PATH)
assert SPEC is not None and SPEC.loader is not None
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class PackageBuilderSecurityTests(unittest.TestCase):
    def test_local_bridge_token_is_never_packaged(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            mod_root = root / "mod"
            dist_root = root / "dist"
            mod_root.mkdir()
            (mod_root / "modinfo.lua").write_text('version = "test"\n', encoding="utf-8")
            (mod_root / "modmain.lua").write_text("-- runtime\n", encoding="utf-8")
            scripts = mod_root / "scripts"
            scripts.mkdir()
            (scripts / "runtime.lua").write_text("-- runtime module\n", encoding="utf-8")
            (mod_root / "bridge_token.txt").write_text("synthetic-not-a-real-secret", encoding="utf-8")

            original_here, original_dist = BUILDER.HERE, BUILDER.DIST
            try:
                BUILDER.HERE = mod_root
                BUILDER.DIST = dist_root
                BUILDER.main()
            finally:
                BUILDER.HERE, BUILDER.DIST = original_here, original_dist

            archive = dist_root / "ModXpector-test-test.zip"
            self.assertTrue(archive.is_file())
            with zipfile.ZipFile(archive) as package:
                names = set(package.namelist())
                self.assertIn("dst_mod_inspector/modmain.lua", names)
                self.assertIn("dst_mod_inspector/scripts/runtime.lua", names)
                self.assertNotIn("dst_mod_inspector/bridge_token.txt", names)


    def test_runtime_symlink_to_external_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            mod_root = root / "mod"
            mod_root.mkdir()
            (mod_root / "modinfo.lua").write_text('version = "test"\\n', encoding="utf-8")
            (mod_root / "modmain.lua").write_text("-- runtime\\n", encoding="utf-8")
            scripts = mod_root / "scripts"
            scripts.mkdir()
            outside = root / "outside.lua"
            outside.write_text("SYNTHETIC_EXTERNAL_CONTENT", encoding="utf-8")
            (scripts / "external.lua").symlink_to(outside)

            original_here = BUILDER.HERE
            try:
                BUILDER.HERE = mod_root
                with self.assertRaisesRegex(SystemExit, "Symlink bloqueado"):
                    BUILDER.runtime_files()
            finally:
                BUILDER.HERE = original_here

    def test_runtime_symlink_directory_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            mod_root = root / "mod"
            mod_root.mkdir()
            (mod_root / "modinfo.lua").write_text('version = "test"\\n', encoding="utf-8")
            (mod_root / "modmain.lua").write_text("-- runtime\\n", encoding="utf-8")
            scripts = mod_root / "scripts"
            scripts.mkdir()
            outside = root / "external"
            outside.mkdir()
            (outside / "leak.lua").write_text("SYNTHETIC_EXTERNAL_CONTENT", encoding="utf-8")
            (scripts / "external").symlink_to(outside, target_is_directory=True)

            original_here = BUILDER.HERE
            try:
                BUILDER.HERE = mod_root
                with self.assertRaisesRegex(SystemExit, "Symlink bloqueado"):
                    BUILDER.runtime_files()
            finally:
                BUILDER.HERE = original_here


if __name__ == "__main__":
    unittest.main()
