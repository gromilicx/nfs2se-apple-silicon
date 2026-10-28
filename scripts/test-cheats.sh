#!/bin/zsh
set -eu
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_BUILD="${1:-$TASK_ROOT/build/native-arm64}"
TASK_RESULTS="${2:-$TASK_ROOT/docs/cheats-test-results.json}"
mkdir -p "$(dirname "$TASK_RESULTS")"

# Reuse the built game's actual objects and flags. Compile in a temporary folder
# and run there so this process cannot find the user's game data or preferences.
python3 - "$TASK_ROOT" "$TASK_BUILD" "$TASK_RESULTS" <<'PY'
import pathlib
import shlex
import subprocess
import sys
import tempfile

root, build, results = map(pathlib.Path, sys.argv[1:])
root, build, results = root.resolve(), build.resolve(), results.resolve()
target = build / "CMakeFiles/nfs2se.dir"
flags = {}
for line in (target / "flags.make").read_text().splitlines():
    if " = " in line:
        key, value = line.split(" = ", 1)
        flags[key] = shlex.split(value)
link = shlex.split((target / "link.txt").read_text())
with tempfile.TemporaryDirectory(prefix="nfs2se-cheat-probe-") as temporary:
    work = pathlib.Path(temporary)
    obj, binary = work / "cheat_probe.o", work / "cheat_probe"
    command = [link[0], *flags["CXX_DEFINES"], *flags["CXX_INCLUDES"],
               *flags["CXX_FLAGS"], "-c", str(root / "tests/cheat_probe.cpp"), "-o", str(obj)]
    subprocess.run(command, cwd=build, check=True)
    replaced = False
    for i, arg in enumerate(link):
        if arg.endswith("nfs2se_main.cpp.o"):
            link[i] = str(obj)
            replaced = True
        if i and link[i - 1] == "-o":
            link[i] = str(binary)
    if not replaced:
        raise SystemExit("Expected native game's main object in link.txt")
    subprocess.run(link, cwd=build, check=True)
    subprocess.run([str(binary), str(results)], cwd=work, check=True)
print(f"Result: {results}")
PY
