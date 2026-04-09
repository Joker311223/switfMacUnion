import AppKit
import CoreGraphics

// MARK: - 应用图标生成器

enum AppIconMaker {

    static func makeIcon(size: CGSize = CGSize(width: 512, height: 512)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        guard let ctx = NSGraphicsContext.current?.cgContext else { return image }

        let w = size.width
        let h = size.height
        let p = w / 512   // 缩放系数，方便按 512pt 写坐标

        // ── 1. 圆角矩形剪裁区域 ──────────────────────────────
        let corner: CGFloat = w * 0.225   // macOS 图标标准圆角比例
        let bgPath = CGPath(
            roundedRect: CGRect(origin: .zero, size: size),
            cornerWidth: corner, cornerHeight: corner, transform: nil
        )
        ctx.addPath(bgPath)
        ctx.clip()

        // ── 2. 背景：深蓝→深紫 径向渐变 ─────────────────────
        let cs = CGColorSpaceCreateDeviceRGB()
        let bgGrad = CGGradient(colorsSpace: cs, colors: [
            CGColor(red: 0.07, green: 0.09, blue: 0.22, alpha: 1),  // 深午夜蓝
            CGColor(red: 0.13, green: 0.07, blue: 0.28, alpha: 1),  // 深紫
        ] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(bgGrad,
            startCenter: CGPoint(x: w * 0.5, y: h * 0.45),
            startRadius: 0,
            endCenter: CGPoint(x: w * 0.5, y: h * 0.5),
            endRadius: w * 0.78,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        // ── 3. 顶部光晕（营造玻璃感）────────────────────────
        let glowGrad = CGGradient(colorsSpace: cs, colors: [
            CGColor(red: 0.55, green: 0.65, blue: 1.0, alpha: 0.18),
            CGColor(red: 0.55, green: 0.65, blue: 1.0, alpha: 0),
        ] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glowGrad,
            startCenter: CGPoint(x: w * 0.5, y: h * 0.08),
            startRadius: 0,
            endCenter: CGPoint(x: w * 0.5, y: h * 0.08),
            endRadius: w * 0.65,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        // ── 4. 视频胶片条（顶部 + 底部装饰）────────────────
        drawFilmStrip(ctx, x: 0, y: h * 0.06, w: w, h: 38 * p, p: p)
        drawFilmStrip(ctx, x: 0, y: h * 0.86, w: w, h: 38 * p, p: p)

        // ── 5. 中央：精致剪刀 ────────────────────────────────
        drawScissors(ctx, cx: w * 0.5, cy: h * 0.47, size: w * 0.52, p: p)

        // ── 6. 底部时间轴 ────────────────────────────────────
        drawTimeline(ctx, cx: w * 0.5, cy: h * 0.79, w: w * 0.72, p: p)

        return image
    }

    // MARK: - 胶片条

    private static func drawFilmStrip(_ ctx: CGContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, p: CGFloat) {
        // 背景条
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
        ctx.fill(CGRect(x: x, y: y, width: w, height: h))

        // 顶/底边高光线
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
        ctx.fill(CGRect(x: x, y: y + h - 1.5 * p, width: w, height: 1.5 * p))
        ctx.fill(CGRect(x: x, y: y, width: w, height: 1.5 * p))

        // 胶片孔
        let holeW: CGFloat = 18 * p
        let holeH: CGFloat = 22 * p
        let holeY = y + (h - holeH) / 2
        let gap: CGFloat = 34 * p
        var hx: CGFloat = 22 * p
        ctx.setFillColor(CGColor(red: 0.18, green: 0.20, blue: 0.35, alpha: 1))
        while hx + holeW < w - 10 * p {
            let holeRect = CGRect(x: hx, y: holeY, width: holeW, height: holeH)
            let holePath = CGPath(roundedRect: holeRect, cornerWidth: 4 * p, cornerHeight: 4 * p, transform: nil)
            ctx.addPath(holePath)
            ctx.fillPath()
            hx += holeW + gap
        }
    }

    // MARK: - 剪刀

    private static func drawScissors(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, size: CGFloat, p: CGFloat) {
        // 剪刀参数
        let bladeLen: CGFloat  = size * 0.50   // 刀片长度
        let handleLen: CGFloat = size * 0.38   // 把手到交叉点
        let bladeAngle: CGFloat = 22 * .pi / 180   // 上下刀片张角
        let pivotR: CGFloat = size * 0.045          // 中心轴钉半径
        let handleR: CGFloat = size * 0.115          // 把手环半径
        let lineW: CGFloat   = size * 0.062          // 线宽

        // 刀片颜色：冷钢蓝白
        let bladeColor = CGColor(red: 0.78, green: 0.88, blue: 1.0, alpha: 1)
        // 把手颜色：半透明蓝
        let handleFill = CGColor(red: 0.30, green: 0.55, blue: 0.95, alpha: 0.9)
        let handleStroke = CGColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 1)
        // 轴钉：亮黄
        let pivotColor = CGColor(red: 1.0, green: 0.88, blue: 0.25, alpha: 1)

        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        for sign: CGFloat in [-1, 1] {  // sign=-1: 上刀片, sign=1: 下刀片
            let angle = sign * bladeAngle

            // 刀尖方向
            let tipX = cx + bladeLen * cos(angle)
            let tipY = cy + bladeLen * sin(angle)
            // 把手方向（反向）
            let baseX = cx - handleLen * cos(angle)
            let baseY = cy - handleLen * sin(angle)

            // 刀片
            ctx.setStrokeColor(bladeColor)
            ctx.setLineWidth(lineW)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: cx, y: cy))
            ctx.addLine(to: CGPoint(x: tipX, y: tipY))
            ctx.strokePath()

            // 刀片高光（上方一层细亮线）
            ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
            ctx.setLineWidth(lineW * 0.3)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: cx, y: cy))
            ctx.addLine(to: CGPoint(x: tipX, y: tipY))
            ctx.strokePath()

            // 把手：先画填充圆，再描边
            let ringPath = CGMutablePath()
            // 外圆
            ringPath.addEllipse(in: CGRect(
                x: baseX - handleR, y: baseY - handleR,
                width: handleR * 2, height: handleR * 2))
            // 内圆（镂空）
            ringPath.addEllipse(in: CGRect(
                x: baseX - handleR * 0.52, y: baseY - handleR * 0.52,
                width: handleR * 1.04, height: handleR * 1.04))
            ctx.addPath(ringPath)
            ctx.setFillColor(handleFill)
            ctx.setBlendMode(.normal)
            ctx.fillPath(using: .evenOdd)

            // 把手描边
            ctx.addEllipse(in: CGRect(
                x: baseX - handleR, y: baseY - handleR,
                width: handleR * 2, height: handleR * 2))
            ctx.setStrokeColor(handleStroke)
            ctx.setLineWidth(lineW * 0.55)
            ctx.strokePath()

            // 把手连接杆（从把手圆心到交叉点）
            ctx.setStrokeColor(bladeColor)
            ctx.setLineWidth(lineW * 0.75)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: baseX, y: baseY))
            ctx.addLine(to: CGPoint(x: cx, y: cy))
            ctx.strokePath()
        }

        // 中央轴钉（最后绘制，压在刀片上面）
        // 外圈阴影
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.4))
        ctx.fillEllipse(in: CGRect(
            x: cx - pivotR * 1.35, y: cy - pivotR * 1.2,
            width: pivotR * 2.7, height: pivotR * 2.7))
        // 轴钉本体
        let pivotGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            CGColor(red: 1.0, green: 0.95, blue: 0.50, alpha: 1),
            CGColor(red: 0.85, green: 0.62, blue: 0.05, alpha: 1),
        ] as CFArray, locations: [0, 1])!
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: cx - pivotR, y: cy - pivotR, width: pivotR * 2, height: pivotR * 2))
        ctx.clip()
        ctx.drawLinearGradient(pivotGrad,
            start: CGPoint(x: cx - pivotR, y: cy + pivotR),
            end: CGPoint(x: cx + pivotR, y: cy - pivotR),
            options: [])
        ctx.restoreGState()
        // 轴钉高光点
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.7))
        ctx.fillEllipse(in: CGRect(
            x: cx - pivotR * 0.38, y: cy + pivotR * 0.18,
            width: pivotR * 0.45, height: pivotR * 0.45))

        _ = pivotColor  // suppress unused warning
    }

    // MARK: - 时间轴

    private static func drawTimeline(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, w: CGFloat, p: CGFloat) {
        let barH: CGFloat = 18 * p
        let barX = cx - w / 2
        let barR: CGFloat = barH / 2

        // 轨道背景（圆角胶囊）
        let trackPath = CGPath(
            roundedRect: CGRect(x: barX, y: cy - barH / 2, width: w, height: barH),
            cornerWidth: barR, cornerHeight: barR, transform: nil)
        ctx.addPath(trackPath)
        ctx.setFillColor(CGColor(red: 0.12, green: 0.14, blue: 0.32, alpha: 0.9))
        ctx.fillPath()

        // 轨道描边
        ctx.addPath(trackPath)
        ctx.setStrokeColor(CGColor(red: 0.35, green: 0.42, blue: 0.72, alpha: 0.6))
        ctx.setLineWidth(1.5 * p)
        ctx.strokePath()

        // 片段 1：橙色
        let seg1 = segmentPath(x: barX + w * 0.08, y: cy - barH / 2,
                                w: w * 0.24, h: barH, r: barR * 0.7)
        ctx.addPath(seg1)
        let g1 = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            CGColor(red: 1.0, green: 0.72, blue: 0.18, alpha: 1),
            CGColor(red: 0.95, green: 0.42, blue: 0.05, alpha: 1),
        ] as CFArray, locations: [0, 1])!
        ctx.saveGState()
        ctx.addPath(seg1)
        ctx.clip()
        ctx.drawLinearGradient(g1,
            start: CGPoint(x: barX + w * 0.08, y: cy + barH / 2),
            end: CGPoint(x: barX + w * 0.08, y: cy - barH / 2),
            options: [])
        ctx.restoreGState()

        // 片段 2：青绿色
        let seg2 = segmentPath(x: barX + w * 0.50, y: cy - barH / 2,
                                w: w * 0.30, h: barH, r: barR * 0.7)
        let g2 = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            CGColor(red: 0.22, green: 0.92, blue: 0.62, alpha: 1),
            CGColor(red: 0.05, green: 0.68, blue: 0.42, alpha: 1),
        ] as CFArray, locations: [0, 1])!
        ctx.saveGState()
        ctx.addPath(seg2)
        ctx.clip()
        ctx.drawLinearGradient(g2,
            start: CGPoint(x: barX + w * 0.5, y: cy + barH / 2),
            end: CGPoint(x: barX + w * 0.5, y: cy - barH / 2),
            options: [])
        ctx.restoreGState()

        // 片段高光：顶部白色细线
        for seg in [seg1, seg2] {
            ctx.saveGState()
            ctx.addPath(seg)
            ctx.clip()
            let glowH = barH * 0.4
            let highlightGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                CGColor(red: 1, green: 1, blue: 1, alpha: 0.32),
                CGColor(red: 1, green: 1, blue: 1, alpha: 0),
            ] as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(highlightGrad,
                start: CGPoint(x: cx, y: cy + barH / 2),
                end: CGPoint(x: cx, y: cy + barH / 2 - glowH),
                options: [])
            ctx.restoreGState()
        }

        // 播放头：白色竖线 + 顶部三角
        let phX = barX + w * 0.35
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
        ctx.setLineWidth(2.5 * p)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: phX, y: cy - barH * 0.9))
        ctx.addLine(to: CGPoint(x: phX, y: cy + barH * 0.9))
        ctx.strokePath()
        // 顶部三角
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
        let triH: CGFloat = 7 * p
        let triW: CGFloat = 5 * p
        ctx.beginPath()
        ctx.move(to: CGPoint(x: phX, y: cy - barH * 0.9))
        ctx.addLine(to: CGPoint(x: phX - triW, y: cy - barH * 0.9 - triH))
        ctx.addLine(to: CGPoint(x: phX + triW, y: cy - barH * 0.9 - triH))
        ctx.closePath()
        ctx.fillPath()
    }

    private static func segmentPath(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h),
               cornerWidth: r, cornerHeight: r, transform: nil)
    }
}
