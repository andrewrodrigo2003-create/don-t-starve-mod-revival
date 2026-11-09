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
    if target.is_dir():
        for path in sorted(p for p in target.rglob("*") if p.is_file()):
            try:
                data = path.read_bytes()
            except OSError as exc:
                yield path.as_posix(), None, str(exc)
                continue
            yield path.relative_to(target).as_posix(), data, None
    elif target.is_file() and zipfile.is_zipfile(target):
        with zipfile.ZipFile(target) as archive:
            for info in sorted(archive.infolist(), key=lambda x: x.filename):
                name = info.filename
                if info.is_dir():
                    continue
                # Reject traversal-like names in reports; never extract archive paths.
                if PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts:
                    yield name, None, "unsafe archive path skipped"
                    continue
                try:
                    yield name, archive.read(info), None
                except (OSError, zipfile.BadZipFile, RuntimeError) as exc:
                    yield name, None, str(exc)
    else:
        raise ValueError("Target must be a directory or a readable ZIP archive.")

def audit(target: Path, run_luac: bool = False) -> dict:
    files, signals, errors, lua_paths = [], [], [], []
    for name, data, error in source_entries(target):
        if error:
            errors.append({"path": name, "error": error})
            continue
        assert data is not None
        item = {"path": name, "size_bytes": len(data), "sha256": sha256_bytes(data)}
        files.append(item)
        if name.lower().endswith(".lua"):
            lua_paths.append(name)
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
