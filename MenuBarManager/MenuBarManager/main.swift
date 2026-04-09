import AppKit

// 纯菜单栏应用，不显示 Dock 图标
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
