import SwiftUI
import AppKit

// MARK: - 主内容视图（三栏布局：侧边树列表 | 知识树 | 节点详情）
struct ContentView: View {
    @EnvironmentObject var store: KnowledgeStore
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showSearch = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 左侧：知识树列表 + 搜索
            SidebarTreeListView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } content: {
            // 中间：知识树可视化
            if let treeId = store.selectedTreeId,
               let tree = store.trees.first(where: { $0.id == treeId }) {
                KnowledgeTreeView(tree: tree)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 480, max: 700)
            } else {
                EmptyStateView()
                    .navigationSplitViewColumnWidth(min: 300, ideal: 480, max: 700)
            }
        } detail: {
            // 右侧：节点详情/编辑
            if store.selectedNodeId != nil {
                NodeDetailView()
                    .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 480)
            } else {
                NodePlaceholderView()
                    .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 480)
            }
        }
        .overlay(alignment: .top) {
            if showSearch {
                SearchOverlay(isVisible: $showSearch)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { withAnimation(.spring()) { showSearch.toggle() } }) {
                    Image(systemName: "magnifyingglass")
                }
                .help("搜索知识节点 (⌘F)")
                .keyboardShortcut("f", modifiers: .command)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.selectedTreeId)
        .animation(.easeInOut(duration: 0.25), value: store.selectedNodeId)
    }
}

// MARK: - 左侧边栏：知识树列表
struct SidebarTreeListView: View {
    @EnvironmentObject var store: KnowledgeStore
    @State private var showNewTreeSheet = false
    @State private var editingTreeId: String?
    @State private var editingName = ""

    var body: some View {
        List(selection: Binding(
            get: { store.selectedTreeId },
            set: { if let id = $0 { store.selectTree(id) } }
        )) {
            ForEach(store.trees) { tree in
                HStack(spacing: 8) {
                    // 颜色标记
                    Circle()
                        .fill(Color(NSColor(hex: tree.themeColor) ?? .systemBlue))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        if editingTreeId == tree.id {
                            TextField("树名称", text: $editingName, onCommit: {
                                store.renameTree(tree.id, newName: editingName)
                                editingTreeId = nil
                            })
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                        } else {
                            Text(tree.name)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                        }

                        if store.preferences.showNodeCount {
                            Text("\(tree.root.totalCount) 个节点")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 2)
                .tag(tree.id)
                .contextMenu {
                    Button("重命名") {
                        editingTreeId = tree.id
                        editingName = tree.name
                    }
                    Divider()
                    Button("删除知识树", role: .destructive) {
                        store.deleteTree(tree.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("知识树")
        .safeAreaInset(edge: .bottom) {
            Button(action: { showNewTreeSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("新建知识树")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showNewTreeSheet) {
            NewTreeSheet { name, description, color in
                guard !name.isEmpty else { return }
                store.createTree(name: name, description: description, themeColor: color)
                showNewTreeSheet = false
            } onCancel: {
                showNewTreeSheet = false
            }
        }
    }
}

// MARK: - 新建树弹窗
struct NewTreeSheet: View {
    var onConfirm: (String, String, String) -> Void
    var onCancel: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var selectedColor = "#4A90D9"

    let colorPresets: [(String, String)] = [
        ("蓝", "#4A90D9"), ("绿", "#52C41A"), ("橙", "#FA8C16"),
        ("紫", "#722ED1"), ("红", "#F5222D"), ("粉", "#EB2F96"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建知识树")
                .font(.headline)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("名称").font(.caption).foregroundColor(.secondary)
                TextField("例如：编程技术", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("描述（可选）").font(.caption).foregroundColor(.secondary)
                TextField("简短描述这棵知识树的主题", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("主题色").font(.caption).foregroundColor(.secondary)
                HStack(spacing: 10) {
                    ForEach(colorPresets, id: \.0) { label, hex in
                        Button(action: { selectedColor = hex }) {
                            ZStack {
                                Circle()
                                    .fill(Color(NSColor(hex: hex) ?? .systemBlue))
                                    .frame(width: 28, height: 28)
                                if selectedColor == hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(label)
                    }
                }
            }

            Spacer()

            HStack {
                Button("取消") { onCancel() }
                Spacer()
                Button("创建") { onConfirm(name, description, selectedColor) }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380, height: 240)
    }
}

// MARK: - 空状态视图
struct EmptyStateView: View {
    @EnvironmentObject var store: KnowledgeStore

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            Text("没有选中的知识树")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("从左侧选择一棵知识树，或创建新的知识树")
                .font(.body)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 节点占位符
struct NodePlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.tap")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))
            Text("选择节点查看详情")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
