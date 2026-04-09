import AppKit

// MARK: - 菜单栏图标管理器应用图标
// 风格：深色背景 + 网格排列的彩色小方块，象征"管理多个菜单栏图标"
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

        // ── 1. 深色圆角背景 ──────────────────────────────────
        let bgR = s * 0.22
        let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
        let bgGrad = CGGradient(colorsSpace: csp, colors: [
            NSColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1).cgColor,
            NSColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1).cgColor,
        ] as CFArray, locations: [0.0, 1.0])!
        let bgPath = CGMutablePath()
        bgPath.addRoundedRect(in: bgRect, cornerWidth: bgR, cornerHeight: bgR)
        ctx.addPath(bgPath)
        ctx.clip()
        ctx.drawLinearGradient(bgGrad,
                               start: CGPoint(x: s / 2, y: s),
                               end:   CGPoint(x: s / 2, y: 0),
                               options: [])
        ctx.resetClip()

        // ── 2. 内发光边框 ────────────────────────────────────
        ctx.saveGState()
        let borderPath = CGMutablePath()
        borderPath.addRoundedRect(in: bgRect.insetBy(dx: 1, dy: 1),
                                  cornerWidth: bgR - 1, cornerHeight: bgR - 1)
        ctx.addPath(borderPath)
        ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.08).cgColor)
        ctx.setLineWidth(2)
        ctx.strokePath()
        ctx.restoreGState()

        // ── 3. 模拟菜单栏顶部横条 ────────────────────────────
        let barH = s * 0.10
        let barY = s - barH - s * 0.08
        let barRect = CGRect(x: s * 0.08, y: barY, width: s * 0.84, height: barH)
        let barR = barH * 0.35
        let barPath = CGMutablePath()
        barPath.addRoundedRect(in: barRect, cornerWidth: barR, cornerHeight: barR)
        ctx.addPath(barPath)
        NSColor(white: 1.0, alpha: 0.10).setFill()
        ctx.fillPath()

        // ── 4. 菜单栏上的小图标块（模拟各 App 状态栏图标）──────
        let iconSize = s * 0.072
        let iconY = barY + (barH - iconSize) / 2
        let iconColors: [NSColor] = [
            NSColor(red: 0.30, green: 0.85, blue: 0.60, alpha: 1),  // 绿
            NSColor(red: 0.40, green: 0.75, blue: 1.00, alpha: 1),  // 蓝
            NSColor(red: 1.00, green: 0.70, blue: 0.30, alpha: 1),  // 橙
            NSColor(red: 0.85, green: 0.45, blue: 0.90, alpha: 1),  // 紫
            NSColor(red: 1.00, green: 0.45, blue: 0.45, alpha: 1),  // 红
            NSColor(white: 0.5, alpha: 0.4),                         // 灰（隐藏的）
            NSColor(white: 0.5, alpha: 0.4),                         // 灰（隐藏的）
        ]
        let iconSpacing = iconSize * 1.55
        let totalW = CGFloat(iconColors.count) * iconSpacing
        let startX = barRect.maxX - totalW - iconSize * 0.3

        for (i, color) in iconColors.enumerated() {
            let ix = startX + CGFloat(i) * iconSpacing
            let ir = CGRect(x: ix, y: iconY, width: iconSize, height: iconSize)
            let ip = CGMutablePath()
            ip.addRoundedRect(in: ir, cornerWidth: iconSize * 0.25, cornerHeight: iconSize * 0.25)
            ctx.addPath(ip)
            color.setFill()
            ctx.fillPath()
        }

        // ── 5. 中央主体：一个展开的抽屉 / 收纳盒 ───────────────
        let boxW = s * 0.62
        let boxH = s * 0.44
        let boxX = (s - boxW) / 2
        let boxY = s * 0.14
        let boxRect = CGRect(x: boxX, y: boxY, width: boxW, height: boxH)
        let boxR = s * 0.04

        // 盒子背景
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.015),
                      blur: s * 0.06,
                      color: NSColor.black.withAlphaComponent(0.6).cgColor)
        let boxPath = CGMutablePath()
        boxPath.addRoundedRect(in: boxRect, cornerWidth: boxR, cornerHeight: boxR)
        ctx.addPath(boxPath)
        NSColor(red: 0.14, green: 0.14, blue: 0.20, alpha: 1).setFill()
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // 盒子边框
        ctx.saveGState()
        let boxBorderPath = CGMutablePath()
        boxBorderPath.addRoundedRect(in: boxRect.insetBy(dx: 0.5, dy: 0.5),
                                     cornerWidth: boxR, cornerHeight: boxR)
        ctx.addPath(boxBorderPath)
        ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.12).cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
        ctx.restoreGState()

        // ── 6. 盒子内网格排列的彩色图标（4×2）────────────────
        let cellSize = boxW * 0.16
        let cellGap  = boxW * 0.065
        let cols = 4
        let rows = 2
        let gridW = CGFloat(cols) * cellSize + CGFloat(cols - 1) * cellGap
        let gridH = CGFloat(rows) * cellSize + CGFloat(rows - 1) * cellGap
        let gridX = boxX + (boxW - gridW) / 2
        let gridY = boxY + (boxH - gridH) / 2

        let cellColors: [[NSColor]] = [
            [
                NSColor(red: 0.30, green: 0.85, blue: 0.60, alpha: 1),
                NSColor(red: 0.40, green: 0.75, blue: 1.00, alpha: 1),
                NSColor(red: 1.00, green: 0.70, blue: 0.30, alpha: 1),
                NSColor(red: 0.85, green: 0.45, blue: 0.90, alpha: 1),
            ],
            [
                NSColor(red: 1.00, green: 0.45, blue: 0.45, alpha: 1),
                NSColor(red: 0.45, green: 0.90, blue: 0.90, alpha: 1),
                NSColor(red: 1.00, green: 0.85, blue: 0.30, alpha: 1),
                NSColor(white: 0.35, alpha: 1),
            ],
        ]

        for row in 0..<rows {
            for col in 0..<cols {
                let cx = gridX + CGFloat(col) * (cellSize + cellGap)
                let cy = gridY + CGFloat(row) * (cellSize + cellGap)
                let cr = CGRect(x: cx, y: cy, width: cellSize, height: cellSize)
                let cp = CGMutablePath()
                cp.addRoundedRect(in: cr, cornerWidth: cellSize * 0.28, cornerHeight: cellSize * 0.28)
                ctx.addPath(cp)
                cellColors[row][col].setFill()
                ctx.fillPath()
            }
        }

        // ── 7. 盒子顶部的"溢出"箭头 ─────────────────────────
        let arrowCx = boxX + boxW / 2
        let arrowY  = boxY + boxH + s * 0.025
        let arrowW  = s * 0.06
        let arrowH  = s * 0.04
        ctx.beginPath()
        ctx.move(to:    CGPoint(x: arrowCx, y: arrowY + arrowH))
        ctx.addLine(to: CGPoint(x: arrowCx - arrowW / 2, y: arrowY))
        ctx.addLine(to: CGPoint(x: arrowCx + arrowW / 2, y: arrowY))
        ctx.closePath()
        NSColor(red: 0.40, green: 0.75, blue: 1.00, alpha: 0.9).setFill()
        ctx.fillPath()

        image.unlockFocus()
        return image
    }

    // MARK: - 状态栏小图标（16×16，纯模板图）
    static func makeStatusIcon(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let s = size
        // 三行网格，象征管理多个图标
        let rowH: CGFloat = s * 0.18
        let gap:  CGFloat = s * 0.10
        let rows = 3
        let totalH = CGFloat(rows) * rowH + CGFloat(rows - 1) * gap
        let startY = (s - totalH) / 2

        for i in 0..<rows {
            let y = startY + CGFloat(i) * (rowH + gap)
            let width = i == 2 ? s * 0.55 : s * 0.85  // 最后一行短一点
            let rect = CGRect(x: (s - width) / 2, y: y, width: width, height: rowH)
            let path = CGMutablePath()
            path.addRoundedRect(in: rect, cornerWidth: rowH / 2, cornerHeight: rowH / 2)
            ctx.addPath(path)
            NSColor.white.setFill()
            ctx.fillPath()
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
