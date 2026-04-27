import AppKit
import SwiftUI

class MainWindowController: NSWindowController {

    private var store = KnowledgeStore.shared

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "KnowledgeTree"
        window.minSize = NSSize(width: 700, height: 500)
        window.titlebarAppearsTransparent = false
        window.center()

        let rootView = ContentView()
            .environmentObject(KnowledgeStore.shared)

        let hosting = NSHostingController(rootView: rootView)
        window.contentViewController = hosting

        self.init(window: window)
    }

    func showNewTreeSheet() {
        guard let window = window else { return }
        let sheet = NewTreeSheet { [weak self] name, description, color in
            guard !name.isEmpty else { return }
            KnowledgeStore.shared.createTree(name: name, description: description, themeColor: color)
            window.endSheet(window.sheets.first ?? window)
        } onCancel: {
            window.endSheet(window.sheets.first ?? window)
        }
        let hosting = NSHostingController(rootView: sheet)
        let sheetWindow = NSWindow(contentViewController: hosting)
        sheetWindow.setContentSize(NSSize(width: 400, height: 250))
        window.beginSheet(sheetWindow)
    }

    func expandAll() {
        // 通过 store 广播
        NotificationCenter.default.post(name: .expandAll, object: nil)
    }

    func collapseAll() {
        NotificationCenter.default.post(name: .collapseAll, object: nil)
    }
}

extension Notification.Name {
    static let expandAll = Notification.Name("expandAll")
    static let collapseAll = Notification.Name("collapseAll")
}
