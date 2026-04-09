import Foundation

// MARK: - Memo Model
struct Memo: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), title: String = "新建备忘录", content: String = "", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// 从内容第一行提取标题
    var displayTitle: String {
        let firstLine = content.components(separatedBy: "\n").first ?? ""
        // 去掉 Markdown 标题符号
        let cleaned = firstLine
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
        return cleaned.isEmpty ? "无标题" : cleaned
    }
    
    var preview: String {
        let lines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let preview = lines.prefix(2).joined(separator: " ")
        return preview.isEmpty ? "暂无内容" : preview
    }
    
    static func == (lhs: Memo, rhs: Memo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Store (持久化，路径跟随 AppSettings)
final class MemoStore {
    static let shared = MemoStore()
    private init() {}

    private var fileURL: URL {
        // 动态读取，支持运行时切换存储目录
        let dir = AppSettings.shared.effectiveSaveURL
        return dir.appendingPathComponent("memos.json")
    }

    func load() -> [Memo] {
        guard let data = try? Data(contentsOf: fileURL),
              let memos = try? JSONDecoder().decode([Memo].self, from: data) else {
            // 尝试旧路径迁移
            return loadLegacy()
        }
        return memos
    }

    func save(_ memos: [Memo]) {
        guard let data = try? JSONEncoder().encode(memos) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 兼容旧路径（Application Support/MemoApp）
    private func loadLegacy() -> [Memo] {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let legacy = appSupport.appendingPathComponent("MemoApp/memos.json")
        guard let data = try? Data(contentsOf: legacy),
              let memos = try? JSONDecoder().decode([Memo].self, from: data) else { return [] }
        return memos
    }
}
