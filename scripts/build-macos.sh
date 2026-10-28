#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$project_root/source/nfs-recompiled"
build_dir="$project_root/build/native-arm64"
asset_dir="$project_root/data/extracted/app"
app_name="Need for Speed II SE.app"
final_app="$project_root/$app_name"
build_jobs="${NFS_BUILD_JOBS:-8}"

for required in cmake clang pkg-config codesign install_name_tool rsync vtool python3; do
    command -v "$required" >/dev/null || { echo "Missing build tool: $required" >&2; exit 1; }
done
for required in FEDATA GAMEDATA INSTALL.WIN text.eng NFS2SEN.EXE; do
    test -e "$asset_dir/$required" || { echo "Missing game data: $asset_dir/$required" >&2; exit 1; }
done

sdl_prefix="$(pkg-config --variable=prefix sdl3)"
sdl_library="$(pkg-config --variable=libdir sdl3)/libSDL3.0.dylib"
sdl_minos="$(vtool -show-build "$sdl_library" | awk '$1 == "minos" { print $2; exit }')"
if ! [[ "$sdl_minos" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "Cannot determine the minimum macOS version required by SDL3." >&2
    exit 1
fi
deployment_target="$sdl_minos"
if test "${sdl_minos%%.*}" -lt 13; then
    deployment_target=13.0
fi
echo "Minimum macOS version: $deployment_target (SDL3 requires $sdl_minos)"

cmake -S "$source_dir" -B "$build_dir" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$deployment_target" \
    -DWITH_MMX=ON -DWITH_PEDANTIC_FPU=OFF
cmake --build "$build_dir" --target nfs2se --parallel "$build_jobs"

package_dir="$(mktemp -d "$project_root/build/macos-package.XXXXXX")"
trap 'rm -rf "$package_dir"' EXIT
app="$package_dir/$app_name"
macos="$app/Contents/MacOS"
frameworks="$app/Contents/Frameworks"
resources="$app/Contents/Resources"
mkdir -p "$macos" "$frameworks" "$resources/game-data" "$resources/licenses"

cp "$build_dir/nfs2se" "$macos/nfs2se"
clang -fobjc-arc -arch arm64 -mmacosx-version-min="$deployment_target" \
    -framework Foundation -framework AppKit \
    "$project_root/scripts/launcher.m" -o "$macos/NFS II SE"

# The current SDL3 build has only system-framework dependencies. Keep the
# private dylib inside the bundle and fail if a future build introduces extras.
cp -L "$sdl_library" "$frameworks/libSDL3.0.dylib"
chmod u+w "$macos/nfs2se" "$frameworks/libSDL3.0.dylib"
install_name_tool -id '@rpath/libSDL3.0.dylib' "$frameworks/libSDL3.0.dylib"

dependencies() {
    otool -L "$1" | tail -n +2 | sed -E 's/^[[:space:]]+//; s/ \(compatibility version.*$//'
}
while IFS= read -r dependency; do
    case "$dependency" in
        */libSDL3.0.dylib)
            install_name_tool -change "$dependency" \
                '@executable_path/../Frameworks/libSDL3.0.dylib' "$macos/nfs2se"
            ;;
        /System/Library/*|/usr/lib/*) ;;
        *) echo "Private dependency needs packaging: $dependency" >&2; exit 1 ;;
    esac
done < <(dependencies "$macos/nfs2se")
while IFS= read -r dependency; do
    case "$dependency" in
        @rpath/libSDL3.0.dylib|/System/Library/*|/usr/lib/*) ;;
        *) echo "SDL3 private dependency needs packaging: $dependency" >&2; exit 1 ;;
    esac
done < <(dependencies "$frameworks/libSDL3.0.dylib")

rsync -a --exclude='*.exe' --exclude='*.EXE' "$asset_dir/" "$resources/game-data/"
# NFS2SEN.EXE is required by the original game's CD/data presence check.
# It is copied as data only; the launcher executes Contents/MacOS/nfs2se.
cp "$asset_dir/NFS2SEN.EXE" "$resources/game-data/NFS2SEN.EXE"
python3 "$project_root/scripts/prepare-game-text.py" \
    "$resources/game-data" "$resources/text-compat-originals"
cp "$source_dir/include/third_party/sse2neon.LICENSE" "$resources/licenses/"
cp "$source_dir/include/third_party/README.txt" "$resources/licenses/sse2neon-provenance.txt"
cp "$sdl_prefix/share/licenses/SDL3/LICENSE.txt" "$resources/licenses/SDL3-LICENSE.txt"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>NFS II SE</string>
  <key>CFBundleIdentifier</key><string>local.nfs2se.apple-silicon</string>
  <key>CFBundleName</key><string>NFS II SE</string>
  <key>CFBundleDisplayName</key><string>NFS II SE</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.2</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>LSMinimumSystemVersion</key><string>$deployment_target</string>
  <key>LSArchitecturePriority</key><array><string>arm64</string></array>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
plutil -lint "$app/Contents/Info.plist"

codesign --force --sign - "$frameworks/libSDL3.0.dylib"
codesign --force --sign - "$macos/nfs2se"
codesign --force --sign - "$macos/NFS II SE"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
test "$(lipo -archs "$macos/nfs2se")" = arm64
test "$(lipo -archs "$macos/NFS II SE")" = arm64

# Game progress lives outside the app. Preserve the previous app as a backup
# until the new package has built, signed, and passed the checks above.
if test -e "$final_app"; then
    backup_dir="$(mktemp -d "$project_root/build/previous-app.XXXXXX")"
    mv "$final_app" "$backup_dir/$app_name-backup"
    echo "Previous app preserved at: $backup_dir/$app_name-backup"
fi
mv "$app" "$final_app"
echo "Ready: $final_app"
echo "Saves: $HOME/Library/Application Support/NFS II SE/game-data"
