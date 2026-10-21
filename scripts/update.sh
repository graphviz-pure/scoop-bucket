#!/usr/bin/env bash
# Rewrites bucket/graphviz-pure.json for the latest verified release.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! gh release view --repo graphviz-pure/graphviz-pure >/dev/null 2>&1; then
  echo "no release yet" >&2; exit 0
fi
version=$(scripts/fetch-verified.sh '*-pc-windows-msvc.zip')
sha() { (cd dist && sha256sum "graphviz-pure-$version-$1.zip" | cut -d' ' -f1); }
base="https://github.com/graphviz-pure/graphviz-pure/releases/download/v$version"
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
echo "$version"
