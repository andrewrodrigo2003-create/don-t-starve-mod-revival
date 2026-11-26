#!/usr/bin/env python3
"""Build a clean, installable ModXpector archive (runtime files only)."""
from pathlib import Path
import re
import zipfile

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[1]
DIST = ROOT / "dist" / "modxpector"
PACKAGE_ROOT = "dst_mod_inspector"

def _validate_runtime_file(path, root):
    relative = path.relative_to(HERE).as_posix()
    current = path
    while current != HERE:
        if current.is_symlink():
            raise SystemExit(f"Symlink bloqueado no pacote: {relative}")
        current = current.parent

    try:
        resolved = path.resolve(strict=True)
        resolved.relative_to(root)
    except (OSError, RuntimeError, ValueError):
        raise SystemExit(f"Caminho de runtime fora da raiz ou inválido: {relative}")
    if not resolved.is_file():
        raise SystemExit(f"Arquivo de runtime inválido: {relative}")


def runtime_files():
    root = HERE.resolve()
    required = [HERE / "modinfo.lua", HERE / "modmain.lua"]
    for path in required:
        if path.is_symlink():
            raise SystemExit(f"Symlink bloqueado no pacote: {path.relative_to(HERE)}")
        if not path.is_file():
            raise SystemExit(f"Arquivo obrigatório ausente: {path.relative_to(HERE)}")
        _validate_runtime_file(path, root)

    scripts_dir = HERE / "scripts"
    if scripts_dir.is_symlink():
        raise SystemExit("Symlink bloqueado no pacote: scripts")
    files = list(required)
    if scripts_dir.exists():
        if not scripts_dir.is_dir():
            raise SystemExit("Diretório de runtime inválido: scripts")
        for path in sorted(scripts_dir.rglob("*")):
            if path.is_symlink():
                raise SystemExit(f"Symlink bloqueado no pacote: {path.relative_to(HERE)}")
            if path.is_file() and path.suffix == ".lua" and path.name != "bridge_token.txt":
                _validate_runtime_file(path, root)
                files.append(path)

    if len(files) <= 2:
        raise SystemExit("Nenhum script de runtime encontrado.")
    return files

def main():
    info = (HERE / "modinfo.lua").read_text(encoding="utf-8")
    match = re.search(r'version\s*=\s*"([^"]+)"', info)
    if not match:
        raise SystemExit("Versão não encontrada em modinfo.lua")
    version = match.group(1)
    DIST.mkdir(parents=True, exist_ok=True)
    archive = DIST / f"ModXpector-{version}-test.zip"
    files = runtime_files()
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for path in files:
            relative = path.relative_to(HERE).as_posix()
            if relative.startswith(("tests/", "tools/", "docs/")) or relative == "README.md":
                raise SystemExit(f"Arquivo de desenvolvimento bloqueado no pacote: {relative}")
            z.write(path, f"{PACKAGE_ROOT}/{relative}")
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        bad = z.testzip()
        if bad:
            raise SystemExit(f"ZIP inválido: {bad}")
        if not names or any(not name.startswith(f"{PACKAGE_ROOT}/") for name in names):
            raise SystemExit("Estrutura de pacote inválida.")
        forbidden = ("/tests/", "/tools/", "/docs/", "README.md")
        leaked = [name for name in names if any(part in name for part in forbidden)]
        if leaked:
            raise SystemExit("Arquivos extras encontrados: " + ", ".join(leaked))
        if f"{PACKAGE_ROOT}/modinfo.lua" not in names or f"{PACKAGE_ROOT}/modmain.lua" not in names:
            raise SystemExit("Pacote sem modinfo.lua ou modmain.lua.")
    print(f"OK: {archive} ({archive.stat().st_size} bytes; {len(files)} arquivos de runtime)")
    for name in names:
        print(name)

if __name__ == "__main__":
    main()
