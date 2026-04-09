import AppKit
import Foundation

// MARK: - 扫描当前运行中、具有菜单栏图标的应用
final class RunningAppsScanner {

    // 已知的"系统级"菜单栏图标的 Bundle ID 前缀，供参考识别
    private static let systemPrefixes = [
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.Spotlight",
        "com.apple.TextInputMenu",
        "com.apple.systemuiserver",
    ]

    /// 返回当前所有"激活策略为 .regular 或 .accessory"且在后台常驻的应用，
    /// 这些应用通常在菜单栏中有图标。
    static func scan() -> [ScannedApp] {
        var result: [ScannedApp] = []

        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            // 仅关注以下两种策略（accessory = 纯菜单栏应用；regular = 普通应用但可能有菜单栏项）
            guard app.activationPolicy == .accessory || app.activationPolicy == .regular else {
                continue
            }
            guard let bundleID = app.bundleIdentifier else { continue }
            // 过滤掉自身
            guard bundleID != Bundle.main.bundleIdentifier else { continue }
            // 过滤掉没有名称的
            guard let name = app.localizedName, !name.isEmpty else { continue }

            let icon = app.icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: name)
            result.append(ScannedApp(
                bundleIdentifier: bundleID,
                name: name,
                icon: icon,
                isAccessory: app.activationPolicy == .accessory
            ))
        }

        // 去重（同 bundleID 保留一条）
        var seen = Set<String>()
        result = result.filter { seen.insert($0.bundleIdentifier).inserted }

        return result.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

// MARK: - 扫描结果模型
struct ScannedApp: Identifiable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let icon: NSImage?
    let isAccessory: Bool  // true = 纯菜单栏 App（无 Dock 图标）
}
