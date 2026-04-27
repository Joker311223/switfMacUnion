import SwiftUI
import AppKit

// MARK: - 全局搜索浮层
struct SearchOverlay: View {
    @EnvironmentObject var store: KnowledgeStore
    @Binding var isVisible: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 搜索输入框
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))

                TextField("搜索知识节点、标签…", text: $store.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isFocused)
                    .onSubmit {
                        // 选中第一个结果
                        if let first = store.searchResults.first {
                            navigateToResult(first)
                        }
                    }

                if !store.searchQuery.isEmpty {
                    Button(action: { store.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    withAnimation(.spring()) {
                        isVisible = false
                        store.searchQuery = ""
                    }
                }) {
                    Text("Esc")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // 搜索结果列表
            if !store.searchQuery.isEmpty {
                if store.searchResults.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("未找到「\(store.searchQuery)」相关节点")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.searchResults) { result in
                                SearchResultRow(result: result, query: store.searchQuery) {
                                    navigateToResult(result)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 320)

                    Divider()
                    HStack {
                        Text("\(store.searchResults.count) 个结果")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            } else {
                // 无搜索词时展示最近操作提示
                VStack(spacing: 6) {
                    HStack {
                        Text("快捷搜索")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 16) {
                        SearchHintChip(icon: "tag", text: "按标签搜索")
                        SearchHintChip(icon: "textformat", text: "按标题搜索")
                        SearchHintChip(icon: "doc.text", text: "按内容搜索")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .padding(.top, 10)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: 6)
        .frame(maxWidth: 580)
        .padding(.horizontal, 40)
        .padding(.top, 8)
        .onAppear { isFocused = true }
    }

    private func navigateToResult(_ result: SearchResult) {
        // 找到该节点属于哪棵树
        for tree in store.trees {
            if tree.root.findNode(id: result.node.id) != nil {
                store.selectTree(tree.id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    store.selectNode(result.node.id)
                }
                break
            }
        }
        withAnimation(.spring()) {
            isVisible = false
            store.searchQuery = ""
        }
    }
}

// MARK: - 搜索结果行
struct SearchResultRow: View {
    let result: SearchResult
    let query: String
    var onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // 节点图标
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    if let icon = result.node.icon, !icon.isEmpty {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    } else {
                        Text(String(result.node.title.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HighlightedText(text: result.node.title, highlight: query)
                        .font(.system(size: 13, weight: .medium))

                    if !result.node.content.isEmpty {
                        Text(result.node.content.replacingOccurrences(of: "\n", with: " "))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // 匹配类型标签
                Text(matchTypeLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())

                // 标签
                HStack(spacing: 4) {
                    ForEach(result.node.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    var matchTypeLabel: String {
        switch result.matchType {
        case .title: return "标题"
        case .content: return "内容"
        case .tag: return "标签"
        }
    }
}

// MARK: - 高亮文本
struct HighlightedText: View {
    let text: String
    let highlight: String

    var body: some View {
        if highlight.isEmpty {
            Text(text)
        } else {
            buildHighlighted()
        }
    }

    private func buildHighlighted() -> some View {
        let parts = text.components(separatedBy: highlight)
        return parts.enumerated().reduce(Text("")) { acc, item in
            let (idx, part) = item
            if idx < parts.count - 1 {
                return acc + Text(part) + Text(highlight).foregroundColor(.orange).bold()
            }
            return acc + Text(part)
        }
    }
}

// MARK: - 搜索提示
struct SearchHintChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 11))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Capsule())
    }
}
