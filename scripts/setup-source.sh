#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
for required in git python3; do
    command -v "$required" >/dev/null || { echo "Missing tool: $required" >&2; exit 1; }
done
mkdir -p "$project_root/source"

prepare_repository() {
    local repository_url="$1" revision="$2" destination="$3"
    if test -e "$destination"; then
        test -d "$destination/.git" || { echo "Not a Git checkout: $destination" >&2; exit 1; }
        test "$(git -C "$destination" rev-parse HEAD)" = "$revision" || {
            echo "Checkout revision differs from the tested revision: $destination" >&2
            echo "Preserve your changes and move this checkout aside before retrying." >&2
            exit 1
        }
        return
    fi
    local staging
    staging="$(mktemp -d "$project_root/source/.checkout.XXXXXX")"
    git -C "$staging" init --quiet
    git -C "$staging" remote add origin "$repository_url"
    git -C "$staging" fetch --quiet --depth 1 origin "$revision"
    git -C "$staging" -c core.hooksPath=/dev/null checkout --quiet --detach FETCH_HEAD
    mv "$staging" "$destination"
}

prepare_repository https://github.com/motor-dev/nfs-recompiled.git \
    77ebdb3b6a21925ccfc4fc4c1d712abec3e1945a "$project_root/source/nfs-recompiled"
prepare_repository https://github.com/zaps166/NFSIISEN.git \
    ad73d45c7f2f5f8c384c8b46dd9c82125578e647 "$project_root/source/NFSIISEN"

python3 - "$project_root" <<'PYTHON'
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(sys.argv[1])
target = root / 'source/nfs-recompiled'
overlay = root / 'port'
patch = root / 'patches/apple-silicon.patch'
files = sorted(p for p in overlay.rglob('*') if p.is_file())
# Reject collisions before applying anything; never overwrite local edits.
for source in files:
    destination = target / source.relative_to(overlay)
    if destination.exists() and (not destination.is_file() or destination.read_bytes() != source.read_bytes()):
        raise SystemExit(f'Local source differs from the port overlay; preserve it before retrying: {destination}')

def check(*arguments):
    return subprocess.run(['git', '-C', str(target), 'apply', '--check', *arguments, str(patch)],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0

if check():
    subprocess.run(['git', '-C', str(target), 'apply', str(patch)], check=True)
elif not check('--reverse'):
    raise SystemExit('The port patch cannot be applied cleanly. No local changes were reset.')
for source in files:
    destination = target / source.relative_to(overlay)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        shutil.copy2(source, destination)
print('Pinned source and Apple Silicon changes are ready.')
PYTHON
