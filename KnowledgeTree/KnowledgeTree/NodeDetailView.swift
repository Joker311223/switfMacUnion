import SwiftUI
import AppKit

// MARK: - 编辑 Tab 枚举
enum EditingTab: String, CaseIterable {
    case edit = "编辑"
    case preview = "预览"
}

// MARK: - 节点详情/编辑视图
struct NodeDetailView: View {
    @EnvironmentObject var store: KnowledgeStore

    @State private var editTitle = ""
    @State private var editContent = ""
    @State private var editTagsInput = ""
    @State private var editIcon = ""
    @State private var editColor = ""
    @State private var isEditing = false
    @State private var editingTab: EditingTab = .edit
    @State private var showMetadataEditor = false
    @State private var newMetaKey = ""
    @State private var newMetaValue = ""

    var currentNode: KnowledgeNode? { store.selectedNode }
    var currentTreeId: String? { store.selectedTreeId }

    var nodeColor: Color {
        if let hex = editColor.isEmpty ? currentNode?.color : editColor,
           let c = NSColor(hex: hex) {
            return Color(c)
        }
        if let tree = store.selectedTree,
           let c = NSColor(hex: tree.themeColor) {
            return Color(c)
        }
        return .accentColor
    }

    let iconOptions: [(String, String)] = [
        ("无", ""), ("书籍", "book"), ("灯泡", "lightbulb"), ("代码", "chevron.left.forwardslash.chevron.right"),
        ("星星", "star"), ("心形", "heart"), ("旗帜", "flag"), ("文档", "doc.text"),
        ("链接", "link"), ("脑图", "brain"), ("图表", "chart.bar"), ("时钟", "clock"),
        ("笔记", "pencil"), ("问题", "questionmark.circle"), ("检查", "checkmark.circle"),
        ("地图", "map"), ("网格", "square.grid.2x2"), ("终端", "terminal"),
    ]

    var body: some View {
        Group {
            if let node = currentNode {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 顶部节点 Header
                        nodeHeader(node: node)

                        Divider().padding(.horizontal, 16)

                        if isEditing {
                            editingView(node: node)
                        } else {
                            readingView(node: node)
                        }
                    }
                }
                .onChange(of: store.selectedNodeId) { _ in
                    loadNode()
                    isEditing = false
                }
                .onAppear { loadNode() }
            }
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func nodeHeader(node: KnowledgeNode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // 图标
                ZStack {
                    Circle()
                        .fill(nodeColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    if let iconName = node.icon, !iconName.isEmpty {
                        Image(systemName: iconName)
                            .font(.system(size: 20))
                            .foregroundColor(nodeColor)
                    } else {
                        Text(String(node.title.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(nodeColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)

                    Text("更新于 \(node.updatedAt, style: .relative) 前")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 编辑/保存按钮
                Button(action: {
                    if isEditing {
                        saveChanges()
                    } else {
                        startEditing(node: node)
                    }
                }) {
                    Text(isEditing ? "保存" : "编辑")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isEditing ? nodeColor : Color.secondary.opacity(0.15))
                        .foregroundColor(isEditing ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("e", modifiers: .command)

                if isEditing {
                    Button("取消") {
                        isEditing = false
                        loadNode()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - 阅读模式
    @ViewBuilder
    private func readingView(node: KnowledgeNode) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标签
            if !node.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(node.tags, id: \.self) { tag in
                        TagBadge(text: tag, color: nodeColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // 内容
            if !node.content.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("内容", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)

                    MarkdownContentView(content: node.content, color: nodeColor)
                        .padding(.horizontal, 16)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("暂无内容，点击「编辑」添加")
                        .font(.callout)
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }

            // 元信息
            if !node.metadata.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("扩展信息", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(Array(node.metadata.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(node.metadata[key] ?? "")
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 16)
            }

            // 统计信息
            VStack(spacing: 1) {
                Divider()
                HStack {
                    InfoRow(label: "子节点", value: "\(node.children.count)")
                    Divider().frame(height: 30)
                    InfoRow(label: "总节点", value: "\(node.totalCount - 1)")
                    Divider().frame(height: 30)
                    InfoRow(label: "最大深度", value: "\(node.maxDepth)")
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                Divider()
                HStack {
                    InfoRow(label: "创建", value: node.createdAt.formatted(.dateTime.year().month().day()))
                    Divider().frame(height: 30)
                    InfoRow(label: "更新", value: node.updatedAt.formatted(.dateTime.year().month().day()))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            }
            .background(Color.secondary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }

    // MARK: - 编辑模式
    @ViewBuilder
    private func editingView(node: KnowledgeNode) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            // 标题
            FormField(label: "标题") {
                TextField("节点标题", text: $editTitle)
                    .textFieldStyle(.roundedBorder)
            }

            // 内容（带编辑/预览切换）
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("内容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    // 编辑/预览 Tab 切换
                    HStack(spacing: 0) {
                        ForEach(EditingTab.allCases, id: \.self) { tab in
                            Button(tab.rawValue) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    editingTab = tab
                                }
                            }
                            .font(.system(size: 11, weight: editingTab == tab ? .semibold : .regular))
                            .foregroundColor(editingTab == tab ? .white : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(editingTab == tab ? nodeColor : Color.clear)
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                if editingTab == .edit {
                    TextEditor(text: $editContent)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 160)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1))
                } else {
                    // 预览
                    VStack(alignment: .leading) {
                        if editContent.isEmpty {
                            Text("（暂无内容）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                        } else {
                            MarkdownContentView(content: editContent, color: nodeColor)
                                .padding(10)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
                    .background(Color.secondary.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // 标签
            FormField(label: "标签（逗号分隔）") {
                TextField("例如：基础, 重要", text: $editTagsInput)
                    .textFieldStyle(.roundedBorder)
            }

            // 图标
            FormField(label: "图标") {
                HStack {
                    Picker("图标", selection: $editIcon) {
                        ForEach(iconOptions, id: \.0) { name, icon in
                            if icon.isEmpty {
                                Text("无").tag(icon)
                            } else {
                                Label(name, systemImage: icon).tag(icon)
                            }
                        }
                    }
                    .frame(width: 160)
                    if !editIcon.isEmpty {
                        Image(systemName: editIcon)
                            .font(.system(size: 18))
                            .foregroundColor(nodeColor)
                    }
                }
            }

            // 颜色
            FormField(label: "颜色") {
                HStack(spacing: 8) {
                    ForEach(NSColor.nodeColors, id: \.hex) { item in
                        Button(action: { editColor = item.hex }) {
                            ZStack {
                                Circle()
                                    .fill(Color(NSColor(hex: item.hex)!))
                                    .frame(width: 26, height: 26)
                                if editColor == item.hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: { editColor = "" }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("继承父节点颜色")
                }
            }

            // 元数据编辑
            FormField(label: "扩展信息") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(node.metadata.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text("\(key):")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text(node.metadata[key] ?? "")
                                .font(.system(size: 12))
                            Spacer()
                            Button(action: {
                                if let treeId = currentTreeId {
                                    store.updateNode(node.id, in: treeId) { n in
                                        n.metadata.removeValue(forKey: key)
                                    }
                                    loadNode()
                                }
                            }) {
                                Image(systemName: "minus.circle").foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        TextField("键", text: $newMetaKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        TextField("值", text: $newMetaValue)
                            .textFieldStyle(.roundedBorder)
                        Button("添加") {
                            guard !newMetaKey.isEmpty else { return }
                            if let treeId = currentTreeId {
                                let key = newMetaKey
                                let val = newMetaValue
                                store.updateNode(node.id, in: treeId) { n in
                                    n.metadata[key] = val
                                }
                                newMetaKey = ""
                                newMetaValue = ""
                                loadNode()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newMetaKey.isEmpty)
                    }
                }
            }

            Spacer(minLength: 16)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - 操作

    private func loadNode() {
        guard let node = currentNode else { return }
        editTitle = node.title
        editContent = node.content
        editTagsInput = node.tags.joined(separator: ", ")
        editIcon = node.icon ?? ""
        editColor = node.color ?? ""
    }

    private func startEditing(node: KnowledgeNode) {
        loadNode()
        isEditing = true
    }

    private func saveChanges() {
        guard let node = currentNode, let treeId = currentTreeId else { return }
        let tags = editTagsInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        store.updateNode(node.id, in: treeId) { n in
            n.title = editTitle.trimmingCharacters(in: .whitespaces).isEmpty ? n.title : editTitle
            n.content = editContent
            n.tags = tags
            n.icon = editIcon.isEmpty ? nil : editIcon
            n.color = editColor.isEmpty ? nil : editColor
        }
        isEditing = false
    }
}

// MARK: - Markdown 渲染视图（NSTextView + AttributedString）
struct MarkdownContentView: View {
    let content: String
    let color: Color

    var body: some View {
        MarkdownNSTextView(markdown: content, accentColor: NSColor(color))
    }
}

/// 用 NSTextView 渲染 AttributedString(markdown:)，支持标准 Markdown 全语法
struct MarkdownNSTextView: NSViewRepresentable {
    let markdown: String
    let accentColor: NSColor

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        let textView = NonEditableTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView

        // 设置内容
        textView.textStorage?.setAttributedString(buildAttributedString(markdown, accentColor: accentColor))
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let newAttr = buildAttributedString(markdown, accentColor: accentColor)
        if textView.attributedString() != newAttr {
            textView.textStorage?.setAttributedString(newAttr)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView scrollView: NSScrollView, context: Context) -> CGSize? {
        guard let textView = scrollView.documentView as? NSTextView,
              let container = textView.textContainer,
              let manager = textView.layoutManager else { return nil }
        let width = proposal.width ?? 400
        container.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        manager.ensureLayout(for: container)
        let rect = manager.usedRect(for: container)
        return CGSize(width: width, height: ceil(rect.height) + 4)
    }
}

// 允许点击链接
class NonEditableTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let url = linkAt(point: point) {
            NSWorkspace.shared.open(url)
        } else {
            super.mouseDown(with: event)
        }
    }
    private func linkAt(point: NSPoint) -> URL? {
        guard let manager = layoutManager, let container = textContainer else { return nil }
        let idx = manager.characterIndex(for: point, in: container, fractionOfDistanceBetweenInsertionPoints: nil)
        guard idx < textStorage!.length else { return nil }
        return textStorage!.attribute(.link, at: idx, effectiveRange: nil) as? URL
    }
}

private func buildAttributedString(_ markdown: String, accentColor: NSColor) -> NSAttributedString {
    // 全量解析（包含标题、代码块等）
    let fullOptions = AttributedString.MarkdownParsingOptions(
        allowsExtendedAttributes: true,
        interpretedSyntax: .full,
        failurePolicy: .returnPartiallyParsedIfPossible
    )

    let baseFont = NSFont.systemFont(ofSize: 13)
    let baseColor = NSColor.labelColor

    // 先做代码块预处理，把 ``` 包裹的代码提取替换为占位符，再交给系统解析
    let (processedMarkdown, codeBlocks) = extractCodeBlocks(markdown)

    var attrStr: AttributedString
    do {
        attrStr = try AttributedString(markdown: processedMarkdown, options: fullOptions)
    } catch {
        attrStr = AttributedString(processedMarkdown)
    }

    // 转成 NSAttributedString 进行深度定制
    let result = NSMutableAttributedString(attrStr)

    // 2. 全局基础样式
    let fullRange = NSRange(location: 0, length: result.length)
    result.addAttribute(.font, value: baseFont, range: fullRange)
    result.addAttribute(.foregroundColor, value: baseColor, range: fullRange)

    // 3. 段落样式（行距）
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.lineSpacing = 4
    paraStyle.paragraphSpacing = 6
    result.addAttribute(.paragraphStyle, value: paraStyle, range: fullRange)

    // 4. 处理标题（AttributedString 解析后标题会带 presentationIntent 属性）
    result.enumerateAttribute(.init("NSPresentationIntentAttributeName"), in: fullRange) { val, range, _ in
        // 兜底：直接扫描原始文本中的标题行
    }

    // 重新解析标题行（直接扫描结果文本）
    applyHeadingStyles(to: result, accentColor: accentColor)

    // 5. 内联代码样式
    applyInlineCodeStyles(to: result)

    // 6. 链接颜色
    result.enumerateAttribute(.link, in: NSRange(location: 0, length: result.length)) { val, range, _ in
        if val != nil {
            result.addAttribute(.foregroundColor, value: accentColor, range: range)
            result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
    }

    // 7. 还原代码块
    restoreCodeBlocks(in: result, codeBlocks: codeBlocks, accentColor: accentColor)

    return result
}

// MARK: - 代码块提取与还原
private func extractCodeBlocks(_ markdown: String) -> (String, [(placeholder: String, code: String, lang: String)]) {
    var result = markdown
    var blocks: [(placeholder: String, code: String, lang: String)] = []
    let pattern = try! NSRegularExpression(pattern: "```([\\w]*)\n?([\\s\\S]*?)```", options: [])
    let ns = result as NSString
    let matches = pattern.matches(in: result, range: NSRange(location: 0, length: ns.length))
    for (i, match) in matches.enumerated() {
        let fullRange = Range(match.range, in: result)!
        let lang = match.range(at: 1).length > 0 ? String(result[Range(match.range(at: 1), in: result)!]) : ""
        let code = match.range(at: 2).length > 0 ? String(result[Range(match.range(at: 2), in: result)!]) : ""
        let placeholder = "⌘CODEBLOCK\(i)⌘"
        blocks.append((placeholder: placeholder, code: code.trimmingCharacters(in: .newlines), lang: lang))
        result.replaceSubrange(fullRange, with: "\n\(placeholder)\n")
    }
    return (result, blocks)
}

private func restoreCodeBlocks(in attr: NSMutableAttributedString, codeBlocks: [(placeholder: String, code: String, lang: String)], accentColor: NSColor) {
    for block in codeBlocks {
        let str = attr.string as NSString
        let range = str.range(of: block.placeholder)
        guard range.location != NSNotFound else { continue }

        // 代码块样式
        let codeFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let codeBg = NSColor.systemGray.withAlphaComponent(0.12)
        let codeColor = NSColor.labelColor

        let codeAttr = NSMutableAttributedString(string: block.code)
        let codeRange = NSRange(location: 0, length: codeAttr.length)
        codeAttr.addAttribute(.font, value: codeFont, range: codeRange)
        codeAttr.addAttribute(.foregroundColor, value: codeColor, range: codeRange)
        codeAttr.addAttribute(.backgroundColor, value: codeBg, range: codeRange)

        let blockPara = NSMutableParagraphStyle()
        blockPara.lineSpacing = 3
        blockPara.paragraphSpacing = 4
        blockPara.headIndent = 10
        blockPara.firstLineHeadIndent = 10
        blockPara.tailIndent = -10
        codeAttr.addAttribute(.paragraphStyle, value: blockPara, range: codeRange)

        // 包一层带背景的容器段
        let container = NSMutableAttributedString(string: "\n")
        container.append(codeAttr)
        container.append(NSAttributedString(string: "\n"))

        attr.replaceCharacters(in: range, with: container)
    }
}

// MARK: - 标题样式（扫描原始文本行）
private func applyHeadingStyles(to attr: NSMutableAttributedString, accentColor: NSColor) {
    let text = attr.string
    let lines = text.components(separatedBy: "\n")
    var pos = 0
    for line in lines {
        let lineLen = (line as NSString).length
        let lineRange = NSRange(location: pos, length: lineLen)
        if line.hasPrefix("# ") && lineLen > 2 {
            let contentRange = NSRange(location: pos + 2, length: lineLen - 2)
            attr.addAttribute(.font, value: NSFont.systemFont(ofSize: 18, weight: .bold), range: contentRange)
            attr.addAttribute(.foregroundColor, value: NSColor.labelColor, range: contentRange)
        } else if line.hasPrefix("## ") && lineLen > 3 {
            let contentRange = NSRange(location: pos + 3, length: lineLen - 3)
            attr.addAttribute(.font, value: NSFont.systemFont(ofSize: 15, weight: .semibold), range: contentRange)
            attr.addAttribute(.foregroundColor, value: accentColor, range: contentRange)
        } else if line.hasPrefix("### ") && lineLen > 4 {
            let contentRange = NSRange(location: pos + 4, length: lineLen - 4)
            attr.addAttribute(.font, value: NSFont.systemFont(ofSize: 13, weight: .medium), range: contentRange)
            attr.addAttribute(.foregroundColor, value: accentColor.withAlphaComponent(0.85), range: contentRange)
        } else if line.hasPrefix("> ") {
            let quoteStyle = NSMutableParagraphStyle()
            quoteStyle.headIndent = 12
            quoteStyle.firstLineHeadIndent = 12
            quoteStyle.lineSpacing = 3
            attr.addAttribute(.paragraphStyle, value: quoteStyle, range: lineRange)
            attr.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: lineRange)
            // 添加左边框效果：用特殊背景色
            attr.addAttribute(.backgroundColor, value: accentColor.withAlphaComponent(0.08), range: lineRange)
        }
        pos += lineLen + 1 // +1 for newline
    }
}

// MARK: - 内联代码样式（`code`）
private func applyInlineCodeStyles(to attr: NSMutableAttributedString) {
    let text = attr.string
    let pattern = try! NSRegularExpression(pattern: "`([^`\n]+)`", options: [])
    let matches = pattern.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    // 从后往前替换，避免 range 偏移
    for match in matches.reversed() {
        let fullRange = match.range
        let innerRange = match.range(at: 1)
        guard innerRange.location != NSNotFound else { continue }
        let innerText = (text as NSString).substring(with: innerRange)
        let codeAttr = NSMutableAttributedString(string: innerText)
        codeAttr.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: NSRange(location: 0, length: codeAttr.length))
        codeAttr.addAttribute(.backgroundColor, value: NSColor.systemGray.withAlphaComponent(0.15), range: NSRange(location: 0, length: codeAttr.length))
        codeAttr.addAttribute(.foregroundColor, value: NSColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1.0), range: NSRange(location: 0, length: codeAttr.length))
        attr.replaceCharacters(in: fullRange, with: codeAttr)
    }
}

// MARK: - 辅助视图
struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            content()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
