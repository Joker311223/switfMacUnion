import AppKit
import Foundation

// MARK: - 单个菜单栏项目的数据模型
struct MenuBarItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var bundleIdentifier: String   // 应用 Bundle ID（如 com.apple.Spotlight）
    var appName: String            // 显示名称
    var isHidden: Bool             // 是否在菜单栏中隐藏
    var sortOrder: Int             // 排序权重（越小越靠前）
    var isPinned: Bool             // 是否置顶（钉住，不参与自动折叠）
    var lastSeen: Date             // 上次发现时间

    init(bundleIdentifier: String,
         appName: String,
         isHidden: Bool = false,
         sortOrder: Int = 100,
         isPinned: Bool = false) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.isHidden = isHidden
        self.sortOrder = sortOrder
        self.isPinned = isPinned
        self.lastSeen = Date()
    }
}

// MARK: - App 设置
final class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    // 菜单栏最大显示数量（超出则折叠到弹出菜单）
    var maxVisibleCount: Int {
        get { defaults.integer(forKey: "maxVisibleCount").nonZero ?? 8 }
        set { defaults.set(newValue, forKey: "maxVisibleCount") }
    }

    // 是否显示溢出指示器（「⋯」按钮）
    var showOverflowIndicator: Bool {
        get { defaults.bool(forKey: "showOverflowIndicator", defaultValue: true) }
        set { defaults.set(newValue, forKey: "showOverflowIndicator") }
    }

    // 是否开机自启
    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin", defaultValue: false) }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    // 是否在 Dock 中隐藏图标（纯菜单栏模式）
    var hideDockIcon: Bool {
        get { defaults.bool(forKey: "hideDockIcon", defaultValue: true) }
        set { defaults.set(newValue, forKey: "hideDockIcon") }
    }

    private init() {}
}

// MARK: - UserDefaults 扩展
extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil { return defaultValue }
        return bool(forKey: key)
    }
}

extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

// MARK: - 数据存储（本地 JSON）
final class DataStore {
    static let shared = DataStore()

    private let fileName = "MenuBarItems.json"
    private var fileURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("MenuBarManager")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent(fileName)
    }

    var items: [MenuBarItem] = []

    private init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([MenuBarItem].self, from: data)
        else { return }
        items = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL)
    }

    // 添加或更新一个 item
    func upsert(_ item: MenuBarItem) {
        if let idx = items.firstIndex(where: { $0.bundleIdentifier == item.bundleIdentifier }) {
            items[idx] = item
        } else {
            items.append(item)
        }
        save()
    }

    // 移除
    func remove(bundleIdentifier: String) {
        items.removeAll { $0.bundleIdentifier == bundleIdentifier }
        save()
    }
}
