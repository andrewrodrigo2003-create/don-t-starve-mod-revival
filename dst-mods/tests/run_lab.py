#!/usr/bin/env python3
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
MOD = "dst-mods/metals_and_reforged"
LUA_TESTS = tuple("dst-mods/tests/" + name + ".lua" for name in (
    "smelting_module_harness", "forecast_ambiguous_start_test",
    "legacy_recipe_default_weight_test", "gold_ore_migration_test",
    "recipe_application_retry_test", "smelter_component_lifecycle_test",
    "smelter_destruction_harvest_test", "smelter_stack_settings_test",
    "metal_storage_chest_test", "metal_storage_chest_deprecation_test",
    "metal_deconstruction_test", "recipe_station_migration_test",
    "tool_gated_crafting_test", "station_storage_localization_test",
    "mam_localization_runtime_test", "um_beta_loot_compatibility_test",
    "mam_tech_tree_runtime_test", "loot_rewrite_runtime_test",
    "weapon_compatibility_contract_test",
    "combat_wrapper_contract_test", "combat_area_compatibility_characterization_test",
    "forge_pack_combat_api_characterization_test", "forge_visual_preview_test",
    "stategraph_compatibility_test", "container_widget_compatibility_test",
    "character_ability_compatibility_test", "smelter_simulator_integration_test",
    "simulator_bootstrap_test", "simulator_container_test", "simulator_network_test",
    "modded_regrow_save_reference_test",
)) + (MOD + "/tests/mam_config_test.lua",)
PYTHON_TESTS = (
    "dst-mods/tests/legacy_forge_weapon_gate_test.py",
    "dst-mods/tests/metallurgy_reference_book_contract_test.py",
    "dst-mods/tests/robot_forge_automation_contract_test.py",
    "dst-mods/tests/warworkbench_tech_contract_test.py",
    "dst-mods/tests/mod_asset_reference_test.py",
    "tests/test_mam_crafting_balance_contract.py",
    "tests/test_mam_localization.py",
    "tests/test_minimap_update_optimization.py",
    "tests/test_dst_lab_runner.py",
)
SIMULATIONS = {
    "simulator_bootstrap_test.lua", "simulator_container_test.lua",
    "simulator_network_test.lua", "smelter_simulator_integration_test.lua",
}
NATIVE_TESTS = {
    "metal_deconstruction_test.lua": ("components/inventory.lua", "components/container.lua"),
    "tool_gated_crafting_test.lua": (
        "components/builder.lua", "components/builder_replica.lua", "components/inventory_replica.lua",
        "components/tool.lua", "components/finiteuses.lua", "widgets/redux/craftingmenu_hud.lua",
        "recipes.lua", "speech_wilson.lua",
    ),
    "station_storage_localization_test.lua": ("actions.lua", "strings.lua", "speech_wilson.lua"),
}
UNRUN_GATES = {name: "not_run" for name in ("ci", "packaging", "dst_runtime", "manual_gameplay", "multiplayer_mod_stack")}


def timestamp():
    return datetime.now(timezone.utc).isoformat()


def text(value):
    return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else value or ""


def run_check(check_id, kind, command, cwd, timeout, required=()):
    result = {
        "id": check_id, "kind": kind, "command": [str(value) for value in command],
        "cwd": str(cwd), "started_at": timestamp(), "returncode": None,
        "stdout": "", "stderr": "", "status": "blocked", "duration_seconds": 0,
    }
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        result["stderr"] = "Required files missing: " + ", ".join(missing)
        return result
    started = time.monotonic()
    try:
        process = subprocess.run(result["command"], cwd=cwd, timeout=timeout, shell=False,
                                 capture_output=True, text=True, encoding="utf-8", errors="replace")
        result.update(returncode=process.returncode, stdout=process.stdout, stderr=process.stderr,
                      status="passed" if process.returncode == 0 else "failed")
    except subprocess.TimeoutExpired as error:
        result.update(status="failed", stdout=text(error.stdout),
                      stderr=text(error.stderr) + f"\nTimeout after {timeout} seconds")
    except OSError as error:
        result["stderr"] = str(error)
    result["duration_seconds"] = round(time.monotonic() - started, 4)
    return result


def probe_lua(check_id, executable, root, timeout):
    result = run_check(check_id, "tooling", [executable, "-v"], root, timeout)
    if result["status"] == "passed" and not re.search(r"\bLua 5\.1(?:\.|\s|$)", result["stdout"] + result["stderr"]):
        result.update(status="failed", stderr=result["stderr"] + "\nLua 5.1 is required; no automatic installation.")
    return result


def test_cwd(root, relative):
    return root / MOD if relative == MOD + "/tests/mam_config_test.lua" else root


def fingerprint(root, paths):
    return {path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            if path.is_file() else None for path in sorted(set(paths))}


def git_metadata(root, timeout):
    metadata = {}
    for key, command in (
        ("head", ["rev-parse", "HEAD"]),
        ("branch", ["branch", "--show-current"]),
        ("working_tree", ["status", "--porcelain", "--untracked-files=normal"]),
    ):
        result = run_check("git:" + key, "provenance", ["git", *command], root, timeout)
        metadata[key] = result["stdout"].rstrip() if result["status"] == "passed" else None
        if result["status"] != "passed":
            metadata[key + "_error"] = result["stderr"]
    metadata["dirty"] = bool(metadata["working_tree"]) if metadata["working_tree"] is not None else None
    return metadata


def run_lab(report, args):
    def record(result, quiet=False):
        report["checks"].append(result)
        if not quiet:
            print(f"{timestamp()} {result['status'].upper():8} {result['id']}", flush=True)
        return result

    report["repository"] = {"root": str(ROOT), **git_metadata(ROOT, args.timeout)}
    report["environment"] = {"python": sys.version, "platform": platform.platform(), "dst_build": "unverified"}
    lua_paths = sorted((ROOT / MOD).rglob("*.lua")) + sorted((ROOT / "dst-mods/tests").rglob("*.lua"))
    source_paths = lua_paths + [ROOT / name for name in PYTHON_TESTS] + [Path(__file__).resolve()]
    report["source_sha256"] = fingerprint(ROOT, source_paths)
    references = []
    if args.dst_scripts is not None:
        args.dst_scripts = args.dst_scripts.resolve()
        references = [args.dst_scripts / name for paths in NATIVE_TESTS.values() for name in paths]
        report["native_sources"] = {
            "directory": str(args.dst_scripts), "sha256": fingerprint(args.dst_scripts, references),
            "limitation": "Supplied DST Lua sources with stub entities; no engine execution or automatic origin/build verification.",
        }
    lua = shutil.which(args.lua)
    lua = str(Path(lua).resolve()) if lua else args.lua
    luac = shutil.which(args.luac)
    luac = str(Path(luac).resolve()) if luac else args.luac
    lua_ready = record(probe_lua("lua-version", lua, ROOT, args.timeout))["status"] == "passed"
    luac_ready = record(probe_lua("luac-version", luac, ROOT, args.timeout))["status"] == "passed"
    if not lua_paths:
        record({"id": "lua-syntax", "kind": "static", "status": "blocked", "stderr": "No Lua sources found."})
    for path in lua_paths:
        check_id = "syntax:" + path.relative_to(ROOT).as_posix()
        if luac_ready:
            record(run_check(check_id, "static", [luac, "-p", str(path)], ROOT, args.timeout, [path]), quiet=True)
        else:
            record({"id": check_id, "kind": "static", "status": "blocked", "stderr": "Lua 5.1 compiler unavailable."}, quiet=True)
    print(f"{timestamp()} Lua syntax checks recorded: {len(lua_paths)}", flush=True)
    for relative in LUA_TESTS:
        path = ROOT / relative
        kind = "simulation" if path.name in SIMULATIONS else "harness"
        if lua_ready:
            record(run_check(relative, kind, [lua, str(path)], test_cwd(ROOT, relative), args.timeout, [path]))
        else:
            record({"id": relative, "kind": kind, "status": "blocked", "stderr": "Lua 5.1 runtime unavailable."})
    for relative in PYTHON_TESTS:
        path = ROOT / relative
        kind = "harness" if path.name == "test_dst_lab_runner.py" else "static"
        record(run_check(relative, kind, [sys.executable, "-B", str(path)], ROOT, args.timeout, [path]))
    for name, required in NATIVE_TESTS.items():
        check_id = "native:" + name
        kind = "native_script_harness"
        if args.dst_scripts is None:
            record({"id": check_id, "kind": kind, "status": "not_run", "reason": "No --dst-scripts directory supplied."})
        elif not lua_ready:
            record({"id": check_id, "kind": kind, "status": "blocked", "stderr": "Lua 5.1 runtime unavailable."})
        else:
            path = ROOT / "dst-mods/tests" / name
            record(run_check(check_id, kind, [lua, str(path), str(args.dst_scripts)], ROOT, args.timeout,
                             [path, *(args.dst_scripts / value for value in required)]))
    after = fingerprint(ROOT, source_paths)
    current_paths = sorted((ROOT / MOD).rglob("*.lua")) + sorted((ROOT / "dst-mods/tests").rglob("*.lua"))
    changed = report["source_sha256"] != after or set(current_paths) != set(lua_paths)
    if args.dst_scripts is not None:
        changed = changed or report["native_sources"]["sha256"] != fingerprint(args.dst_scripts, references)
    record({"id": "source-integrity", "kind": "provenance", "status": "failed" if changed else "passed",
            "detail": "Source changed during execution; rerun before using these results." if changed
                      else "Recorded source files stayed unchanged during execution."})


def finalize(report):
    summary = {}
    for result in report["checks"]:
        counts = summary.setdefault(result["kind"], Counter())
        counts[result["status"]] += 1
    report["summary"] = {kind: dict(counts) for kind, counts in summary.items()}
    report["finished_at"] = timestamp()
    passed = any(result["status"] == "passed" for result in report["checks"])
    failed = any(result["status"] in ("failed", "blocked") for result in report["checks"])
    report["local_checks_status"] = "passed" if passed and not failed else "failed"


def positive_timeout(value):
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError("timeout must be a finite positive number")
    return number


def main(argv=None):
    parser = argparse.ArgumentParser(description="Run local MAM/DST lab checks without launching or installing the game.")
    parser.add_argument("--lua", default="lua5.1", help="Lua 5.1 executable name or path")
    parser.add_argument("--luac", default="luac5.1", help="Lua 5.1 compiler name or path")
    parser.add_argument("--dst-scripts", type=Path, help="Optional trusted, locally extracted DST scripts for native-source harnesses")
    parser.add_argument("--timeout", type=positive_timeout, default=120, help="Maximum seconds per subprocess (default: 120)")
    parser.add_argument("--output", type=Path, required=True, help="New JSON report path; parent must exist; never overwrites a report")
    args = parser.parse_args(argv)
    report = {"schema": "dst-lab/v1", "started_at": timestamp(), "checks": [], "gates": dict(UNRUN_GATES),
              "limitations": "Local checks only. No full mod bootstrap, DST engine, rendering, game save/load, real networking or mod-list certification."}
    interrupted = False
    try:
        with args.output.open("x", encoding="utf-8") as output:
            try:
                run_lab(report, args)
            except KeyboardInterrupt:
                interrupted = True
            except (OSError, ValueError) as error:
                report["checks"].append({"id": "lab-infrastructure", "kind": "tooling", "status": "blocked", "stderr": str(error)})
            finalize(report)
            if interrupted:
                report["local_checks_status"] = "interrupted"
            json.dump(report, output, indent=2, ensure_ascii=False)
            output.write("\n")
    except OSError as error:
        print(f"Cannot create/write laboratory report: {error}", file=sys.stderr)
        return 2
    print(f"{timestamp()} Local checks: {report['local_checks_status']}; DST runtime/CI/packaging: not run")
    print(f"Report: {args.output.resolve()}")
    return 130 if interrupted else 0 if report["local_checks_status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
