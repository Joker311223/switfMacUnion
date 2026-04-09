# CLAUDE.md — AI 协作规范

本文件为 AI（如 Claude / CatPaw）提供该仓库的开发约定，每次迭代后必须按本文件的要求同步更新文档。

---

## 仓库定位

这是一个 **macOS 桌面软件合集**，每个子目录是一款独立的 macOS 原生应用（Swift + AppKit）。

- `docs/index.html` 是整个合集的**官网**，向用户介绍所有应用的功能与使用方法。
- `README.md` 是面向开发者的**技术文档**，记录每款应用的功能、快捷键、构建方式等。
- 本文件（`CLAUDE.md`）是面向 AI 的**协作规范**。

---

## 每次迭代后必须执行的文档更新

> ⚠️ 无论功能大小，只要改动了用户可感知的行为，就必须同步更新以下两处。

### 1. 更新 `README.md`

按以下规则更新：

| 改动类型 | 需要更新的内容 |
|----------|----------------|
| 新增功能 | 在对应应用的「核心功能」表格中追加一行 |
| 新增快捷键 | 在「快捷键速查」表格中追加一行 |
| 新增偏好设置项 | 在「偏好设置面板」列表中追加描述 |
| 修复 Bug（用户可感知） | 无需改动，除非行为发生变化 |
| 新增应用 | 在「应用列表」章节新增一个完整的应用条目，格式参照 MemoApp |
| 删除功能 | 同步删除对应条目 |

### 2. 更新 `docs/index.html`

官网是单文件 React 应用，数据集中在文件顶部的常量数组里，按以下规则更新：

| 改动类型 | 需要更新的内容 |
|----------|----------------|
| 新增功能 | 在 `features` 数组中追加一项 `{ icon, title, desc, color }` |
| 新增快捷键 | 在 `shortcuts` 数组中追加一项 `{ keys, desc }` |
| 新增偏好设置项 | 在 `settings` 数组中找到对应 tab，在 `items` 里追加描述字符串 |
| 新增应用 | 在 Hero 区域的 MockAppWindow 和 Download 区域更新应用介绍，并在 features/shortcuts/settings 中加入该应用的数据 |
| 删除功能 | 同步删除对应数组项 |

---

## 应用开发规范

### 目录结构
```
AppName/
├── AppName/          # Swift 源码
│   ├── main.swift
│   ├── AppDelegate.swift
│   └── ...
└── Package.swift     # Swift Package Manager 配置
```

### 技术栈
- **语言**：Swift（最低 macOS 13）
- **UI 框架**：AppKit（不使用 SwiftUI）
- **构建工具**：Swift Package Manager（`swift build`）
- **持久化**：`UserDefaults`（设置项）+ JSON 文件（数据）
- **图标**：`AppIconMaker.swift` 用 Core Graphics 绘制，无需外部资源

### 代码约定
- 每个应用独立 `Package.swift`，不共享依赖
- 用 `NotificationCenter` 做跨组件通信，避免强引用循环
- 设置项统一用 `@Setting` 属性包装器 + `UserDefaults` 持久化
- 全局快捷键通过 `HotKeyManager`（Carbon HIToolbox）注册，启动时调用 `register()`，退出时调用 `unregister()`

---

## 文档更新示例

### 场景：MemoApp 新增「代码块语言高亮」功能

**README.md** — 在 MemoApp 核心功能表格末尾追加：
```markdown
| 代码块语言高亮 | 在代码块首行指定语言（如 ```swift），预览区自动着色 |
```

**website/index.html** — 在 `features` 数组末尾追加：
```js
{
  icon: "🌈",
  title: "代码块语言高亮",
  desc: "在代码块首行指定语言，预览区自动识别并着色，支持 Swift、Python、JavaScript 等常见语言。",
  color: "#06b6d4",
},
```

---

## 不需要更新文档的情况

- 纯内部重构（用户无感知的代码结构调整）
- Bug 修复（行为恢复到预期，未引入新特性）
- 性能优化（无 UI/功能变化）
- `.gitignore`、`Package.swift` 等配置文件变更
