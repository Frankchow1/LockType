#!/bin/bash
# 编译 LockType 并打包成 .app + .dmg
# 直接用 swiftc，不走 SPM（避免 Command Line Tools 下的 PackageDescription 链接问题）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_NAME="LockType"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
DMG_STAGE="$BUILD_DIR/dmg-stage"
BIN="$BUILD_DIR/$APP_NAME"
ICON_SVG="$ROOT/Resources/AppIcon.svg"
ICON_ICNS="$BUILD_DIR/AppIcon.icns"

echo "==> 清理"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> 编译 (swiftc, release, arm64)"
swiftc -O \
    -target arm64-apple-macos14.0 \
    -framework AppKit \
    -framework Carbon \
    -framework ServiceManagement \
    -o "$BIN" \
    Sources/LockType/*.swift

echo "    binary: $BIN ($(du -h "$BIN" | awk '{print $1}'))"

if [ -f "$ICON_SVG" ]; then
    echo "==> 生成 AppIcon.icns"
    ICONSET="$BUILD_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET"
    TMP_PNG="$BUILD_DIR/icon-1024.png"
    # 用 WebKit 把 SVG 渲染为透明 PNG（qlmanage 不支持透明背景）
    swift "$ROOT/scripts/svg2png.swift" "$ICON_SVG" "$TMP_PNG" 1024

    for size in 16 32 128 256 512; do
        sips -z $size $size "$TMP_PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        DOUBLE=$((size * 2))
        sips -z $DOUBLE $DOUBLE "$TMP_PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done

    iconutil -c icns "$ICONSET" -o "$ICON_ICNS"
    rm -rf "$ICONSET" "$TMP_PNG"
    echo "    icon: $ICON_ICNS ($(du -h "$ICON_ICNS" | awk '{print $1}'))"
fi

echo "==> 组装 .app bundle"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
[ -f "$ICON_ICNS" ] && cp "$ICON_ICNS" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

echo "==> Ad-hoc 签名"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "    .app 完成: $APP_BUNDLE ($(du -sh "$APP_BUNDLE" | awk '{print $1}'))"

echo "==> 打包 dmg"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$DMG_STAGE"

echo ""
echo "✅ 完成:"
echo "   App: $APP_BUNDLE"
echo "   DMG: $DMG_PATH ($(du -h "$DMG_PATH" | awk '{print $1}'))"
