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

echo "==> 编译通用二进制 (swiftc, release, arm64 + x86_64)"
BIN_ARM64="$BUILD_DIR/$APP_NAME-arm64"
BIN_X86="$BUILD_DIR/$APP_NAME-x86_64"

swiftc -O \
    -target arm64-apple-macos14.0 \
    -framework AppKit -framework Carbon -framework ServiceManagement \
    -o "$BIN_ARM64" \
    Sources/LockType/*.swift

swiftc -O \
    -target x86_64-apple-macos14.0 \
    -framework AppKit -framework Carbon -framework ServiceManagement \
    -o "$BIN_X86" \
    Sources/LockType/*.swift

# 合并成 universal 二进制（Intel + Apple Silicon 都能跑）
lipo -create "$BIN_ARM64" "$BIN_X86" -output "$BIN"
rm -f "$BIN_ARM64" "$BIN_X86"

echo "    binary: $BIN ($(du -h "$BIN" | awk '{print $1}')) [$(lipo -archs "$BIN")]"

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

# 背景图：醒目展示「拖到应用程序」+「首次打开去隐私与安全性点仍要打开」
if [ -f "$ROOT/Resources/DmgBackground.svg" ]; then
    echo "==> 生成 dmg 背景图"
    mkdir -p "$DMG_STAGE/.background"
    swift "$ROOT/scripts/svg2png.swift" \
        "$ROOT/Resources/DmgBackground.svg" \
        "$DMG_STAGE/.background/background.png" 640 480
fi

# 首次打开说明（背景图已写明步骤，这里留终端一键命令等完整详情）
README_NAME='首次打不开-点我看说明.txt'
cat > "$DMG_STAGE/$README_NAME" <<'TXT'
LockType 打不开？这是正常的，处理一次即可
==========================================

文件名就是最快办法：到「系统设置 → 隐私与安全性」滑到底，
点那行被拦住的 LockType 旁边的「仍要打开」按钮。

本 App 未购买 Apple 开发者证书（未公证），首次打开会被系统拦一下，
这是正常现象，只需处理「一次」，之后双击即可正常使用。

—— 最快（推荐）：终端跑一行命令 ——
打开「终端」，粘贴下面这行回车（拖进去后会无任何弹窗直接打开）：

    xattr -dr com.apple.quarantine /Applications/LockType.app

（先把 LockType.app 拖到「应用程序」文件夹，再跑上面这行）

—— 或者用图形界面 ——
• macOS 15 (Sequoia) 及以上：
    双击打开 → 弹出「未能打开」→ 打开
    系统设置 → 隐私与安全性 → 滑到底部
    → 点「仍要打开」→ 再确认一次
    （新系统已取消「右键打开」绕过方式，必须走系统设置）

• macOS 14 (Sonoma) 及以下：
    右键（或按住 Control 点击）LockType.app → 打开 → 再点「打开」

装好后菜单栏会出现一个锁图标，就成功了。
TXT

# 先做可读写 dmg，挂载后用 Finder 设置窗口布局（背景图 + 图标位置），再压缩成只读
DMG_RW="$BUILD_DIR/$APP_NAME-rw.dmg"
rm -f "$DMG_RW"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov -format UDRW -fs HFS+ \
    "$DMG_RW" >/dev/null

MOUNT_DIR="/Volumes/$APP_NAME"
DEV=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_RW" | grep '^/dev/' | head -1 | awk '{print $1}')
sleep 1

# 用 AppleScript 摆位（首次运行 Terminal 可能要求授权「控制 Finder」，同意一次即可）
if osascript <<OSA 2>/dev/null
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 840, 620}
        set vo to the icon view options of container window
        set arrangement of vo to not arranged
        set icon size of vo to 96
        set text size of vo to 12
        set background picture of vo to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {155, 175}
        set position of item "Applications" of container window to {485, 175}
        set position of item "$README_NAME" of container window to {320, 452}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
OSA
then
    echo "    窗口布局已设置"
else
    echo "    ⚠️ 跳过窗口布局（Finder 自动化不可用，背景图与文件仍在 dmg 内）"
fi

chmod -Rf go-w "$MOUNT_DIR" 2>/dev/null || true
sync
hdiutil detach "$DEV" >/dev/null 2>&1 || hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true

rm -f "$DMG_PATH"
hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$DMG_RW"
rm -rf "$DMG_STAGE"

echo ""
echo "✅ 完成:"
echo "   App: $APP_BUNDLE"
echo "   DMG: $DMG_PATH ($(du -h "$DMG_PATH" | awk '{print $1}'))"
