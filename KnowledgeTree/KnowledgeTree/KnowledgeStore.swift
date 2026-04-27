import Foundation
import Combine
import AppKit

// MARK: - KnowledgeStore 数据中心（全局单例）
final class KnowledgeStore: ObservableObject {

    static let shared = KnowledgeStore()

    // MARK: - Published 状态
    @Published var trees: [KnowledgeTree] = []
    @Published var selectedTreeId: String?
    @Published var selectedNodeId: String?
    @Published var preferences: AppPreferences = .default
    @Published var isLoading = false
    @Published var errorMessage: String?

    // 新增节点动画状态: nodeId -> animationState
    @Published var nodeAnimations: [String: NodeAnimationState] = [:]

    // 搜索
    @Published var searchQuery: String = ""
    @Published var searchResults: [SearchResult] = []

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var autoSaveTimer: Timer?
    private var dirtyTreeIds: Set<String> = []
    private var cancellables = Set<AnyCancellable>()

    // 当前选中的树
    var selectedTree: KnowledgeTree? {
        trees.first { $0.id == selectedTreeId }
    }

    // 当前选中节点
    var selectedNode: KnowledgeNode? {
        guard let tree = selectedTree else { return nil }
        guard let nodeId = selectedNodeId else { return nil }
        return tree.root.findNode(id: nodeId)
    }

    private init() {
        loadPreferences()
        loadAllTrees()
        setupAutoSave()
        setupSearch()
    }

    // MARK: - 偏好设置

    private func loadPreferences() {
        let url = preferencesURL
        if let data = try? Data(contentsOf: url),
           let prefs = try? decoder.decode(AppPreferences.self, from: data) {
            preferences = prefs
        } else {
            preferences = .default
        }
        ensureDirectoryExists()
    }

    func savePreferences() {
        let url = preferencesURL
        if let data = try? encoder.encode(preferences) {
            try? data.write(to: url)
        }
        ensureDirectoryExists()
    }

    private var preferencesURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("KnowledgeTree")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("preferences.json")
    }

    func updateDirectory(_ newPath: String) {
        let oldPath = preferences.knowledgeDirectory
        preferences.knowledgeDirectory = newPath
        savePreferences()
        ensureDirectoryExists()

        // 如果目录变了，重新加载
        if oldPath != newPath {
            loadAllTrees()
        }
    }

    private func ensureDirectoryExists() {
        let url = URL(fileURLWithPath: preferences.knowledgeDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    // MARK: - 加载树

    func loadAllTrees() {
        isLoading = true
        let dir = URL(fileURLWithPath: preferences.knowledgeDirectory)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var loaded: [KnowledgeTree] = []

            if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for file in files.filter({ $0.pathExtension == "json" }) {
                    if let data = try? Data(contentsOf: file),
                       let tree = try? self.decoder.decode(KnowledgeTree.self, from: data) {
                        loaded.append(tree)
                    }
                }
            }

            // 如果没有任何树，创建示例
            if loaded.isEmpty {
                let sample = self.createSampleTree()
                loaded.append(sample)
                self.saveTree(sample)
            }

            loaded.sort { $0.updatedAt > $1.updatedAt }

            DispatchQueue.main.async {
                self.trees = loaded
                self.isLoading = false

                // 恢复上次选中
                if let lastId = self.preferences.lastOpenedTreeId,
                   self.trees.contains(where: { $0.id == lastId }) {
                    self.selectedTreeId = lastId
                } else {
                    self.selectedTreeId = self.trees.first?.id
                }
            }
        }
    }

    // MARK: - 保存树

    func saveTree(_ tree: KnowledgeTree) {
        let dir = URL(fileURLWithPath: preferences.knowledgeDirectory)
        let file = dir.appendingPathComponent(tree.fileName)
        if let data = try? encoder.encode(tree) {
            try? data.write(to: file)
        }
    }

    func markDirty(_ treeId: String) {
        dirtyTreeIds.insert(treeId)
    }

    private func setupAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: preferences.autoSaveInterval, repeats: true) { [weak self] _ in
            self?.flushDirty()
        }
    }

    private func flushDirty() {
        guard !dirtyTreeIds.isEmpty else { return }
        let ids = dirtyTreeIds
        dirtyTreeIds.removeAll()
        for id in ids {
            if let tree = trees.first(where: { $0.id == id }) {
                saveTree(tree)
            }
        }
    }

    // MARK: - 树 CRUD

    func createTree(name: String, description: String = "", themeColor: String = "#4A90D9") -> KnowledgeTree {
        let tree = KnowledgeTree(name: name, description: description, themeColor: themeColor)
        trees.append(tree)
        saveTree(tree)
        selectedTreeId = tree.id
        return tree
    }

    func deleteTree(_ treeId: String) {
        guard let tree = trees.first(where: { $0.id == treeId }) else { return }
        let dir = URL(fileURLWithPath: preferences.knowledgeDirectory)
        let file = dir.appendingPathComponent(tree.fileName)
        try? FileManager.default.removeItem(at: file)
        trees.removeAll { $0.id == treeId }
        if selectedTreeId == treeId {
            selectedTreeId = trees.first?.id
        }
    }

    func renameTree(_ treeId: String, newName: String) {
        guard let index = trees.firstIndex(where: { $0.id == treeId }) else { return }
        let old = trees[index]
        // 删除旧文件
        let dir = URL(fileURLWithPath: preferences.knowledgeDirectory)
        let oldFile = dir.appendingPathComponent(old.fileName)
        try? FileManager.default.removeItem(at: oldFile)
        // 更新
        trees[index].name = newName
        trees[index].root.title = newName
        trees[index].updatedAt = Date()
        saveTree(trees[index])
    }

    // MARK: - 节点 CRUD

    @discardableResult
    func addNode(
        to parentId: String,
        in treeId: String,
        title: String,
        content: String = "",
        tags: [String] = [],
        icon: String? = nil,
        color: String? = nil
    ) -> KnowledgeNode? {
        guard let idx = trees.firstIndex(where: { $0.id == treeId }) else { return nil }

        let newNode = KnowledgeNode(
            title: title,
            content: content,
            tags: tags,
            color: color,
            icon: icon
        )

        // 确保父节点展开
        trees[idx].root = trees[idx].root.updatingChild(with: parentId) { node in
            var n = node
            n.isExpanded = true
            return n
        }

        trees[idx].root = trees[idx].root.addingChild(newNode, toParentId: parentId)
        trees[idx].updatedAt = Date()
        markDirty(treeId)

        // 触发新增动画
        if preferences.animationsEnabled {
            triggerAnimation(for: newNode.id, state: .appearing)
        }

        // 自动选中新节点
        selectedNodeId = newNode.id

        return newNode
    }

    func updateNode(_ nodeId: String, in treeId: String, transform: (inout KnowledgeNode) -> Void) {
        guard let idx = trees.firstIndex(where: { $0.id == treeId }) else { return }

        trees[idx].root = trees[idx].root.updatingChild(with: nodeId) { node in
            var n = node
            transform(&n)
            n.updatedAt = Date()
            return n
        }
        trees[idx].updatedAt = Date()
        markDirty(treeId)

        if preferences.animationsEnabled {
            triggerAnimation(for: nodeId, state: .highlighting)
        }
    }

    func deleteNode(_ nodeId: String, in treeId: String) {
        guard let idx = trees.firstIndex(where: { $0.id == treeId }) else { return }
        // 不能删除根节点
        if trees[idx].root.id == nodeId { return }

        trees[idx].root = trees[idx].root.deletingChild(with: nodeId)
        trees[idx].updatedAt = Date()
        markDirty(treeId)

        if selectedNodeId == nodeId {
            selectedNodeId = nil
        }
    }

    func toggleExpand(_ nodeId: String, in treeId: String) {
        guard let idx = trees.firstIndex(where: { $0.id == treeId }) else { return }
        trees[idx].root = trees[idx].root.updatingChild(with: nodeId) { node in
            var n = node
            n.isExpanded = !n.isExpanded
            return n
        }
        markDirty(treeId)
    }

    // MARK: - 动画

    func triggerAnimation(for nodeId: String, state: NodeAnimationState) {
        nodeAnimations[nodeId] = state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.nodeAnimations[nodeId] = .idle
        }
    }

    // MARK: - 搜索

    private func setupSearch() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        var results: [SearchResult] = []
        for tree in trees {
            results.append(contentsOf: tree.root.search(query: query))
        }
        searchResults = results
    }

    // MARK: - 选中管理

    func selectTree(_ id: String) {
        selectedTreeId = id
        selectedNodeId = nil
        preferences.lastOpenedTreeId = id
        savePreferences()
    }

    func selectNode(_ id: String?) {
        selectedNodeId = id
    }

    // MARK: - JSON 导入导出（给 Skill 使用）

    /// 导出树为 JSON 字符串
    func exportTreeJSON(_ treeId: String) -> String? {
        guard let tree = trees.first(where: { $0.id == treeId }) else { return nil }
        guard let data = try? encoder.encode(tree) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 从外部 JSON 更新节点（Skill 调用）
    func importNodeUpdate(treeId: String, nodeId: String, updatedData: [String: Any]) -> Bool {
        guard let idx = trees.firstIndex(where: { $0.id == treeId }) else { return false }

        trees[idx].root = trees[idx].root.updatingChild(with: nodeId) { node in
            var n = node
            if let title = updatedData["title"] as? String { n.title = title }
            if let content = updatedData["content"] as? String { n.content = content }
            if let tags = updatedData["tags"] as? [String] { n.tags = tags }
            if let icon = updatedData["icon"] as? String { n.icon = icon }
            if let color = updatedData["color"] as? String { n.color = color }
            n.updatedAt = Date()
            return n
        }
        trees[idx].updatedAt = Date()
        markDirty(treeId)
        flushDirty()

        if preferences.animationsEnabled {
            triggerAnimation(for: nodeId, state: .highlighting)
        }
        return true
    }

    // MARK: - 示例数据

    private func createSampleTree() -> KnowledgeTree {
        let swiftNode = KnowledgeNode(
            title: "Swift",
            content: "Apple 的现代编程语言，用于 iOS/macOS 开发。\n\n- 类型安全\n- 高性能\n- 现代语法",
            tags: ["编程语言", "Apple"],
            color: "#FA8C16",
            icon: "swift",
            children: [
                KnowledgeNode(title: "语法基础", content: "变量、常量、控制流、函数...", tags: ["基础"], icon: "textformat"),
                KnowledgeNode(title: "SwiftUI", content: "声明式 UI 框架，跨 Apple 平台。", tags: ["UI", "框架"], color: "#4A90D9", icon: "rectangle.3.group"),
                KnowledgeNode(title: "Combine", content: "响应式编程框架，处理异步数据流。", tags: ["异步", "框架"], icon: "arrow.triangle.merge"),
            ]
        )

        let programmingNode = KnowledgeNode(
            title: "编程",
            content: "计算机编程相关知识体系",
            tags: ["技术"],
            color: "#4A90D9",
            icon: "laptopcomputer",
            children: [
                swiftNode,
                KnowledgeNode(
                    title: "Python",
                    content: "通用编程语言，广泛用于数据科学、AI、Web。",
                    tags: ["编程语言"],
                    color: "#52C41A",
                    icon: "terminal",
                    children: [
                        KnowledgeNode(title: "NumPy", content: "科学计算库", tags: ["数据科学"]),
                        KnowledgeNode(title: "FastAPI", content: "现代 Web 框架", tags: ["Web"]),
                    ]
                ),
            ],
            isExpanded: true
        )

        let root = KnowledgeNode(
            title: "我的知识树",
            content: "这是我的个人知识管理系统。\n\n点击节点查看详情，右键可添加/删除子节点。",
            tags: [],
            icon: "brain",
            children: [
                programmingNode,
                KnowledgeNode(
                    title: "设计",
                    content: "UI/UX 设计知识",
                    tags: ["设计"],
                    color: "#EB2F96",
                    icon: "pencil.and.ruler",
                    children: [
                        KnowledgeNode(title: "色彩理论", content: "色轮、对比度、配色方案", tags: ["基础"]),
                        KnowledgeNode(title: "字体设计", content: "衬线体、无衬线体、字号层级", tags: ["基础"]),
                    ]
                ),
                KnowledgeNode(
                    title: "读书笔记",
                    content: "书籍摘录与思考",
                    tags: ["读书"],
                    color: "#722ED1",
                    icon: "book",
                    children: []
                ),
            ],
            isExpanded: true
        )

        return KnowledgeTree(name: "我的知识树", description: "从这里开始构建你的知识体系", root: root, themeColor: "#4A90D9")
    }
}
