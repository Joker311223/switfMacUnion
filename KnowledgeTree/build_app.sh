#!/bin/bash
set -e

APP_NAME="KnowledgeTree"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🌳 Building $APP_NAME..."

# 1. Swift build
cd "$SCRIPT_DIR"
swift build -c release 2>&1

BINARY=".build/release/$APP_NAME"
if [ ! -f "$BINARY" ]; then
    echo "❌ Build failed: binary not found"
    exit 1
fi

# 2. 创建 .app 目录结构
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. 复制二进制
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 4. 复制 Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# 5. 生成图标
if [ -f "$SCRIPT_DIR/make_icon.py" ] && [ ! -d "$SCRIPT_DIR/AppIcon.iconset" ]; then
    echo "🎨 Generating app icon..."
    python3 "$SCRIPT_DIR/make_icon.py"
fi

if [ -d "$SCRIPT_DIR/AppIcon.iconset" ]; then
    iconutil -c icns "$SCRIPT_DIR/AppIcon.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "✅ AppIcon.icns created"
fi

# 6. 安装到 /Applications
INSTALL_PATH="/Applications/$APP_NAME.app"
echo ""
echo "📦 Installing to $INSTALL_PATH ..."
rm -rf "$INSTALL_PATH"
cp -R "$APP_BUNDLE" "$INSTALL_PATH"

echo ""
echo "✅ $APP_NAME.app installed successfully!"
echo "   Location: $INSTALL_PATH"
echo ""
echo "🚀 Launching app..."
open "$INSTALL_PATH"
