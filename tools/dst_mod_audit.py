#!/usr/bin/env python3
"""Read-only DST/Lua mod triage: inventory, SHA-256, API/hook signals, optional luac check.

This tool never executes scanned mod code. It reads a directory or ZIP archive and
produces JSON. Signals are leads for human review, not proof of a vulnerability.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path, PurePosixPath
from typing import Iterable

TEXT_SUFFIXES = {".lua", ".txt", ".json", ".xml", ".md", ".cfg", ".ini"}
MAX_TEXT_BYTES = 8 * 1024 * 1024
MAX_FILE_BYTES = 64 * 1024 * 1024
MAX_TOTAL_BYTES = 512 * 1024 * 1024
MAX_ZIP_COMPRESSION_RATIO = 200

PATTERNS = {
    "spell_api": re.compile(r"\b(?:SetSpellFn|aoespell|spellcaster)\b", re.I),
    "prefab_component_hooks": re.compile(
        r"\b(?:AddPrefabPostInit(?:Any)?|AddComponentPostInit|AddPlayerPostInit|AddSimPostInit)\b"
    ),
    "weapon_projectile_hooks": re.compile(
        r"\b(?:SetAltAttack|SetProjectile|CanRangedAttack|projectile)\b", re.I
    ),
    "mod_detection_and_recipes": re.compile(
        r"\b(?:KnownModIndex|IsModEnabled|GetModConfigData|AddRecipe2?|AddCharacterRecipe)\b"
    ),
    "global_mutation": re.compile(
        r"\b(?:rawset\s*\(\s*_G|setmetatable\s*\(\s*_G|GLOBAL\s*\.[A-Za-z_]\w*\s*=)"
    ),
    "dynamic_code_or_debug": re.compile(
        r"\b(?:loadstring|loadfile|debug\.getregistry|debug\.setmetatable|getfenv|setfenv|string\.dump)\b"
    ),
    "filesystem_or_process": re.compile(
        r"\b(?:io\.open|io\.popen|os\.execute|os\.remove|os\.rename)\b"
    ),
    "network_or_remote_calls": re.compile(
        r"\b(?:TheSim\s*:\s*QueryServer|TheNet\s*:\s*SendRemote|socket\.tcp|https?://)\b",
        re.I,
    ),
    "encoding_or_crypto_indicators": re.compile(
        r"\b(?:base64|decrypt|decryptstring|encrypt|compressstring|decompressstring|cipher|openssl)\b",
        re.I,
    ),
}

def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def decode_text(data: bytes) -> str | None:
    if len(data) > MAX_TEXT_BYTES or b"\x00" in data[:4096]:
        return None
    for encoding in ("utf-8-sig", "utf-8", "cp1252", "latin-1"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return None

def source_entries(target: Path):
    """Yield bounded file contents without following directory symlinks or extracting archives."""
    total_bytes = 0
    if target.is_dir():
        for path in sorted(target.rglob("*")):
            if path.is_symlink():
                yield path.relative_to(target).as_posix(), None, "symbolic link skipped"
                continue
            if not path.is_file():
                continue
            try:
                size = path.stat().st_size
                if size > MAX_FILE_BYTES:
                    yield path.relative_to(target).as_posix(), None, "file exceeds per-file size limit"
                    continue
                if total_bytes + size > MAX_TOTAL_BYTES:
                    yield path.relative_to(target).as_posix(), None, "directory scan total size limit reached"
                    continue
                data = path.read_bytes()
                if len(data) > MAX_FILE_BYTES:
                    yield path.relative_to(target).as_posix(), None, "file grew beyond per-file size limit while reading"
                    continue
                total_bytes += len(data)
            except OSError as exc:
                yield path.relative_to(target).as_posix(), None, str(exc)
                continue
            yield path.relative_to(target).as_posix(), data, None
    elif target.is_file() and zipfile.is_zipfile(target):
        with zipfile.ZipFile(target) as archive:
            for info in sorted(archive.infolist(), key=lambda x: x.filename):
                name = info.filename
                if info.is_dir():
                    continue
                archive_path = PurePosixPath(name)
                if archive_path.is_absolute() or ".." in archive_path.parts:
                    yield name, None, "unsafe archive path skipped"
                    continue
                if info.file_size > MAX_FILE_BYTES:
                    yield name, None, "archive entry exceeds per-file size limit"
                    continue
                if total_bytes + info.file_size > MAX_TOTAL_BYTES:
                    yield name, None, "archive scan total uncompressed size limit reached"
                    continue
                ratio = info.file_size / max(info.compress_size, 1)
                if ratio > MAX_ZIP_COMPRESSION_RATIO:
                    yield name, None, "archive entry exceeds compression-ratio limit"
                    continue
                try:
                    data = archive.read(info)
                    if len(data) != info.file_size:
                        yield name, None, "archive entry size did not match metadata"
                        continue
                    total_bytes += len(data)
                    yield name, data, None
                except (OSError, zipfile.BadZipFile, RuntimeError, zipfile.LargeZipFile) as exc:
                    yield name, None, str(exc)
    else:
        raise ValueError("Target must be a directory or a readable ZIP archive.")


def strip_lua_comments(source: str) -> str:
    """Mask Lua comments while preserving newlines and quoted strings for conservative scanning."""
    out = list(source)
    i, n = 0, len(source)
    quote = None
    while i < n:
        ch = source[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            i += 1
            continue
        if source.startswith("--", i):
            # Lua long comment: --[=[ ... ]=], with any number of '='.
            match = re.match(r"--\[(=*)\[", source[i:])
            if match:
                close = "]" + match.group(1) + "]"
                start = i
                body_start = i + match.end()
                end_at = source.find(close, body_start)
                end = n if end_at < 0 else end_at + len(close)
                for j in range(start, end):
                    if out[j] not in "\r\n":
                        out[j] = " "
                i = end
            else:
                end = source.find("\n", i)
                if end < 0:
                    end = n
                for j in range(i, end):
                    if out[j] != "\r":
                        out[j] = " "
                i = end
            continue
        i += 1
    return "".join(out)


def extract_registration_candidates(path: str, content: str) -> list[dict]:
    """Extract high-value DST registration/override signals; not a full Lua parser."""
    code = strip_lua_comments(content)
    patterns = [
        ("component_postinit", r"\bAddComponentPostInit\s*\(\s*['\"]([^'\"]+)['\"]", "additive", "informational"),
        ("prefab_postinit", r"\bAddPrefabPostInit(?:Any)?\s*\(\s*['\"]([^'\"]+)['\"]", "additive", "informational"),
        ("stategraph_postinit", r"\bAddStategraphPostInit\s*\(\s*['\"]([^'\"]+)['\"]", "additive", "informational"),
        ("stategraph_action_handler", r"\bAddStategraphActionHandler\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*ActionHandler\s*\(\s*ACTIONS\.([A-Za-z_]\w*)", "keyed_registration", "high"),
        ("stategraph_state", r"\bAddStategraphState\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]", "keyed_registration", "high"),
        ("action_definition", r"\bAddAction\s*\(\s*['\"]([^'\"]+)['\"]", "keyed_registration", "high"),
        ("action_assignment", r"\bACTIONS\.([A-Za-z_]\w*)\s*=", "replacement", "high"),
        ("global_assignment", r"\b(?:_G|GLOBAL)\.([A-Za-z_]\w*)\s*=", "replacement", "high"),
        ("entityscript_method_override", r"\b(?:function\s+EntityScript\s*[:.]|EntityScript\s*\.\s*)([A-Za-z_]\w*)", "replacement", "high"),
        ("container_widget_override", r"\bcontainers\.widgetsetup\s*=", "replacement", "high"),
    ]
    found = []
    for kind, pattern, operation, severity in patterns:
        for match in re.finditer(pattern, code):
            line = code.count("\n", 0, match.start()) + 1
            groups = [value for value in match.groups() if value is not None]
            target = "::".join(groups) if groups else kind
            found.append({
                "path": path,
                "line": line,
                "kind": kind,
                "target": target,
                "operation": operation,
                "severity_if_competing": severity,
            })
    return found



def is_single_mod_root(target: Path) -> bool:
    if target.is_dir():
        return (target / "modmain.lua").exists() or (target / "modinfo.lua").exists()
    if target.is_file() and zipfile.is_zipfile(target):
        with zipfile.ZipFile(target) as archive:
            return any(
                len(PurePosixPath(info.filename).parts) == 1
                and PurePosixPath(info.filename).name in {"modmain.lua", "modinfo.lua"}
                for info in archive.infolist()
            )
    return False


def resolve_mod_id(path: str, target: Path, single_root: bool) -> str:
    if single_root:
        return target.stem if target.is_file() else target.name
    parts = PurePosixPath(path).parts
    return parts[0] if len(parts) > 1 else target.name


def extract_modinfo_metadata(path: str, content: str, mod_id: str) -> dict:
    """Read only simple literal modinfo fields; never execute modinfo.lua."""
    code = strip_lua_comments(content)
    name_match = re.search(r"(?m)^\s*name\s*=\s*['\"]([^'\"]+)['\"]", code)
    priority_match = re.search(r"(?m)^\s*priority\s*=\s*(-?\d+)", code)
    dependencies_match = re.search(r"\bmod_dependencies\s*=\s*\{([^}]*)\\}", code, re.S)
    dependencies = (
        re.findall(r"['\"]([^'\"]+)['\"]", dependencies_match.group(1))
        if dependencies_match else []
    )
    return {
        "mod_id": mod_id,
        "path": path,
        "name": name_match.group(1) if name_match else None,
        "priority": int(priority_match.group(1)) if priority_match else None,
        "mod_dependencies": dependencies,
        "metadata_is_partial": name_match is None or priority_match is None,
    }


def find_cross_mod_conflicts(candidates: list[dict], target: Path, metadata_by_mod: dict | None = None) -> list[dict]:
    """Group repeated registrations across top-level mod folders; report candidates, not verdicts."""
    groups: dict[tuple[str, str], list[dict]] = {}
    single_mod_root = is_single_mod_root(target)
    metadata_by_mod = metadata_by_mod or {}
    for item in candidates:
        mod_id = resolve_mod_id(item["path"], target, single_mod_root)
        item["mod_id"] = mod_id
        key = (item["kind"], item["target"])
        groups.setdefault(key, []).append(item)

    conflicts = []
    additive = {"component_postinit", "prefab_postinit", "stategraph_postinit"}
    for (kind, symbol), entries in sorted(groups.items()):
        mods = sorted({entry["mod_id"] for entry in entries})
        if len(mods) < 2:
            continue
        if kind in additive:
            severity = "informational"
            interpretation = "Multiple post-init registrations can be additive; inspect callback behavior and order."
        else:
            severity = "high"
            interpretation = "The same keyed registration or replacement appears in multiple mod folders; inspect actual registration semantics and load order."
        conflicts.append({
            "kind": kind,
            "target": symbol,
            "severity": severity,
            "mods": mods,
            "occurrences": entries,
            "mod_details": {mod: metadata_by_mod.get(mod) for mod in mods},
            "interpretation": interpretation,
        })
    return conflicts


def audit(target: Path, run_luac: bool = False) -> dict:
    files, signals, errors, lua_paths, registrations = [], [], [], [], []
    mod_metadata = {}
    single_mod_root = is_single_mod_root(target)
    for name, data, error in source_entries(target):
        if error:
            errors.append({"path": name, "error": error})
            continue
        assert data is not None
        item = {"path": name, "size_bytes": len(data), "sha256": sha256_bytes(data)}
        files.append(item)
        if name.lower().endswith(".lua"):
            lua_paths.append(name)
            decoded_lua = decode_text(data)
            if decoded_lua is not None:
                registrations.extend(extract_registration_candidates(name, decoded_lua))
                if PurePosixPath(name).name.lower() == "modinfo.lua":
                    mod_id = resolve_mod_id(name, target, single_mod_root)
                    mod_metadata[mod_id] = extract_modinfo_metadata(name, decoded_lua, mod_id)
        if Path(name).suffix.lower() not in TEXT_SUFFIXES:
            continue
        content = decode_text(data)
        if content is None:
            continue
        for line_no, line in enumerate(content.splitlines(), 1):
            for category, pattern in PATTERNS.items():
                if pattern.search(line):
                    signals.append({
                        "path": name,
                        "line": line_no,
                        "category": category,
                        "snippet": line.strip()[:240],
                    })

    lua_check = {"requested": run_luac, "available": False, "checked": 0, "failures": []}
    if run_luac:
        compiler = shutil.which("luac5.1") or shutil.which("luac")
        lua_check["available"] = bool(compiler)
        if compiler and target.is_dir():
            for rel in lua_paths:
                result = subprocess.run(
                    [compiler, "-p", str(target / rel)],
                    capture_output=True, text=True, check=False,
                )
                lua_check["checked"] += 1
                if result.returncode:
                    lua_check["failures"].append({
                        "path": rel,
                        "stderr": (result.stderr or result.stdout).strip()[:1000],
                    })
        elif compiler and target.is_file():
            lua_check["failures"].append({
                "path": str(target),
                "stderr": "ZIP contents inventoried; extract to a review directory to run luac safely.",
            })

    return {
        "schema": "dst-mod-audit/v1",
        "target": str(target),
        "read_only": True,
        "executed_scanned_code": False,
        "file_count": len(files),
        "lua_file_count": len(lua_paths),
        "files": files,
        "signals": signals,
        "registration_candidates": registrations,
        "mod_metadata": [mod_metadata[key] for key in sorted(mod_metadata)],
        "potential_cross_mod_conflicts": find_cross_mod_conflicts(registrations, target, mod_metadata),
        "read_errors": errors,
        "lua_syntax_check": lua_check,
        "interpretation": (
            "Static indicators only. A match is not proof of a defect or malicious behavior; "
            "absence of a match is not proof of safety or compatibility."
        ),
    }

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", type=Path, help="Mod folder or ZIP archive")
    parser.add_argument("--lua-check", action="store_true", help="Run luac -p on Lua files in a folder if available")
    parser.add_argument("--output", type=Path, help="Write JSON report to this path")
    args = parser.parse_args(argv)
    try:
        report = audit(args.target, args.lua_check)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(f"audit failed: {exc}", file=sys.stderr)
        return 2
    rendered = json.dumps(report, indent=2, ensure_ascii=False)
    if args.output:
        args.output.write_text(rendered + "\n", encoding="utf-8")
    else:
        print(rendered)
    return 1 if report["read_errors"] or report["lua_syntax_check"]["failures"] else 0

if __name__ == "__main__":
    raise SystemExit(main())
