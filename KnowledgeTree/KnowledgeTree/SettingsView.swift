import SwiftUI
import AppKit

// MARK: - 偏好设置视图
struct SettingsView: View {
    @ObservedObject var store = KnowledgeStore.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem { Label("通用", systemImage: "gear") }
                .tag(0)

            StorageSettingsTab()
                .tabItem { Label("存储", systemImage: "folder") }
                .tag(1)

            AppearanceSettingsTab()
                .tabItem { Label("外观", systemImage: "paintbrush") }
                .tag(2)

            AboutTab()
                .tabItem { Label("关于", systemImage: "info.circle") }
                .tag(3)
        }
        .padding(20)
        .frame(width: 460, height: 340)
    }
}

// MARK: - 通用设置
struct GeneralSettingsTab: View {
    @ObservedObject var store = KnowledgeStore.shared

    var body: some View {
        Form {
            Section("自动保存") {
                Toggle("启用自动保存", isOn: Binding(
                    get: { store.preferences.autoSave },
                    set: { store.preferences.autoSave = $0; store.savePreferences() }
                ))

                if store.preferences.autoSave {
                    HStack {
                        Text("保存间隔")
                        Slider(
                            value: Binding(
                                get: { store.preferences.autoSaveInterval },
                                set: { store.preferences.autoSaveInterval = $0; store.savePreferences() }
                            ),
                            in: 1...30,
                            step: 1
                        )
                        Text("\(Int(store.preferences.autoSaveInterval)) 秒")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }
            }

            Section("交互") {
                Toggle("启用动画效果", isOn: Binding(
                    get: { store.preferences.animationsEnabled },
                    set: { store.preferences.animationsEnabled = $0; store.savePreferences() }
                ))

                HStack {
                    Text("默认展开深度")
                    Stepper(
                        "\(store.preferences.defaultExpandDepth) 层",
                        value: Binding(
                            get: { store.preferences.defaultExpandDepth },
                            set: { store.preferences.defaultExpandDepth = $0; store.savePreferences() }
                        ),
                        in: 1...10
                    )
                }

                Toggle("显示节点数量", isOn: Binding(
                    get: { store.preferences.showNodeCount },
                    set: { store.preferences.showNodeCount = $0; store.savePreferences() }
                ))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 存储设置
struct StorageSettingsTab: View {
    @ObservedObject var store = KnowledgeStore.shared
    @State private var showDirectoryPicker = false
    @State private var showImportPanel = false
    @State private var exportMessage = ""
    @State private var showExportSuccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // 存储目录
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label("知识库存储目录", systemImage: "folder.fill")
                        .font(.headline)

                    HStack {
                        Text(store.preferences.knowledgeDirectory)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("更改…") {
                            chooseDirectory()
                        }
                        .controlSize(.small)
                    }

                    HStack {
                        Button("在 Finder 中显示") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: store.preferences.knowledgeDirectory))
                        }
                        .controlSize(.small)
                        .buttonStyle(.link)

                        Spacer()

                        Button("恢复默认") {
                            store.updateDirectory(AppPreferences.defaultDirectory)
                        }
                        .controlSize(.small)
                        .buttonStyle(.link)
                    }
                }
                .padding(8)
            }

            // 文件统计
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("文件统计", systemImage: "chart.bar")
                        .font(.headline)

                    HStack(spacing: 20) {
                        VStack {
                            Text("\(store.trees.count)")
                                .font(.system(size: 24, weight: .bold))
                            Text("知识树").font(.caption).foregroundColor(.secondary)
                        }
                        Divider().frame(height: 40)
                        VStack {
                            Text("\(store.trees.reduce(0) { $0 + $1.root.totalCount })")
                                .font(.system(size: 24, weight: .bold))
                            Text("总节点").font(.caption).foregroundColor(.secondary)
                        }
                        Divider().frame(height: 40)
                        VStack {
                            Text(fileSizeString)
                                .font(.system(size: 24, weight: .bold))
                            Text("存储占用").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
            }

            // 导入/导出
            GroupBox {
                HStack(spacing: 12) {
                    Button("导出全部为 JSON") {
                        exportAll()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("重新加载文件") {
                        store.loadAllTrees()
                    }
                }
                .padding(4)
            }

            if showExportSuccess {
                Label(exportMessage, systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.callout)
            }

            Spacer()
        }
        .padding(4)
    }

    private var fileSizeString: String {
        let dir = URL(fileURLWithPath: store.preferences.knowledgeDirectory)
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return "0 KB" }
        let totalBytes = files.compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }.reduce(0, +)
        if totalBytes < 1024 { return "\(totalBytes) B" }
        if totalBytes < 1024 * 1024 { return "\(totalBytes / 1024) KB" }
        return "\(totalBytes / 1024 / 1024) MB"
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "选择知识库存储目录"
        panel.prompt = "选择此目录"

        if panel.runModal() == .OK, let url = panel.url {
            store.updateDirectory(url.path)
        }
    }

    private func exportAll() {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "knowledge_export_\(Date().timeIntervalSince1970.rounded()).json"
        savePanel.allowedContentTypes = [.json]
        if savePanel.runModal() == .OK, let url = savePanel.url {
            let exportData = store.trees.compactMap { store.exportTreeJSON($0.id) }
            let combined = "[\(exportData.joined(separator: ",\n"))]"
            try? combined.write(to: url, atomically: true, encoding: .utf8)
            exportMessage = "已导出到 \(url.lastPathComponent)"
            showExportSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showExportSuccess = false }
        }
    }
}

// MARK: - 外观设置
struct AppearanceSettingsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label("主题", systemImage: "circle.lefthalf.filled")
                        .font(.headline)
                    Text("应用跟随系统深色/浅色模式自动切换。")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label("节点颜色", systemImage: "paintpalette")
                        .font(.headline)

                    HStack(spacing: 8) {
                        ForEach(NSColor.nodeColors, id: \.hex) { item in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color(NSColor(hex: item.hex) ?? .systemBlue))
                                    .frame(width: 28, height: 28)
                                Text(item.name)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(8)
            }

            Spacer()
        }
        .padding(4)
    }
}

// MARK: - 关于
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 52))
                .foregroundColor(.accentColor)

            VStack(spacing: 4) {
                Text("KnowledgeTree")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("版本 1.0")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Text("个人知识树管理工具\n支持无限层级，本地 JSON 存储，配套 AI Skill 智能更新。")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Text("JSON 文件位置：~/Documents/KnowledgeTree/")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
