#!/bin/bash
set -e

# ────────────────────────────────────────────────────────────────
# WebViewer.app 打包脚本
# 用法：bash build_app.sh
# 产物：./WebViewer.app  （同时复制到 /Applications）
# ────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="WebViewer"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
RESOURCES="$APP_BUNDLE/Contents/Resources"
ICONSET_DIR="$SCRIPT_DIR/AppIcon.iconset"

echo "▶ 1/5  编译 Swift 代码..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1
BINARY=".build/release/$APP_NAME"

echo "▶ 2/5  创建 .app 目录结构..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$RESOURCES"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "▶ 3/5  生成图标..."
mkdir -p "$ICONSET_DIR"

# 用内联 Swift 渲染图标 PNG（传入 iconset 目录路径作为参数）
swift - "$ICONSET_DIR" <<"SWIFT_EOF"
import AppKit

func makeIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return image }
    let s = size
    let csp = CGColorSpaceCreateDeviceRGB()

    // 圆角背景（深蓝黑）
    let bgR = s * 0.22
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGMutablePath()
    bgPath.addRoundedRect(in: bgRect, cornerWidth: bgR, cornerHeight: bgR)
    ctx.addPath(bgPath); ctx.clip()
    let bgGrad = CGGradient(colorsSpace: csp, colors: [
        NSColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1).cgColor,
        NSColor(red: 0.03, green: 0.05, blue: 0.10, alpha: 1).cgColor,
    ] as CFArray, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(bgGrad, start: CGPoint(x: s/2, y: s), end: CGPoint(x: s/2, y: 0), options: [])
    ctx.resetClip()

    // 地球海洋
    let cx = s*0.50, cy = s*0.50, r = s*0.33
    ctx.saveGState()
    ctx.beginPath(); ctx.addEllipse(in: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2)); ctx.clip()
    let oceanGrad = CGGradient(colorsSpace: csp, colors: [
        NSColor(red: 0.18, green: 0.52, blue: 0.90, alpha: 1).cgColor,
        NSColor(red: 0.08, green: 0.30, blue: 0.65, alpha: 1).cgColor,
    ] as CFArray, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(oceanGrad, start: CGPoint(x: cx, y: cy+r), end: CGPoint(x: cx, y: cy-r), options: [])
    ctx.restoreGState()

    // 经纬线
    ctx.saveGState()
    ctx.beginPath(); ctx.addEllipse(in: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2)); ctx.clip()
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.18).cgColor)
    ctx.setLineWidth(max(1, s*0.007))
    for t: CGFloat in [-0.55, -0.25, 0.0, 0.25, 0.55] {
        let ry = r * sqrt(max(0, 1 - t*t)); let ly = cy + t*r
        ctx.beginPath(); ctx.addEllipse(in: CGRect(x: cx-ry, y: ly-ry*0.28, width: ry*2, height: ry*0.56)); ctx.strokePath()
    }
    for angle: CGFloat in [-.pi/3, 0, .pi/3] {
        let rx = r * abs(cos(angle))
        ctx.beginPath(); ctx.addEllipse(in: CGRect(x: cx-rx, y: cy-r, width: rx*2, height: r*2)); ctx.strokePath()
    }
    ctx.restoreGState()

    // 地球外圈
    ctx.saveGState()
    ctx.beginPath(); ctx.addEllipse(in: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2))
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.30).cgColor); ctx.setLineWidth(max(1.5, s*0.008)); ctx.strokePath()
    ctx.restoreGState()

    // 图钉（右下角）
    let pinX = cx + r*0.60, pinY = cy - r*0.60, pinR = s*0.085
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s*0.012), blur: s*0.025, color: NSColor.black.withAlphaComponent(0.5).cgColor)
    ctx.beginPath(); ctx.addEllipse(in: CGRect(x: pinX-pinR, y: pinY-pinR, width: pinR*2, height: pinR*2)); ctx.clip()
    let pinGrad = CGGradient(colorsSpace: csp, colors: [
        NSColor(red: 1.0, green: 0.45, blue: 0.20, alpha: 1).cgColor,
        NSColor(red: 0.85, green: 0.20, blue: 0.10, alpha: 1).cgColor,
    ] as CFArray, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(pinGrad, start: CGPoint(x: pinX, y: pinY+pinR), end: CGPoint(x: pinX, y: pinY-pinR), options: [])
    ctx.restoreGState()
    ctx.saveGState()
    ctx.setStrokeColor(NSColor(white: 0.85, alpha: 0.9).cgColor); ctx.setLineWidth(max(2, s*0.012)); ctx.setLineCap(.round)
    ctx.beginPath(); ctx.move(to: CGPoint(x: pinX, y: pinY-pinR)); ctx.addLine(to: CGPoint(x: pinX, y: pinY-pinR*2.2)); ctx.strokePath()
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

let iconsetDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/AppIcon.iconset"
let url = URL(fileURLWithPath: iconsetDir)
try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
let sizes: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"), (32, "icon_32x32"),
    (64, "icon_32x32@2x"), (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"), (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]
for (px, name) in sizes {
    let img = makeIcon(size: CGFloat(px))
    if let tiff = img.tiffRepresentation,
       let rep  = NSBitmapImageRep(data: tiff),
       let png  = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: url.appendingPathComponent("\(name).png"))
    }
}
print("图标 PNG 已生成到: \(iconsetDir)")
SWIFT_EOF

# iconutil 把 iconset 转成 icns
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES/AppIcon.icns"
echo "    AppIcon.icns 已生成"

echo "▶ 4/5  签名（ad-hoc）..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "▶ 5/5  安装到 /Applications..."
rm -rf "/Applications/$APP_NAME.app"
cp -r "$APP_BUNDLE" "/Applications/$APP_NAME.app"

echo ""
echo "✅ 完成！已安装到 /Applications/$APP_NAME.app"
echo "   运行：open /Applications/$APP_NAME.app"
