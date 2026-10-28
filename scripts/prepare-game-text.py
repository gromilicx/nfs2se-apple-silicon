#!/usr/bin/env python3
"""Adapt the supplied patched Windows menu table to the original NFS2SE engine."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import tempfile


# The patched Windows executable introduces three network choices and H3D.
# The recompiled original executable keeps its original descriptor numbering.
# These are indices in the supplied, 1502-entry table, not in the output.
PATCHED_ONLY_DESCRIPTORS = frozenset((53, 54, 55, 360))
LANGUAGES = frozenset(("ENG", "FRE", "GER", "ITA", "MET", "SPA", "SWE"))


def descriptor_count(data):
    if len(data) < 12:
        raise ValueError("Text table is too short")
    first_string = struct.unpack_from("<I", data, 8)[0]
    if first_string % 12 or not 0 < first_string < len(data):
        raise ValueError("Invalid text descriptor table")
    count = first_string // 12
    for index in range(count):
        offset = struct.unpack_from("<I", data, index * 12 + 8)[0]
        if not first_string <= offset < len(data) or data.find(b"\0", offset) < 0:
            raise ValueError(f"Invalid text offset in descriptor {index}")
    return count


def convert(data):
    count = descriptor_count(data)
    if count == 1498:
        return data
    if count != 1502:
        raise ValueError(f"Unsupported text table with {count} descriptors")
    shift = 12 * len(PATCHED_ONLY_DESCRIPTORS)
    output = bytearray()
    for index in range(count):
        if index in PATCHED_ONLY_DESCRIPTORS:
            continue
        row = bytearray(data[index * 12:(index + 1) * 12])
        offset = struct.unpack_from("<I", row, 8)[0]
        struct.pack_into("<I", row, 8, offset - shift)
        output.extend(row)
    output.extend(data[count * 12:])
    result = bytes(output)
    if descriptor_count(result) != 1498:
        raise ValueError("Converted text table failed validation")
    return result


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    name = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".text-", delete=False) as output:
            name = Path(output.name)
            output.write(data)
        os.chmod(name, 0o644)
        os.replace(name, path)
    finally:
        if name is not None:
            name.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("game_data", type=Path)
    parser.add_argument("originals", type=Path)
    args = parser.parse_args()
    text_dir = args.game_data / "FEDATA/PC/TEXT"
    manifest = {"version": 1, "removed_patched_indices": sorted(PATCHED_ONLY_DESCRIPTORS), "files": []}
    for path in sorted(text_dir.iterdir()):
        name = path.name.upper()
        if not path.is_file() or name.split(".") != ["TEXT", name.rsplit(".", 1)[-1]]:
            continue
        if name.rsplit(".", 1)[-1] not in LANGUAGES:
            continue
        original = path.read_bytes()
        corrected = convert(original)
        atomic_write(args.originals / path.name, original)
        atomic_write(path, corrected)
        manifest["files"].append({
            "name": path.name,
            "original_sha256": hashlib.sha256(original).hexdigest(),
            "corrected_sha256": hashlib.sha256(corrected).hexdigest(),
            "descriptor_count": descriptor_count(corrected),
        })
    if not any(row["name"].upper() == "TEXT.ENG" for row in manifest["files"]):
        raise ValueError("English menu text is missing")
    atomic_write(args.originals.parent / "text-compat-manifest.json",
                 (json.dumps(manifest, indent=2) + "\n").encode())
    print(f"Prepared {len(manifest['files'])} original-engine menu text files")


if __name__ == "__main__":
    main()
