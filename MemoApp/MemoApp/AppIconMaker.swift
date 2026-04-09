import AppKit

// MARK: - 应用图标生成器（黑色系，简洁扁平风格）
enum AppIconMaker {

    static func make(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let s  = size
        let csp = CGColorSpaceCreateDeviceRGB()

        // ── 1. 黑色系圆角背景 ─────────────────────────────────
        let bgR = s * 0.22
        let bgRect = CGRect(x: 0, y: 0, width: s, height: s)

        // 深灰到黑色渐变
        let bgGrad = CGGradient(colorsSpace: csp, colors: [
            NSColor(white: 0.18, alpha: 1).cgColor,
            NSColor(white: 0.08, alpha: 1).cgColor,
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

        // ── 2. 微弱内发光边框 ─────────────────────────────────
        ctx.saveGState()
        let borderPath = CGMutablePath()
        borderPath.addRoundedRect(in: bgRect.insetBy(dx: 1, dy: 1),
                                  cornerWidth: bgR - 1, cornerHeight: bgR - 1)
        ctx.addPath(borderPath)
        ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.08).cgColor)
        ctx.setLineWidth(2)
        ctx.strokePath()
        ctx.restoreGState()

        // ── 3. 纸张（白色，轻微阴影）─────────────────────────
        let paperW  = s * 0.56
        let paperH  = s * 0.62
        let paperX  = (s - paperW) / 2
        let paperY  = (s - paperH) / 2 + s * 0.02
        let paperRect = CGRect(x: paperX, y: paperY, width: paperW, height: paperH)
        let paperR  = s * 0.055

        // 阴影
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.025),
                      blur: s * 0.07,
                      color: NSColor.black.withAlphaComponent(0.55).cgColor)

        let paperPath = CGMutablePath()
        paperPath.addRoundedRect(in: paperRect, cornerWidth: paperR, cornerHeight: paperR)
        ctx.addPath(paperPath)
        // 纸张：极浅灰白，不是纯白，显得更精致
        NSColor(white: 0.97, alpha: 1).setFill()
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // ── 4. 纸张顶部折角（右上角）─────────────────────────
        let foldSize = paperW * 0.18
        ctx.saveGState()
        // 剪掉右上角三角
        let clipPath = CGMutablePath()
        clipPath.addRoundedRect(in: paperRect, cornerWidth: paperR, cornerHeight: paperR)
        ctx.addPath(clipPath)
        ctx.clip()

        // 折角背景（灰色三角）
        ctx.beginPath()
        ctx.move(to:    CGPoint(x: paperRect.maxX - foldSize, y: paperRect.maxY))
        ctx.addLine(to: CGPoint(x: paperRect.maxX,            y: paperRect.maxY))
        ctx.addLine(to: CGPoint(x: paperRect.maxX,            y: paperRect.maxY - foldSize))
        ctx.closePath()
        NSColor(white: 0.82, alpha: 1).setFill()
        ctx.fillPath()

        // 折角斜线（深色分界）
        ctx.beginPath()
        ctx.move(to:    CGPoint(x: paperRect.maxX - foldSize, y: paperRect.maxY))
        ctx.addLine(to: CGPoint(x: paperRect.maxX,            y: paperRect.maxY - foldSize))
        ctx.setStrokeColor(NSColor(white: 0.68, alpha: 1).cgColor)
        ctx.setLineWidth(max(1, s * 0.008))
        ctx.strokePath()
        ctx.restoreGState()

        // ── 5. 三根文字线条 ────────────────────────────────────
        let lineX    = paperX + paperW * 0.13
        let lineMaxX = paperRect.maxX - paperW * 0.26  // 避开折角
        let lineH    = max(2, s * 0.022)
        let lineCapR = lineH / 2
        let lineGap  = s * 0.095
        let lineY1   = paperY + paperH * 0.60
        let lineY2   = lineY1 - lineGap
        let lineY3   = lineY2 - lineGap

        // 线条颜色：深灰配黑色背景
        let lineColors: [(CGFloat, CGFloat)] = [
            (0.65, 1.0),   // 行1：全宽，中灰
            (0.65, 1.0),   // 行2：全宽，中灰
            (0.65, 0.58),  // 行3：短，稍淡
        ]
        for (i, (alpha, wMult)) in lineColors.enumerated() {
            let y  = [lineY1, lineY2, lineY3][i]
            let lw = (lineMaxX - lineX) * wMult
            let lr = CGRect(x: lineX, y: y - lineCapR, width: lw, height: lineH)
            let lp = CGMutablePath()
            lp.addRoundedRect(in: lr, cornerWidth: lineCapR, cornerHeight: lineCapR)
            ctx.addPath(lp)
            NSColor(white: 0.30, alpha: alpha).setFill()
            ctx.fillPath()
        }

        // ── 6. 铅笔（右下角，黑色系）─────────────────────────
        let penLen  = s * 0.30
        let penW    = s * 0.055
        let penPivX = paperX + paperW * 0.80
        let penPivY = paperY + paperH * 0.18

        ctx.saveGState()
        ctx.translateBy(x: penPivX, y: penPivY)
        ctx.rotate(by: .pi / 4 + 0.1)   // 斜放 45°+小角度

        // 笔身（深灰）
        let penBodyH = penLen * 0.72
        let penBodyRect = CGRect(x: -penW / 2, y: 0, width: penW, height: penBodyH)
        let penBodyR    = min(penW / 2, penBodyRect.height / 2)
        let penBodyPath = CGMutablePath()
        penBodyPath.addRoundedRect(in: penBodyRect, cornerWidth: penBodyR, cornerHeight: penBodyR)
        ctx.addPath(penBodyPath)
        // 深灰渐变笔身
        let penGrad = CGGradient(colorsSpace: csp, colors: [
            NSColor(white: 0.42, alpha: 1).cgColor,
            NSColor(white: 0.28, alpha: 1).cgColor,
        ] as CFArray, locations: [0.0, 1.0])!
        ctx.clip()
        ctx.drawLinearGradient(penGrad,
                               start: CGPoint(x: -penW / 2, y: 0),
                               end:   CGPoint(x: penW / 2, y: 0),
                               options: [])
        ctx.resetClip()

        // 金属环
        let ringH   = penBodyH * 0.10
        let ringRect = CGRect(x: -penW / 2, y: penBodyH - ringH, width: penW, height: ringH)
        let ringPath = CGMutablePath()
        ringPath.addRect(ringRect)
        ctx.addPath(ringPath)
        NSColor(white: 0.62, alpha: 1).setFill()
        ctx.fillPath()

        // 橡皮擦
        let eraserH    = penBodyH * 0.14
        let eraserY    = penBodyH
        let eraserRect = CGRect(x: -penW / 2, y: eraserY, width: penW, height: eraserH)
        let eraserR    = min(penW / 2, eraserH / 2)
        let eraserPath = CGMutablePath()
        eraserPath.addRoundedRect(in: eraserRect, cornerWidth: eraserR, cornerHeight: eraserR)
        ctx.addPath(eraserPath)
        NSColor(white: 0.78, alpha: 1).setFill()
        ctx.fillPath()

        // 笔尖（三角形，浅灰）
        ctx.beginPath()
        ctx.move(to:    CGPoint(x: -penW / 2, y: 0))
        ctx.addLine(to: CGPoint(x: penW / 2,  y: 0))
        ctx.addLine(to: CGPoint(x: 0,         y: -penLen * 0.26))
        ctx.closePath()
        NSColor(white: 0.88, alpha: 1).setFill()
        ctx.fillPath()

        // 笔尖末端深点（石墨笔芯）
        let tipSize = penW * 0.25
        ctx.beginPath()
        ctx.move(to:    CGPoint(x: -tipSize, y: 0))
        ctx.addLine(to: CGPoint(x: tipSize,  y: 0))
        ctx.addLine(to: CGPoint(x: 0,        y: -penLen * 0.26))
        ctx.closePath()
        NSColor(white: 0.20, alpha: 1).setFill()
        ctx.fillPath()

        ctx.restoreGState()

        image.unlockFocus()
        return image
    }
}
