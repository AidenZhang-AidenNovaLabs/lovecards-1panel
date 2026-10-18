#!/usr/bin/env python3
"""Check installer syntax, security guards, text UI and rollback offline."""

import ast
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

script = Path(__file__).with_name("install.sh")
text = script.read_text(encoding="utf-8")


def find_sh() -> str:
    exe = shutil.which("sh") or shutil.which("bash")
    if exe:
        return exe
    for candidate in (
        Path(r"C:\Program Files\Git\usr\bin\sh.exe"),
        Path(r"C:\Program Files\Git\bin\bash.exe"),
        Path(r"C:\Program Files\Git\usr\bin\bash.exe"),
    ):
        if candidate.is_file():
            return str(candidate)
    raise SystemExit("sh/bash not found; install Git for Windows or a POSIX shell")


SH = find_sh()


def sh_env() -> dict:
    import os

    env = os.environ.copy()
    git_bin = Path(r"C:\Program Files\Git\usr\bin")
    if git_bin.is_dir():
        env["PATH"] = str(git_bin) + os.pathsep + env.get("PATH", "")
    return env


subprocess.run([SH, "-n", str(script)], check=True, env=sh_env())
assert "--menu" in text and "--gauge" in text and "--defaultno" in text
assert "whiptail" in text and "dialog" in text
assert "LOVECARDS_TEXT" in text and "回退到文本菜单" in text
assert "lovecards-web-frankenphp:latest" in text
assert "LoveCards/LoveCardsV2/releases/download" in text
assert "docker load" in text
# 1Panel sync scans local/*; backups/staging must live outside local/
assert 'work_root="$base_dir/1panel/resource/apps/.app-backups/lovecards"' in text
assert 'stage=$(mktemp -d "$work_root/' in text
assert 'backup=$(mktemp -d "$work_root/' in text
assert '.lovecards.stage' not in text.split("work_root=")[0]  # not under local_root default

blocks = text.split("<<'PY'\n")[1:]
assert len(blocks) >= 2
for block in blocks:
    ast.parse(block.split("\nPY\n")[0])

download = "\n".join(block.split("\nPY\n")[0] for block in blocks[1:])
for guard in (
    "ALLOWED_HOSTS",
    "objects.githubusercontent.com",
    "release-assets.githubusercontent.com",
    "not ip.is_global or ip.is_reserved or ip.is_multicast",
    "'--resolve'",
    "'--noproxy'",
    "'--proto-redir'",
    "'=https'",
    "'--location'",
    "'--max-redirs'",
    "status != '200'",
    "final_host not in ALLOWED_HOSTS",
    "'..' in path.parts",
    "stat.S_ISLNK(mode)",
    "docker",
    "load",
):
    assert guard in download, guard

# Must not allow non-HTTPS redirect protocols
assert "'--proto-redir', '=https'" in download
assert "'-L'" not in download.split()

cleanup = text[text.index("cleanup() {") : text.index("trap cleanup 0")]
with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    backup = root / "backup"
    (backup / "lovecards").mkdir(parents=True)
    (backup / "lovecards/old.txt").write_text("preserved")
    stage = root / "stage"
    stage.mkdir()
    command = "\n".join(
        [
            "set -eu",
            cleanup,
            "backup=" + shlex.quote(str(backup)),
            "app_dir=" + shlex.quote(str(root / "lovecards")),
            "stage=" + shlex.quote(str(stage)),
            "committed=0",
            "cleanup",
        ]
    )
    subprocess.run([SH, "-c", command], check=True, env=sh_env())
    assert (root / "lovecards/old.txt").read_text() == "preserved"
    assert not stage.exists()

ui = text[text.index("ui_msg() {") : text.index("fail() {")]
for selection, expected in [
    ("1\n", "install"),
    ("2\n", "check"),
    ("3\n", "delete"),
    ("4\n", "exit"),
]:
    result = subprocess.run(
        [SH, "-c", ui + '\ntui=""; ui_menu'],
        input=selection.encode(),
        capture_output=True,
        check=True,
        env=sh_env(),
    )
    assert result.stdout.decode("utf-8").strip() == expected
    assert b"1)" in result.stderr

for answer, expected in [("y\n", 0), ("\n", 1), ("n\n", 1)]:
    result = subprocess.run(
        [SH, "-c", ui + '\ntui=""; ui_yesno "confirm"'],
        input=answer.encode(),
        capture_output=True,
        env=sh_env(),
    )
    assert result.returncode == expected

delete_branch = text[text.index('if [ "$choice" = delete ]; then') : text.index('if [ "$choice" = check ]; then')]
for answer, protected in [("n", False), ("y", False), ("y", True)]:
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        app = root / "lovecards"
        app.mkdir()
        (app / "data.yml").write_text("additionalProperties:\n  key: lovecards\n", encoding="utf-8")
        backup_dir = root / ".lovecards.backup.test"
        backup_dir.mkdir()
        if protected:
            (app / ".env").write_text("runtime-config", encoding="utf-8")
        command = "\n".join(
            [
                "set -eu",
                ui,
                "fail() { exit 1; }",
                'tui=""; choice=delete',
                "local_root=" + shlex.quote(str(root)),
                "app_dir=" + shlex.quote(str(app)),
                delete_branch.replace("python3 - ", shlex.quote(sys.executable) + " - "),
            ]
        )
        result = subprocess.run(
            [SH, "-c", command],
            input=(answer + "\n\n").encode(),
            capture_output=True,
            env=sh_env(),
        )
        assert app.exists() == (answer != "y" or protected), (answer, protected, result.returncode, result.stderr.decode())
        assert result.returncode == (1 if protected else 0), result.stderr
        assert backup_dir.is_dir()

print("OK: syntax, text menu, delete/cancel/runtime protection, backup retention, rollback")
