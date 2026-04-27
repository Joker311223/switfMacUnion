import AppKit

// MARK: - WebViewer 应用图标（深色背景 + 地球网格 + 置顶图钉风格）
enum AppIconMaker {

    static func make(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let s = size
        let csp = CGColorSpaceCreateDeviceRGB()

        // ── 1. 圆角背景（深蓝黑渐变）──────────────────────────────
        let bgR = s * 0.22
        let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
        let bgPath = CGMutablePath()
        bgPath.addRoundedRect(in: bgRect, cornerWidth: bgR, cornerHeight: bgR)
        ctx.addPath(bgPath)
        ctx.clip()

        let bgGrad = CGGradient(colorsSpace: csp, colors: [
            NSColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1).cgColor,
            NSColor(red: 0.03, green: 0.05, blue: 0.10, alpha: 1).cgColor,
        ] as CFArray, locations: [0.0, 1.0])!
        ctx.drawLinearGradient(bgGrad,
                               start: CGPoint(x: s / 2, y: s),
                               end:   CGPoint(x: s / 2, y: 0),
                               options: [])
        ctx.resetClip()

        // ── 2. 内发光边框 ─────────────────────────────────────────
        ctx.saveGState()
        let borderPath = CGMutablePath()
        borderPath.addRoundedRect(in: bgRect.insetBy(dx: 1.5, dy: 1.5),
                                   cornerWidth: bgR - 1.5, cornerHeight: bgR - 1.5)
        ctx.addPath(borderPath)
        ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.10).cgColor)
        ctx.setLineWidth(2)
        ctx.strokePath()
        ctx.restoreGState()

        // ── 3. 地球圆形底色 ───────────────────────────────────────
        let cx = s * 0.50
        let cy = s * 0.50
        let r  = s * 0.33

        ctx.saveGState()
        // 剪裁到地球圆形
        ctx.beginPath()
        ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.clip()

        // 海洋渐变（蓝色）
        let oceanGrad = CGGradient(colorsSpace: csp, colors: [
            NSColor(red: 0.18, green: 0.52, blue: 0.90, alpha: 1).cgColor,
            NSColor(red: 0.08, green: 0.30, blue: 0.65, alpha: 1).cgColor,
        ] as CFArray, locations: [0.0, 1.0])!
        ctx.drawLinearGradient(oceanGrad,
                               start: CGPoint(x: cx, y: cy + r),
                               end:   CGPoint(x: cx, y: cy - r),
                               options: [])
        ctx.restoreGState()

        // ── 4. 地球经纬网格线 ─────────────────────────────────────
        ctx.saveGState()
        ctx.beginPath()
        ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.clip()

        ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.18).cgColor)
        ctx.setLineWidth(max(1, s * 0.007))

        // 纬线（水平椭圆）
        let latOffsets: [CGFloat] = [-0.55, -0.25, 0.0, 0.25, 0.55]
        for t in latOffsets {
            let ry_lat = r * sqrt(max(0, 1 - t * t))
            let latY   = cy + t * r
            ctx.beginPath()
            ctx.addEllipse(in: CGRect(x: cx - ry_lat, y: latY - ry_lat * 0.28,
                                      width: ry_lat * 2, height: ry_lat * 0.56))
            ctx.strokePath()
        }

        // 经线（垂直椭圆）
        let lonAngles: [CGFloat] = [-.pi / 3, 0, .pi / 3]
        for angle in lonAngles {
            let rx_lon = r * abs(cos(angle))
            ctx.beginPath()
            ctx.addEllipse(in: CGRect(x: cx - rx_lon, y: cy - r,
                                      width: rx_lon * 2, height: r * 2))
            ctx.strokePath()
        }

        ctx.restoreGState()

        // ── 5. 地球外圈描边 ───────────────────────────────────────
        ctx.saveGState()
        ctx.beginPath()
        ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.30).cgColor)
        ctx.setLineWidth(max(1.5, s * 0.008))
        ctx.strokePath()
        ctx.restoreGState()

        // ── 6. 右下角置顶图钉 (📌 风格) ─────────────────────────
        let pinX = cx + r * 0.60
        let pinY = cy - r * 0.60
        let pinR = s * 0.085

        // 图钉圆头（橙红）
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012),
                      blur: s * 0.025,
                      color: NSColor.black.withAlphaComponent(0.5).cgColor)
        let pinGrad = CGGradient(colorsSpace: csp, colors: [
            NSColor(red: 1.0,  green: 0.45, blue: 0.20, alpha: 1).cgColor,
            NSColor(red: 0.85, green: 0.20, blue: 0.10, alpha: 1).cgColor,
        ] as CFArray, locations: [0.0, 1.0])!
        ctx.beginPath()
        ctx.addEllipse(in: CGRect(x: pinX - pinR, y: pinY - pinR,
                                   width: pinR * 2, height: pinR * 2))
        ctx.clip()
        ctx.drawLinearGradient(pinGrad,
                               start: CGPoint(x: pinX, y: pinY + pinR),
                               end:   CGPoint(x: pinX, y: pinY - pinR),
                               options: [])
        ctx.restoreGState()

        // 图钉高光
        ctx.saveGState()
        ctx.beginPath()
        ctx.addEllipse(in: CGRect(x: pinX - pinR * 0.55, y: pinY + pinR * 0.15,
                                   width: pinR * 0.5, height: pinR * 0.35))
        ctx.setFillColor(NSColor(white: 1.0, alpha: 0.35).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // 图钉针（竖线）
        ctx.saveGState()
        ctx.setStrokeColor(NSColor(white: 0.85, alpha: 0.9).cgColor)
        ctx.setLineWidth(max(2, s * 0.012))
        ctx.setLineCap(.round)
        ctx.beginPath()
        ctx.move(to:    CGPoint(x: pinX, y: pinY - pinR))
        ctx.addLine(to: CGPoint(x: pinX, y: pinY - pinR * 2.2))
        ctx.strokePath()
        ctx.restoreGState()

        image.unlockFocus()
        return image
    }

    // 将图标导出为各尺寸 PNG 并生成 .icns 文件
    static func exportIconSet(to directory: URL) {
        let sizes: [(Int, String)] = [
            (16,   "icon_16x16"),
            (32,   "icon_16x16@2x"),
            (32,   "icon_32x32"),
            (64,   "icon_32x32@2x"),
            (64,   "icon_64x64"),
            (128,  "icon_64x64@2x"),
            (128,  "icon_128x128"),
            (256,  "icon_128x128@2x"),
            (256,  "icon_256x256"),
            (512,  "icon_256x256@2x"),
            (512,  "icon_512x512"),
            (1024, "icon_512x512@2x"),
            (1024, "icon_1024x1024"),
        ]
        for (px, name) in sizes {
            let img = make(size: CGFloat(px))
            if let tiff = img.tiffRepresentation,
               let rep  = NSBitmapImageRep(data: tiff),
               let png  = rep.representation(using: .png, properties: [:]) {
                let url = directory.appendingPathComponent("\(name).png")
                try? png.write(to: url)
            }
        }
    }
}
