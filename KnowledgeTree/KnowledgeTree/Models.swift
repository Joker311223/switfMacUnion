import Foundation
import AppKit

// MARK: - KnowledgeNode 知识节点

/// 知识节点 - 支持无限层级嵌套
/// JSON 文件结构说明:
/// 每个 .json 文件代表一棵知识树的根节点，文件名即为树名
/// 文件存放在用户配置的目录下
struct KnowledgeNode: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var content: String          // 正文/描述（Markdown）
    var tags: [String]           // 标签
    var color: String?           // 节点颜色 hex（可选，nil 使用继承色）
    var icon: String?            // SF Symbol 名称（可选）
    var children: [KnowledgeNode]
    var createdAt: Date
    var updatedAt: Date
    var isExpanded: Bool         // UI 状态：是否展开（保存到文件）
    var metadata: [String: String]  // 扩展字段，key-value 自由存储

    init(
        id: String = UUID().uuidString,
        title: String,
        content: String = "",
        tags: [String] = [],
        color: String? = nil,
        icon: String? = nil,
        children: [KnowledgeNode] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isExpanded: Bool = true,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.color = color
        self.icon = icon
        self.children = children
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isExpanded = isExpanded
        self.metadata = metadata
    }

    /// 深度克隆，修改节点
    func updatingChild(with id: String, using transform: (KnowledgeNode) -> KnowledgeNode) -> KnowledgeNode {
        if self.id == id {
            return transform(self)
        }
        var copy = self
        copy.children = copy.children.map { $0.updatingChild(with: id, using: transform) }
        return copy
    }

    /// 删除节点
    func deletingChild(with id: String) -> KnowledgeNode {
        var copy = self
        copy.children = copy.children
            .filter { $0.id != id }
            .map { $0.deletingChild(with: id) }
        return copy
    }

    /// 在指定父节点下添加子节点
    func addingChild(_ child: KnowledgeNode, toParentId: String) -> KnowledgeNode {
        if self.id == toParentId {
            var copy = self
            copy.children.append(child)
            copy.updatedAt = Date()
            return copy
        }
        var copy = self
        copy.children = copy.children.map { $0.addingChild(child, toParentId: toParentId) }
        return copy
    }

    /// 查找节点
    func findNode(id: String) -> KnowledgeNode? {
        if self.id == id { return self }
        for child in children {
            if let found = child.findNode(id: id) { return found }
        }
        return nil
    }

    /// 全文搜索
    func search(query: String) -> [SearchResult] {
        var results: [SearchResult] = []
        let lowQuery = query.lowercased()

        if title.lowercased().contains(lowQuery) || content.lowercased().contains(lowQuery) ||
           tags.contains(where: { $0.lowercased().contains(lowQuery) }) {
            results.append(SearchResult(node: self, matchType: title.lowercased().contains(lowQuery) ? .title : .content))
        }
        for child in children {
            results.append(contentsOf: child.search(query: query))
        }
        return results
    }

    /// 节点总数
    var totalCount: Int {
        1 + children.reduce(0) { $0 + $1.totalCount }
    }

    /// 最大深度
    var maxDepth: Int {
        if children.isEmpty { return 0 }
        return 1 + (children.map { $0.maxDepth }.max() ?? 0)
    }
}

// MARK: - 知识树文件 (一个 JSON 文件 = 一棵树)
struct KnowledgeTree: Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var root: KnowledgeNode
    var createdAt: Date
    var updatedAt: Date
    var version: String          // 版本号，用于兼容性
    var themeColor: String       // 主题色 hex

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        root: KnowledgeNode? = nil,
        themeColor: String = "#4A90D9"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.root = root ?? KnowledgeNode(id: UUID().uuidString, title: name, icon: "brain")
        self.createdAt = Date()
        self.updatedAt = Date()
        self.version = "1.0"
        self.themeColor = themeColor
    }

    /// 文件名（去掉 .json）
    var fileName: String { "\(name).json" }
}

// MARK: - 搜索结果
struct SearchResult: Identifiable {
    var id: String { node.id }
    let node: KnowledgeNode
    let matchType: MatchType

    enum MatchType {
        case title, content, tag
    }
}

// MARK: - 新增节点动画状态
enum NodeAnimationState {
    case idle
    case appearing       // 新增动画
    case highlighting    // 高亮闪烁
    case disappearing    // 删除动画
}

// MARK: - 应用设置
struct AppPreferences: Codable {
    var knowledgeDirectory: String
    var lastOpenedTreeId: String?
    var sidebarWidth: Double
    var showNodeCount: Bool
    var autoSave: Bool
    var autoSaveInterval: Double  // 秒
    var animationsEnabled: Bool
    var defaultExpandDepth: Int   // 默认展开深度

    static let `default` = AppPreferences(
        knowledgeDirectory: defaultDirectory,
        lastOpenedTreeId: nil,
        sidebarWidth: 260,
        showNodeCount: true,
        autoSave: true,
        autoSaveInterval: 2.0,
        animationsEnabled: true,
        defaultExpandDepth: 2
    )

    static var defaultDirectory: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("KnowledgeTree").path
    }
}

// MARK: - 颜色预设
extension NSColor {
    static let nodeColors: [(name: String, hex: String)] = [
        ("蓝色", "#4A90D9"),
        ("绿色", "#52C41A"),
        ("橙色", "#FA8C16"),
        ("紫色", "#722ED1"),
        ("红色", "#F5222D"),
        ("青色", "#13C2C2"),
        ("粉色", "#EB2F96"),
        ("灰色", "#8C8C8C"),
    ]

    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    var hexString: String {
        guard let color = usingColorSpace(.sRGB) else { return "#4A90D9" }
        let r = Int(color.redComponent * 255)
        let g = Int(color.greenComponent * 255)
        let b = Int(color.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
