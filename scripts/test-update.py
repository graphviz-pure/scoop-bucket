#!/usr/bin/env python3
"""Exercise the update generator with verified-asset fixtures; no network or publication."""
import io
import json
import os
import pathlib
import shutil
import subprocess
import tarfile
import tempfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
BREW = (ROOT / "Formula").is_dir()
DEST = "Formula/graphviz-pure.rb" if BREW else "bucket/graphviz-pure.json"
TARGETS = (["x86_64-apple-darwin", "aarch64-apple-darwin", "x86_64-unknown-linux-musl", "aarch64-unknown-linux-musl"]
           if BREW else ["x86_64-pc-windows-msvc", "aarch64-pc-windows-msvc"])
for case in ("legacy", "dual", "missing-compat"):
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        for directory in ("scripts", "dist", "bin", str(pathlib.Path(DEST).parent)):
            (root / directory).mkdir(exist_ok=True)
        shutil.copy(ROOT / "scripts/update.sh", root / "scripts/update.sh")
        for path, body in [("scripts/fetch-verified.sh", "echo 1.1.0"), ("bin/gh", "exit 0")]:
            (root / path).write_text("#!/bin/sh\n" + body + "\n")
            (root / path).chmod(0o755)
        for target in TARGETS:
            for suffix in (["", "-compat"] if case != "legacy" and target.startswith("x86_64") else [""]):
                name = f"graphviz-pure-1.1.0-{target}{suffix}"
                exe = "graphviz-pure" + ("" if BREW else ".exe")
                payload = {exe: b"fixture"}
                if case != "legacy" and target.startswith("x86_64") and not suffix:
                    payload["graphviz-pure-launcher" + ("" if BREW else ".exe")] = b"launcher"
                if BREW:
                    with tarfile.open(root / f"dist/{name}.tar.gz", "w:gz") as archive:
                        for path, data in payload.items():
                            member = tarfile.TarInfo(name + "/" + path)
                            member.size = len(data)
                            archive.addfile(member, io.BytesIO(data))
                else:
                    with zipfile.ZipFile(root / f"dist/{name}.zip", "w") as archive:
                        for path, data in payload.items():
                            archive.writestr(name + "/" + path, data)
        if case == "missing-compat":
            next((root / "dist").glob("*-compat.*")).unlink()
        result = subprocess.run(["bash", str(root / "scripts/update.sh")], capture_output=True,
                                env=dict(os.environ, PATH=str(root / "bin") + ":" + os.environ["PATH"]))
        if case == "missing-compat":
            assert result.returncode and b"missing" in result.stderr, result
            continue
        assert result.returncode == 0, result.stderr
        text = (root / DEST).read_text()
        if BREW:
            subprocess.run(["ruby", "-c", str(root / DEST)], check=True)
            assert text.count('resource "compat" do') == (2 if case == "dual" else 0)
            assert '(libexec/"v3").install' in text and 'bin.install_symlink libexec/"graphviz-pure"' in text
        else:
            manifest = json.loads(text)
            entry = manifest["architecture"]["64bit"]
            assert isinstance(entry["url"], list) == (case == "dual")
            if case == "dual":
                assert entry["extract_to"] == ["v3", "compat"]
                assert len(entry["url"]) == len(entry["hash"]) == len(entry["extract_dir"]) == 2
                assert entry["pre_install"] == 'Move-Item -LiteralPath "$dir\\v3\\graphviz-pure-launcher.exe" -Destination "$dir\\graphviz-pure.exe"'
            assert isinstance(manifest["architecture"]["arm64"]["url"], str)
print("legacy, dual-CPU and missing-compat generation checks pass")
