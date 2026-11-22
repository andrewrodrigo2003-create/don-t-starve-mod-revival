#!/usr/bin/env python3
from pathlib import Path
import re
import zipfile

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[1]
DIST = ROOT / "dist" / "modxpector"

def main():
    info = (HERE / "modinfo.lua").read_text(encoding="utf-8")
    match = re.search(r'version\s*=\s*"([^"]+)"', info)
    if not match:
        raise SystemExit("Versão não encontrada em modinfo.lua")
    version = match.group(1)
    DIST.mkdir(parents=True, exist_ok=True)
    archive = DIST / f"ModXpector-{version}-test.zip"
    files = sorted(p for p in HERE.rglob("*") if p.is_file() and "tests" not in p.parts and "tools" not in p.parts and "docs" not in p.parts)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for path in files:
            z.write(path, f"dst_mod_inspector/{path.relative_to(HERE).as_posix()}")
        z.write(HERE / "README.md", "dst_mod_inspector/README.md")
    with zipfile.ZipFile(archive) as z:
        bad = z.testzip()
        if bad:
            raise SystemExit(f"ZIP inválido: {bad}")
    print(f"{archive} ({archive.stat().st_size} bytes)")

if __name__ == "__main__":
    main()
