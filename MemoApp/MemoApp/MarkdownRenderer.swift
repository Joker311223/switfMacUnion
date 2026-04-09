import AppKit
import Foundation

// MARK: - 高颜值 Markdown 渲染器
final class MarkdownRenderer {

    // ──────────────────────────────────────────────────────────────
    // MARK: 主入口
    // ──────────────────────────────────────────────────────────────
    static func render(_ markdown: String, darkMode: Bool = false) -> NSAttributedString {
        let pal  = Palette(dark: darkMode)
        let result = NSMutableAttributedString()
        let lines  = markdown.components(separatedBy: "\n")

        var i = 0
        var inCode   = false
        var codeBuf: [String] = []
        var codeLang = ""

        while i < lines.count {
            let raw = lines[i]

            // ── 代码块 ─────────────────────────────────────────
            if raw.hasPrefix("```") {
                if inCode {
                    result.append(renderCodeBlock(codeBuf.joined(separator: "\n"),
                                                   lang: codeLang, pal: pal))
                    inCode = false; codeBuf = []; codeLang = ""
                } else {
                    inCode   = true
                    codeLang = String(raw.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                i += 1; continue
            }
            if inCode { codeBuf.append(raw); i += 1; continue }

            // ── 水平分隔线 ─────────────────────────────────────
            if raw.trimmingCharacters(in: .whitespaces) == "---"
                || raw.trimmingCharacters(in: .whitespaces) == "***"
                || raw.trimmingCharacters(in: .whitespaces) == "___" {
                result.append(makeDivider(pal: pal))
                i += 1; continue
            }

            // ── 标题 ───────────────────────────────────────────
            if raw.hasPrefix("#### ") {
                result.append(makeHeading(String(raw.dropFirst(5)), level: 4, pal: pal))
            } else if raw.hasPrefix("### ") {
                result.append(makeHeading(String(raw.dropFirst(4)), level: 3, pal: pal))
            } else if raw.hasPrefix("## ") {
                result.append(makeHeading(String(raw.dropFirst(3)), level: 2, pal: pal))
            } else if raw.hasPrefix("# ") {
                result.append(makeHeading(String(raw.dropFirst(2)), level: 1, pal: pal))

            // ── 引用 ───────────────────────────────────────────
            } else if raw.hasPrefix("> ") {
                result.append(makeBlockquote(String(raw.dropFirst(2)), pal: pal))

            // ── 任务列表（需在无序列表前判断）─────────────────
            } else if raw.hasPrefix("- [x] ") || raw.hasPrefix("- [X] ") {
                let text = "✅  " + String(raw.dropFirst(6))
                result.append(makeInline(text + "\n", size: 14, color: pal.text, pal: pal, indent: 10))
            } else if raw.hasPrefix("- [ ] ") {
                let text = "⬜️  " + String(raw.dropFirst(6))
                result.append(makeInline(text + "\n", size: 14, color: pal.textSecondary, pal: pal, indent: 10))

            // ── 无序列表 ───────────────────────────────────────
            } else if raw.hasPrefix("  - ") || raw.hasPrefix("  * ") {
                // 二级缩进列表
                let text = "    ◦ " + String(raw.dropFirst(4))
                result.append(makeInline(text + "\n", size: 14, color: pal.text, pal: pal, indent: 24))
            } else if raw.hasPrefix("- ") || raw.hasPrefix("* ") || raw.hasPrefix("+ ") {
                let bullet = bulletSymbol(i, lines: lines)
                let text   = bullet + " " + String(raw.dropFirst(2))
                result.append(makeInline(text + "\n", size: 14, color: pal.text, pal: pal, indent: 10))

            // ── 有序列表 ───────────────────────────────────────
            } else if let m = raw.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                let numStr = String(raw[m])
                let rest   = String(raw[m.upperBound...])
                let attr   = NSMutableAttributedString()
                let numPart = NSAttributedString(string: numStr, attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: pal.accent
                ])
                attr.append(numPart)
                attr.append(makeInline(rest + "\n", size: 14, color: pal.text, pal: pal))
                let ps = NSMutableParagraphStyle()
                ps.headIndent = 20; ps.firstLineHeadIndent = 0
                attr.addAttribute(.paragraphStyle, value: ps,
                                  range: NSRange(location: 0, length: attr.length))
                result.append(attr)

            // ── 表格行（简单支持）─────────────────────────────
            } else if raw.hasPrefix("|") && raw.hasSuffix("|") {
                result.append(makeTableRow(raw, pal: pal,
                                           isHeader: i > 0 && lines[i - 1].hasPrefix("|") == false))

            // ── 图片行 ![alt](src) ─────────────────────────────
            } else if raw.trimmingCharacters(in: .whitespaces).hasPrefix("!["),
                      let imgAttr = parseImageLine(raw, pal: pal) {
                result.append(imgAttr)

            // ── 空行 ───────────────────────────────────────────
            } else if raw.trimmingCharacters(in: .whitespaces).isEmpty {
                result.append(NSAttributedString(string: "\n",
                    attributes: [.font: NSFont.systemFont(ofSize: 6)]))

            // ── 普通段落 ───────────────────────────────────────
            } else {
                let ps = NSMutableParagraphStyle()
                ps.lineSpacing      = 3
                ps.paragraphSpacing = 2
                let base = makeInline(raw + "\n", size: 14, color: pal.text, pal: pal)
                let m2   = NSMutableAttributedString(attributedString: base)
                m2.addAttribute(.paragraphStyle, value: ps,
                                range: NSRange(location: 0, length: m2.length))
                result.append(m2)
            }

            i += 1
        }

        return result
    }

    // ──────────────────────────────────────────────────────────────
    // MARK: 各元素渲染
    // ──────────────────────────────────────────────────────────────

    // 标题
    private static func makeHeading(_ text: String, level: Int, pal: Palette) -> NSAttributedString {
        let cfg: [(CGFloat, NSFont.Weight, NSColor, CGFloat, CGFloat)] = [
            (26, .bold,     pal.h1,   14, 6),   // H1
            (21, .semibold, pal.h2,   10, 4),   // H2
            (17, .semibold, pal.h3,    8, 3),   // H3
            (15, .medium,   pal.h4,    6, 2),   // H4
        ]
        let (size, weight, color, spaceBefore, spaceAfter) = cfg[min(level - 1, 3)]

        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = spaceBefore
        ps.paragraphSpacing       = spaceAfter
        ps.lineSpacing            = 2

        let attr = NSMutableAttributedString(string: text + "\n")
        attr.addAttributes([
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: ps,
        ], range: NSRange(location: 0, length: attr.length))

        // H1/H2 下划线装饰
        if level <= 2 {
            attr.addAttribute(.underlineStyle,
                              value: NSUnderlineStyle.single.rawValue,
                              range: NSRange(location: attr.length - 1, length: 1))
            attr.addAttribute(.underlineColor,
                              value: color.withAlphaComponent(0.3),
                              range: NSRange(location: 0, length: attr.length))
        }
        return attr
    }

    // 引用块
    private static func makeBlockquote(_ text: String, pal: Palette) -> NSAttributedString {
        let attr = NSMutableAttributedString()

        // 竖线装饰（用特殊字符 + 颜色模拟）
        let bar = NSAttributedString(string: "┃ ", attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: pal.quote,
        ])
        let body = makeInline(text + "\n", size: 14, color: pal.quoteText, pal: pal)

        attr.append(bar)
        attr.append(body)

        let ps = NSMutableParagraphStyle()
        ps.headIndent            = 18
        ps.firstLineHeadIndent   = 0
        ps.paragraphSpacingBefore = 2
        ps.paragraphSpacing      = 2
        attr.addAttribute(.paragraphStyle, value: ps,
                          range: NSRange(location: 0, length: attr.length))
        // 整块背景色
        attr.addAttribute(.backgroundColor, value: pal.quoteBg,
                          range: NSRange(location: 0, length: attr.length))
        return attr
    }

    // 代码块
    private static func renderCodeBlock(_ code: String, lang: String, pal: Palette) -> NSAttributedString {
        let ps = NSMutableParagraphStyle()
        ps.headIndent          = 14
        ps.firstLineHeadIndent = 14
        ps.tailIndent          = -14
        ps.paragraphSpacingBefore = 4
        ps.paragraphSpacing    = 4
        ps.lineSpacing         = 2

        let displayCode = code.isEmpty ? " " : code

        // 语言标签行
        let attr = NSMutableAttributedString()
        if !lang.isEmpty {
            let langLabel = NSAttributedString(string: lang + "\n", attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: pal.codeLang,
                .backgroundColor: pal.codeLangBg,
            ])
            attr.append(langLabel)
        }

        let codeAttr = NSMutableAttributedString(string: displayCode + "\n")
        codeAttr.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular),
            .foregroundColor: pal.codeText,
            .backgroundColor: pal.codeBg,
            .paragraphStyle: ps,
        ], range: NSRange(location: 0, length: codeAttr.length))
        attr.append(codeAttr)
        return attr
    }

    // 分隔线
    private static func makeDivider(pal: Palette) -> NSAttributedString {
        let line = String(repeating: "─", count: 40)
        let attr = NSMutableAttributedString(string: line + "\n")
        let ps   = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = 6
        ps.paragraphSpacing       = 6
        attr.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .light),
            .foregroundColor: pal.divider,
            .paragraphStyle: ps,
        ], range: NSRange(location: 0, length: attr.length))
        return attr
    }

    // 表格行
    private static func makeTableRow(_ raw: String, pal: Palette, isHeader: Bool) -> NSAttributedString {
        // 跳过分隔行 |---|---|
        if raw.contains("---") { return NSAttributedString(string: "") }

        let cells = raw.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let attr = NSMutableAttributedString()
        for (j, cell) in cells.enumerated() {
            let sep = NSAttributedString(string: " │ ", attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: pal.tableBorder,
            ])
            if j > 0 { attr.append(sep) }
            let cellAttr = NSMutableAttributedString(string: cell)
            cellAttr.addAttributes([
                .font: isHeader
                    ? NSFont.systemFont(ofSize: 13, weight: .semibold)
                    : NSFont.systemFont(ofSize: 13),
                .foregroundColor: isHeader ? pal.tableHeader : pal.text,
                .backgroundColor: isHeader ? pal.tableHeaderBg : pal.tableCellBg,
            ], range: NSRange(location: 0, length: cellAttr.length))
            attr.append(cellAttr)
        }
        attr.append(NSAttributedString(string: "\n"))
        return attr
    }

    // ── 行内格式解析（**bold** *italic* `code` ~~strike~~ [link](url) ==highlight==）
    static func makeInline(_ text: String, size: CGFloat, color: NSColor,
                            pal: Palette, indent: CGFloat = 0) -> NSAttributedString {
        let result   = NSMutableAttributedString()
        let baseFont = NSFont.systemFont(ofSize: size)
        var rem      = Substring(text)

        while !rem.isEmpty {
            // ==highlight==
            if rem.hasPrefix("=="), let end = rem.dropFirst(2).range(of: "==") {
                let t = String(rem.dropFirst(2)[..<end.lowerBound])
                result.append(NSAttributedString(string: t, attributes: [
                    .font: baseFont, .foregroundColor: pal.highlight,
                    .backgroundColor: pal.highlightBg,
                ]))
                rem = rem.dropFirst(2)[end.upperBound...]
            }
            // **bold**
            else if rem.hasPrefix("**"), let end = rem.dropFirst(2).range(of: "**") {
                let t = String(rem.dropFirst(2)[..<end.lowerBound])
                result.append(NSAttributedString(string: t, attributes: [
                    .font: NSFont.systemFont(ofSize: size, weight: .bold),
                    .foregroundColor: pal.bold,
                ]))
                rem = rem.dropFirst(2)[end.upperBound...]
            }
            // *italic* or _italic_
            else if (rem.hasPrefix("*") && !rem.hasPrefix("**")) || rem.hasPrefix("_"),
                    let delim = rem.first.map({ String($0) }),
                    let end = rem.dropFirst(1).range(of: delim) {
                let t = String(rem.dropFirst(1)[..<end.lowerBound])
                result.append(NSAttributedString(string: t, attributes: [
                    .font: baseFont.italic(), .foregroundColor: color,
                ]))
                rem = rem.dropFirst(1)[end.upperBound...]
            }
            // `code`
            else if rem.hasPrefix("`"), let end = rem.dropFirst(1).range(of: "`") {
                let t = String(rem.dropFirst(1)[..<end.lowerBound])
                result.append(NSAttributedString(string: t, attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: size - 1, weight: .regular),
                    .foregroundColor: pal.inlineCode,
                    .backgroundColor: pal.inlineCodeBg,
                ]))
                rem = rem.dropFirst(1)[end.upperBound...]
            }
            // ~~strikethrough~~
            else if rem.hasPrefix("~~"), let end = rem.dropFirst(2).range(of: "~~") {
                let t = String(rem.dropFirst(2)[..<end.lowerBound])
                result.append(NSAttributedString(string: t, attributes: [
                    .font: baseFont, .foregroundColor: pal.textSecondary,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: pal.textSecondary,
                ]))
                rem = rem.dropFirst(2)[end.upperBound...]
            }
            // [text](url)
            else if rem.hasPrefix("["),
                    let closeBracket = rem.range(of: "]("),
                    let closeUrl = rem[closeBracket.upperBound...].range(of: ")") {
                let linkText = String(rem[rem.index(after: rem.startIndex)..<closeBracket.lowerBound])
                let url      = String(rem[closeBracket.upperBound..<closeUrl.lowerBound])
                let linkAttr = NSMutableAttributedString(string: linkText)
                var attrs: [NSAttributedString.Key: Any] = [
                    .font: baseFont, .foregroundColor: pal.link,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: pal.link,
                ]
                if let u = URL(string: url) { attrs[.link] = u }
                linkAttr.addAttributes(attrs, range: NSRange(location: 0, length: linkAttr.length))
                result.append(linkAttr)
                rem = rem[closeUrl.upperBound...]
            }
            // 普通字符
            else {
                let ch = String(rem.removeFirst())
                result.append(NSAttributedString(string: ch, attributes: [
                    .font: baseFont, .foregroundColor: color,
                ]))
            }
        }

        if indent > 0 {
            let ps = NSMutableParagraphStyle()
            ps.headIndent          = indent
            ps.firstLineHeadIndent = indent
            result.addAttribute(.paragraphStyle, value: ps,
                                range: NSRange(location: 0, length: result.length))
        }
        return result
    }

    // 根据列表上下文决定 bullet 符号
    private static func bulletSymbol(_ idx: Int, lines: [String]) -> String {
        return "•"
    }

    // ── 解析图片行 ![alt](src) → NSAttributedString（含内嵌图片）
    private static func parseImageLine(_ raw: String, pal: Palette) -> NSAttributedString? {
        // 手动解析 ![alt](src)，避免正则在超长 base64 字符串时超时
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("![") else { return nil }

        // 找 "](" 位置
        guard let bracketClose = trimmed.range(of: "](") else { return nil }
        let alt = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<bracketClose.lowerBound])

        // 找最后一个 ")" 作为 src 结束
        let srcStart = bracketClose.upperBound
        guard let parenClose = trimmed[srcStart...].lastIndex(of: ")") else { return nil }
        let src = String(trimmed[srcStart..<parenClose])

        var image: NSImage?

        if src.hasPrefix("data:image") {
            // base64 内嵌图片
            if let commaIdx = src.firstIndex(of: ",") {
                let b64 = String(src[src.index(after: commaIdx)...])
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: " ",  with: "")
                if let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) {
                    image = NSImage(data: data)
                }
            }
        } else if !src.isEmpty {
            // 本地文件路径或 URL
            if src.hasPrefix("http") {
                // 网络图片（同步加载，仅作简单支持）
                if let url = URL(string: src), let data = try? Data(contentsOf: url) {
                    image = NSImage(data: data)
                }
            } else {
                image = NSImage(contentsOfFile: src)
            }
        }

        let result = NSMutableAttributedString()

        if let img = image {
            // 限制预览宽度最大 480pt
            let maxW: CGFloat = 480
            let scale = img.size.width > maxW ? maxW / img.size.width : 1.0
            let displaySize = NSSize(width: img.size.width * scale,
                                     height: img.size.height * scale)

            let attachment = NSTextAttachment()
            attachment.image = img
            attachment.bounds = CGRect(origin: .zero, size: displaySize)

            // 换行 + 图片 + 换行
            result.append(NSAttributedString(string: "\n"))
            result.append(NSAttributedString(attachment: attachment))

            // alt 文字说明（灰色小字）
            if !alt.isEmpty && alt != "image" {
                let caption = NSAttributedString(string: "\n" + alt, attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: pal.textSecondary,
                ])
                result.append(caption)
            }
            result.append(NSAttributedString(string: "\n"))
        } else {
            // 图片加载失败：显示带颜色的占位文字
            let placeholder = NSAttributedString(string: "🖼 \(alt.isEmpty ? "图片" : alt)\n",
                                                  attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: pal.textSecondary,
            ])
            result.append(placeholder)
        }
        return result
    }
}

// ──────────────────────────────────────────────────────────────────
// MARK: - 调色板
// ──────────────────────────────────────────────────────────────────
struct Palette {
    let dark: Bool

    // 正文（支持用户自定义）
    var text: NSColor {
        let s = AppSettings.shared
        if !s.colorBody.isEmpty, let c = NSColor.fromHex(s.colorBody) { return c }
        return dark ? NSColor(white: 0.88, alpha: 1) : NSColor(white: 0.13, alpha: 1)
    }
    var textSecondary: NSColor { dark ? NSColor(white: 0.55, alpha: 1) : NSColor(white: 0.45, alpha: 1) }

    // 标题色（支持用户自定义，fallback 到默认配色）
    var h1: NSColor {
        let s = AppSettings.shared
        if !s.colorH1.isEmpty, let c = NSColor.fromHex(s.colorH1) { return c }
        return dark ? c(0.40, 0.75, 1.00) : c(0.08, 0.40, 0.78)
    }
    var h2: NSColor {
        let s = AppSettings.shared
        if !s.colorH2.isEmpty, let c = NSColor.fromHex(s.colorH2) { return c }
        return dark ? c(0.55, 0.88, 0.72) : c(0.08, 0.52, 0.35)
    }
    var h3: NSColor {
        let s = AppSettings.shared
        if !s.colorH3.isEmpty, let c = NSColor.fromHex(s.colorH3) { return c }
        return dark ? c(1.00, 0.78, 0.40) : c(0.70, 0.42, 0.05)
    }
    var h4: NSColor {
        let s = AppSettings.shared
        if !s.colorH4.isEmpty, let c = NSColor.fromHex(s.colorH4) { return c }
        return dark ? c(0.88, 0.60, 1.00) : c(0.48, 0.18, 0.70)
    }

    // 强调
    var bold:   NSColor { dark ? NSColor(white: 1.0, alpha: 0.92) : NSColor(white: 0.08, alpha: 1) }
    var accent: NSColor { dark ? c(0.40, 0.78, 1.00) : c(0.10, 0.45, 0.85) }
    var link: NSColor {
        let s = AppSettings.shared
        if !s.colorLink.isEmpty, let c = NSColor.fromHex(s.colorLink) { return c }
        return dark ? c(0.45, 0.75, 1.00) : c(0.05, 0.38, 0.80)
    }

    // 高亮 ==text==
    var highlight:   NSColor { dark ? c(1.00, 0.88, 0.30) : c(0.60, 0.40, 0.00) }
    var highlightBg: NSColor { dark ? c(1.00, 0.88, 0.30).withAlphaComponent(0.20)
                                     : c(1.00, 0.96, 0.55).withAlphaComponent(0.80) }

    // 行内 `code`（支持用户自定义）
    var inlineCode: NSColor {
        let s = AppSettings.shared
        if !s.colorCode.isEmpty, let c = NSColor.fromHex(s.colorCode) { return c }
        return dark ? c(1.00, 0.55, 0.45) : c(0.75, 0.18, 0.10)
    }
    var inlineCodeBg: NSColor { dark ? NSColor(white: 0.20, alpha: 1) : NSColor(white: 0.93, alpha: 1) }

    // 代码块
    var codeBg:      NSColor { dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.95, alpha: 1) }
    var codeText:    NSColor { dark ? c(0.75, 0.95, 0.75) : c(0.08, 0.35, 0.18) }  // 绿色代码
    var codeLang:    NSColor { dark ? c(0.55, 0.78, 1.00) : c(0.10, 0.35, 0.75) }
    var codeLangBg:  NSColor { dark ? NSColor(white: 0.18, alpha: 1) : NSColor(white: 0.90, alpha: 1) }

    // 引用
    var quote:    NSColor { dark ? c(0.55, 0.88, 0.72) : c(0.08, 0.60, 0.38) }   // 绿色竖线
    var quoteText: NSColor { dark ? NSColor(white: 0.70, alpha: 1) : NSColor(white: 0.35, alpha: 1) }
    var quoteBg:   NSColor { dark ? c(0.08, 0.60, 0.38).withAlphaComponent(0.12)
                                   : c(0.08, 0.60, 0.38).withAlphaComponent(0.07) }

    // 分隔线
    var divider: NSColor { dark ? NSColor(white: 0.35, alpha: 1) : NSColor(white: 0.72, alpha: 1) }

    // 表格
    var tableBorder:   NSColor { dark ? NSColor(white: 0.35, alpha: 1) : NSColor(white: 0.70, alpha: 1) }
    var tableHeader:   NSColor { dark ? c(0.40, 0.75, 1.00) : c(0.08, 0.40, 0.78) }
    var tableHeaderBg: NSColor { dark ? c(0.08, 0.28, 0.55).withAlphaComponent(0.35)
                                       : c(0.08, 0.40, 0.78).withAlphaComponent(0.08) }
    var tableCellBg:   NSColor { .clear }

    // 工具方法
    private func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: 1)
    }
}

// ──────────────────────────────────────────────────────────────────
// MARK: - NSFont Extension
// ──────────────────────────────────────────────────────────────────
extension NSFont {
    func italic() -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
