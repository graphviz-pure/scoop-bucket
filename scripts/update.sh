#!/usr/bin/env bash
# Rewrites bucket/graphviz-pure.json for the latest verified release.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! gh release view --repo graphviz-pure/graphviz-pure >/dev/null 2>&1; then
  echo "no release yet" >&2; exit 0
fi
version=$(scripts/fetch-verified.sh '*-pc-windows-msvc*.zip')
sha() { (cd dist && sha256sum "graphviz-pure-$version-$1.zip" | cut -d' ' -f1); }
base="https://github.com/graphviz-pure/graphviz-pure/releases/download/v$version"
python3 - "$version" <<'PYTHON'
import pathlib
import sys
import zipfile
name = f"graphviz-pure-{sys.argv[1]}-x86_64-pc-windows-msvc"
with zipfile.ZipFile(f"dist/{name}.zip") as archive:
    has_launcher = any(p.endswith("/graphviz-pure-launcher.exe") for p in archive.namelist())
if has_launcher and not pathlib.Path(f"dist/{name}-compat.zip").is_file():
    sys.exit("missing x86-64 compat archive: refusing a v3-only installation")
PYTHON
cat > bucket/graphviz-pure.json <<JSON
{
    "version": "$version",
    "description": "Pure-Rust port of Graphviz 16.1.0, same output on every platform (not affiliated with Graphviz)",
    "homepage": "https://graphviz-pure.github.io/",
    "license": "EPL-2.0",
    "architecture": {
        "64bit": {
            "url": "$base/graphviz-pure-$version-x86_64-pc-windows-msvc.zip",
            "hash": "$(sha x86_64-pc-windows-msvc)",
            "extract_dir": "graphviz-pure-$version-x86_64-pc-windows-msvc"
        },
        "arm64": {
            "url": "$base/graphviz-pure-$version-aarch64-pc-windows-msvc.zip",
            "hash": "$(sha aarch64-pc-windows-msvc)",
            "extract_dir": "graphviz-pure-$version-aarch64-pc-windows-msvc"
        }
    },
    "bin": "graphviz-pure.exe"
}
JSON
# Keep old baseline-only releases installable. New x86-64 releases install the
# same launcher + v3/compat directory layout as the PyPI wheel and container.
if [ -f "dist/graphviz-pure-$version-x86_64-pc-windows-msvc-compat.zip" ]; then
  python3 - "$version" "$(sha x86_64-pc-windows-msvc)" "$(sha x86_64-pc-windows-msvc-compat)" <<'PYTHON'
import json
import sys
version, v3_hash, compat_hash = sys.argv[1:]
name = f"graphviz-pure-{version}-x86_64-pc-windows-msvc"
base = f"https://github.com/graphviz-pure/graphviz-pure/releases/download/v{version}"
path = "bucket/graphviz-pure.json"
with open(path) as f:
    manifest = json.load(f)
manifest["architecture"]["64bit"] = {
    "url": [f"{base}/{name}.zip", f"{base}/{name}-compat.zip"],
    "hash": [v3_hash, compat_hash],
    "extract_dir": [name, name + "-compat"],
    "extract_to": ["v3", "compat"],
    "pre_install": 'Move-Item -LiteralPath "$dir\\v3\\graphviz-pure-launcher.exe" -Destination "$dir\\graphviz-pure.exe"',
}
with open(path, "w") as f:
    f.write(json.dumps(manifest, indent=4) + "\n")
PYTHON
fi
echo "$version"
