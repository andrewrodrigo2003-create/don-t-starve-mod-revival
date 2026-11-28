from pathlib import Path
import importlib.util
import io
import json
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("dst_lab", ROOT / "dst-mods/tests/run_lab.py")
lab = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lab)


class LabRunnerTests(unittest.TestCase):
    def test_registry_includes_current_suites_and_correct_config_directory(self):
        self.assertEqual(len(lab.LUA_TESTS), 32)
        self.assertEqual(len(lab.PYTHON_TESTS), 9)
        self.assertEqual(len(lab.LUA_TESTS), len(set(lab.LUA_TESTS)))
        for name in ("tool_gated_crafting_test.lua", "station_storage_localization_test.lua"):
            self.assertIn("dst-mods/tests/" + name, lab.LUA_TESTS)
        config = "dst-mods/metals_and_reforged/tests/mam_config_test.lua"
        self.assertIn(config, lab.LUA_TESTS)
        self.assertEqual(lab.test_cwd(ROOT, config), ROOT / "dst-mods/metals_and_reforged")
        for relative in (*lab.LUA_TESTS, *lab.PYTHON_TESTS):
            self.assertTrue((ROOT / relative).is_file(), relative)
        self.assertNotIn("dst-mods/tests/better_lucy_test.lua", lab.LUA_TESTS)
        self.assertIn("dst-mods/tests/mod_asset_reference_test.py", lab.PYTHON_TESTS)
        self.assertIn("tests/test_dst_lab_runner.py", lab.PYTHON_TESTS)
        self.assertIn("tests/test_mam_crafting_balance_contract.py", lab.PYTHON_TESTS)
        self.assertIn("dst-mods/tests/warworkbench_tech_contract_test.py", lab.PYTHON_TESTS)

    def test_registry_stays_in_sync_with_ci_workflow(self):
        workflow = (ROOT / ".github/workflows/metals-and-more-lua-checks.yml").read_text(encoding="utf-8")
        lua_step = re.search(
            r"(?ms)^      - name: Run all Metals and More regression harnesses\n"
            r"        run: \|\n(?P<body>.*?)(?=^      - name: )", workflow,
        )
        self.assertIsNotNone(lua_step)
        ci_lua = {f"dst-mods/tests/{name}" for name in re.findall(r"dst-mods/tests/([A-Za-z0-9_]+\.lua)", lua_step.group("body"))}
        config_step = re.search(
            r"(?ms)^      - name: Run MAM configuration Lua harness\n"
            r"        run: \|\n(?P<body>.*?)(?=^      - name: )", workflow,
        )
        self.assertIsNotNone(config_step)
        self.assertIn("cd dst-mods/metals_and_reforged", config_step.group("body"))
        self.assertIn("lua5.1 tests/mam_config_test.lua", config_step.group("body"))
        ci_lua.add("dst-mods/metals_and_reforged/tests/mam_config_test.lua")
        self.assertEqual(ci_lua, set(lab.LUA_TESTS))

        python_steps = workflow.split("      - name: Package installable mod", 1)[0]
        ci_python = set(re.findall(r"^        run: python3 ([^\s]+\.py)$", python_steps, re.MULTILINE))
        registered_python = set(lab.PYTHON_TESTS)
        self.assertEqual(ci_python, registered_python - {"tests/test_minimap_update_optimization.py"})

    def test_missing_script_is_blocked_instead_of_silently_skipped(self):
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "missing.lua"
            with patch.object(lab.subprocess, "run") as run:
                result = lab.run_check("missing", "harness", ["lua", str(missing)], Path(directory), 1, [missing])
            run.assert_not_called()
            self.assertEqual(result["status"], "blocked")
            self.assertIn("missing.lua", result["stderr"])

    def test_missing_executable_is_reported(self):
        with patch.object(lab.subprocess, "run", side_effect=FileNotFoundError("lua unavailable")):
            result = lab.run_check("lua", "tooling", ["missing-lua"], ROOT, 1)
        self.assertEqual(result["status"], "blocked")
        self.assertIsNone(result["returncode"])

    def test_timeout_keeps_partial_output(self):
        failure = subprocess.TimeoutExpired(["lua"], 1, output=b"partial output", stderr=b"partial error")
        with patch.object(lab.subprocess, "run", side_effect=failure):
            result = lab.run_check("timeout", "harness", ["lua"], ROOT, 1)
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["stdout"], "partial output")
        self.assertIn("partial error", result["stderr"])
        self.assertIn("Timeout", result["stderr"])

    def test_nonzero_exit_and_logs_survive_json_round_trip(self):
        with patch.object(lab.subprocess, "run", return_value=subprocess.CompletedProcess([], 3, "prévia", "failure")):
            result = lab.run_check("failed", "harness", ["lua"], ROOT, 1)
        restored = json.loads(json.dumps(result))
        self.assertEqual(restored["returncode"], 3)
        self.assertEqual(restored["status"], "failed")
        self.assertEqual(restored["stderr"], "failure")
        self.assertEqual(restored["stdout"], "prévia")

    def test_commands_preserve_spaces_and_do_not_use_a_shell(self):
        command = ["C:/Lua tools/lua5.1.exe", "a test.lua", "C:/reference scripts"]
        with patch.object(lab.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "PASS", "")) as run:
            result = lab.run_check("safe-argv", "harness", command, ROOT, 2)
        self.assertEqual(run.call_args.args[0], command)
        self.assertIs(run.call_args.kwargs["shell"], False)
        self.assertEqual(run.call_args.kwargs["timeout"], 2)
        self.assertEqual(result["status"], "passed")

    def test_relative_executables_are_resolved_before_changing_directories(self):
        def check(check_id, kind, command, cwd, timeout, required=()):
            return {"id": check_id, "kind": kind, "status": "passed", "command": command,
                    "cwd": cwd, "stdout": "Lua 5.1.5", "stderr": ""}
        args = lab.argparse.Namespace(lua="tools/lua5.1.exe", luac="tools/luac5.1.exe",
                                      dst_scripts=None, timeout=1)
        report = {"checks": []}
        with patch.object(lab.shutil, "which", side_effect=[args.lua, args.luac]), \
                patch.object(lab, "git_metadata", return_value={}), \
                patch.object(lab, "run_check", side_effect=check), \
                patch("sys.stdout", new=io.StringIO()):
            lab.run_lab(report, args)
        expected_lua = str(Path(args.lua).resolve())
        self.assertEqual(report["checks"][0]["command"][0], expected_lua)
        self.assertEqual(report["checks"][1]["command"][0], str(Path(args.luac).resolve()))
        config = next(result for result in report["checks"]
                      if result["id"] == lab.MOD + "/tests/mam_config_test.lua")
        self.assertEqual(config["command"][0], expected_lua)
        self.assertEqual(config["cwd"], ROOT / lab.MOD)
        native = [result for result in report["checks"] if result["kind"] == "native_script_harness"]
        self.assertEqual(len(native), 3)
        self.assertTrue(all(result["status"] == "not_run" for result in native))

    def test_lua_version_probe_accepts_only_lua_51(self):
        for version, expected in (("Lua 5.1.5", "passed"), ("Lua 5.4.8", "failed"), ("LuaJIT 2.1", "failed"), ("", "failed")):
            with self.subTest(version=version):
                with patch.object(lab.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "", version)):
                    result = lab.probe_lua("lua", "lua", ROOT, 1)
                self.assertEqual(result["status"], expected)

    def test_source_fingerprints_detect_changes_and_deletion(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "example.lua"
            path.write_text("return 1", encoding="utf-8")
            before = lab.fingerprint(root, [path])
            path.write_text("return 2", encoding="utf-8")
            self.assertNotEqual(before, lab.fingerprint(root, [path]))
            path.unlink()
            self.assertIsNone(lab.fingerprint(root, [path])["example.lua"])

    def test_summary_keeps_asset_failure_and_unrun_gates_separate(self):
        report = {"checks": [
            {"kind": "harness", "status": "passed"},
            {"kind": "static", "status": "failed"},
            {"kind": "native_script_harness", "status": "not_run"},
        ], "gates": dict(lab.UNRUN_GATES)}
        lab.finalize(report)
        self.assertEqual(report["local_checks_status"], "failed")
        self.assertEqual(report["summary"]["static"]["failed"], 1)
        self.assertEqual(report["gates"]["dst_runtime"], "not_run")
        self.assertEqual(report["gates"]["manual_gameplay"], "not_run")
        self.assertEqual(report["gates"]["ci"], "not_run")
        self.assertEqual(report["gates"]["packaging"], "not_run")

    def test_requested_but_blocked_checks_fail_the_local_run(self):
        report = {"checks": [{"kind": "harness", "status": "blocked"}]}
        lab.finalize(report)
        self.assertEqual(report["local_checks_status"], "failed")

    def test_empty_lab_cannot_report_success(self):
        report = {"checks": []}
        lab.finalize(report)
        self.assertEqual(report["local_checks_status"], "failed")

    def test_existing_output_is_never_overwritten_and_no_tests_run(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "report.json"
            output.write_text("keep me", encoding="utf-8")
            with patch.object(lab, "run_lab") as run, patch("sys.stderr", new=io.StringIO()):
                code = lab.main(["--output", str(output)])
            self.assertEqual(code, 2)
            run.assert_not_called()
            self.assertEqual(output.read_text(encoding="utf-8"), "keep me")

    def test_invalid_timeout_is_rejected_before_execution(self):
        for value in ("0", "-1", "nan", "inf"):
            with self.subTest(value=value), patch("sys.stderr", new=io.StringIO()):
                with patch.object(lab, "run_lab") as run:
                    with self.assertRaises(SystemExit) as error:
                        lab.main(["--timeout", value, "--output", "unused.json"])
                    self.assertEqual(error.exception.code, 2)
                    run.assert_not_called()

    def test_cli_records_failures_and_returns_nonzero(self):
        def fill(report, args):
            report["checks"].append({"kind": "static", "status": "failed", "stderr": "missing asset"})
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "report.json"
            with patch.object(lab, "run_lab", side_effect=fill), patch("sys.stdout", new=io.StringIO()):
                code = lab.main(["--output", str(output)])
            report = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(code, 1)
        self.assertEqual(report["schema"], "dst-lab/v1")
        self.assertEqual(report["local_checks_status"], "failed")
        self.assertEqual(report["checks"][0]["stderr"], "missing asset")

    def test_interruption_preserves_partial_report(self):
        def interrupt(report, args):
            report["checks"].append({"kind": "harness", "status": "passed"})
            raise KeyboardInterrupt()
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "report.json"
            with patch.object(lab, "run_lab", side_effect=interrupt), patch("sys.stdout", new=io.StringIO()):
                code = lab.main(["--output", str(output)])
            report = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(code, 130)
        self.assertEqual(report["local_checks_status"], "interrupted")
        self.assertEqual(len(report["checks"]), 1)


if __name__ == "__main__":
    unittest.main()
