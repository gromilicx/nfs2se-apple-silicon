#!/bin/bash
set -euo pipefail

if test "$#" -gt 1; then
    echo "Usage: $0 [path/to/Need.for.Speed.II.SE.zip]" >&2
    exit 1
fi
project_root="$(cd "$(dirname "$0")/.." && pwd)"
zip_archive="${1:-$HOME/Downloads/Need.for.Speed.II.SE.zip}"
installer_dir="$project_root/data/installer"
extracted_dir="$project_root/data/extracted"
metadata_dir="$project_root/source/NFSIISEN/Need For Speed II SE"
for required in python3 innoextract; do
    command -v "$required" >/dev/null || { echo "Missing extraction tool: $required" >&2; exit 1; }
done
test -f "$zip_archive" || { echo "ZIP archive not found: $zip_archive" >&2; exit 1; }
for required in install.win text.eng; do
    test -f "$metadata_dir/$required" || { echo "Missing source metadata: $metadata_dir/$required" >&2; exit 1; }
done
mkdir -p "$installer_dir" "$extracted_dir"

# Read only the setup executable and its numbered data volumes. Flatten paths,
# reject ambiguous installers and links, and publish each file atomically. No
# executable from the ZIP is ever run.
installer_exe="$(python3 - "$zip_archive" "$installer_dir" <<'PYTHON'
import os
from pathlib import Path
import re
import shutil
import stat
import sys
import tempfile
import zipfile

archive_path, output_path = sys.argv[1:]
output_dir = Path(output_path)

def basename(entry):
    return entry.filename.replace('\\', '/').rsplit('/', 1)[-1]

with zipfile.ZipFile(archive_path) as archive:
    entries = [entry for entry in archive.infolist() if not entry.is_dir()]
    # Ignore unrelated redistributable setup files: the game installer has
    # accompanying numbered .bin volumes with the same filename stem.
    installers = []
    for entry in entries:
        name = basename(entry)
        if not name.lower().endswith('.exe') or 'setup' not in name.lower():
            continue
        pattern = re.compile(re.escape(name[:-4]) + r'-\d+\.bin', re.IGNORECASE)
        if any(pattern.fullmatch(basename(volume)) for volume in entries):
            installers.append(entry)
    if len(installers) != 1:
        raise SystemExit('Expected exactly one game setup executable in the ZIP.')
    installer = installers[0]
    stem = basename(installer)[:-4]
    volume_pattern = re.compile(re.escape(stem) + r'-\d+\.bin', re.IGNORECASE)
    volumes = [entry for entry in entries if volume_pattern.fullmatch(basename(entry))]
    if not volumes:
        raise SystemExit('No matching installer data volumes found in the ZIP.')
    selected = [installer, *volumes]
    names = [basename(entry) for entry in selected]
    if len({name.lower() for name in names}) != len(names):
        raise SystemExit('Duplicate installer filenames in the ZIP.')
    if any(any(ord(char) < 32 for char in name) for name in names):
        raise SystemExit('Unsupported control characters in an installer filename.')
    for entry, name in zip(selected, names):
        mode = entry.external_attr >> 16
        if stat.S_ISLNK(mode):
            raise SystemExit('Installer entries must be regular files, not links.')
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=output_dir, prefix='.extract-',
                                             delete=False) as destination:
                temporary = Path(destination.name)
                with archive.open(entry) as source:
                    shutil.copyfileobj(source, destination, 1024 * 1024)
            os.chmod(temporary, 0o600)
            os.replace(temporary, output_dir / name)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
    print(output_dir / basename(installer))
PYTHON
)"

innoextract --silent --extract \
    --include app/FEDATA --include app/GAMEDATA --include app/NFS2SEN.EXE \
    --output-dir "$extracted_dir" "$installer_exe"
# The original executable is retained only as the game's CD/data presence
# marker. The ARM64 port reads it as data; no Windows executable is run.
cp "$metadata_dir/install.win" "$extracted_dir/app/INSTALL.WIN"
cp "$metadata_dir/text.eng" "$extracted_dir/app/text.eng"
echo "Game data ready: $extracted_dir/app"
echo "Windows installer files were read as archives; no Windows program was executed."
