# macOS Apps Collection

一个 macOS 桌面软件合集仓库，每款应用均以 Swift 原生开发，追求极简体验与高性能。

官网文档：https://joker311223.github.io/switfMacUnion/
---

## 应用列表

### 📝 MemoApp — 极简 Markdown 备忘录

> 专注写作的 macOS 备忘录，全局快捷键唤醒，实时 Markdown 预览。

**路径**：`MemoApp/`  
**要求**：macOS 13+，支持 Apple Silicon 与 Intel

#### 核心功能

| 功能 | 说明 |
|------|------|
| Markdown 实时预览 | 编辑区与预览区并排，输入即渲染，支持标题、代码块、表格、高亮等完整语法 |
| 全局快捷键唤醒 | 任意界面按 ⌃⌥Z 瞬间唤出最近备忘录 |
| 图片粘贴 | 截图后 ⌘V 直接粘贴，自动保存为本地文件并插入路径引用 |
| 超链接插入 | 选中文字后按 ⌘K，弹窗输入 URL，自动生成 Markdown 链接 |
| 自动 + 手动保存 | 输入后 0.5 秒自动保存，⌘S 手动保存，工具栏绿/红点实时指示状态 |
| 窗口置顶 | 一键钉住窗口，始终浮于最前 |
| 完全可定制外观 | 自定义各级标题、正文、链接、代码颜色，跟随系统深色/浅色模式 |
| 批量导出 | 一键导出全部备忘录为 Markdown 文件 |

#### 快捷键速查

| 快捷键 | 功能 |
|--------|------|
| `⌘S` | 手动保存 |
| `⌘N` | 新建备忘录 |
| `⌘K` | 插入超链接 |
| `⌘F` | 全文查找 |
| `⌘Z` | 撤销 |
| `⇧⌘Z` | 重做 |
| `⌃⌥Z` | 全局唤醒（任意界面生效） |
| `⌘W` | 关闭窗口 |

#### 偏好设置面板

- **通用**：启动行为、删除确认、字数统计显示
- **编辑器**：字体风格与字号、行间距、自动换行、Markdown 高亮、自动保存延迟
- **外观**：深色/浅色/跟随系统、预览字号、各级标题及正文颜色自定义
- **快捷键**：全局与编辑器快捷键速查
- **存储**：自定义存储目录、恢复默认路径
- **导出**：导出格式选择、批量导出

#### 构建方式

```bash
# 使用 Swift Package Manager 构建
cd MemoApp
swift build

# 运行
.build/debug/MemoApp
```

---

### ✂️ VideoClipper — 视频多段裁剪工具

> 可视化时间轴选区，多段裁剪后灵活导出：分别保存、拼接合并或两者兼得。

**路径**：`VideoClipper/`  
**要求**：macOS 13+，支持 Apple Silicon 与 Intel

#### 核心功能

| 功能 | 说明 |
|------|------|
| 可视化时间轴 | 缩略图帧预览 + 刻度标尺，直观展示视频内容 |
| 多段区间选择 | 在时间轴上拖拽创建多个裁剪片段，可任意增删调整 |
| 片段手柄拖拽 | 拖动片段边缘精确调整开始/结束时间，拖动主体移动整段 |
| 视频播放预览 | 内置播放器，支持播放/暂停、逐帧步进、倍速播放、音量调节 |
| 三种导出模式 | 分别保存各片段为独立文件 / 拼接为单一视频 / 两者都保存 |
| 拖拽打开视频 | 将视频文件直接拖入窗口即可加载，支持 mp4/mov/m4v/avi/mkv |
| 片段侧边栏 | 右侧展示所有片段列表，点击定位到对应区间 |

#### 快捷键速查

| 快捷键 | 功能 |
|--------|------|
| `⌘O` | 打开视频文件 |
| `⌘E` | 弹出导出选项面板 |
| `A` | 在当前播放位置添加 5 秒片段 |
| `Space` | 播放 / 暂停 |
| `←` | 后退一帧 |
| `→` | 前进一帧 |
| `Delete` | 删除选中片段 |

#### 构建方式

```bash
cd VideoClipper
swift build

# 运行
.build/debug/VideoClipper
```

---

## 项目结构

```
claudeProject/
├── MemoApp/                # MemoApp 源码
│   ├── MemoApp/
│   │   ├── main.swift
│   │   ├── AppDelegate.swift
│   │   ├── MainWindowController.swift
│   │   ├── SidebarView.swift
│   │   ├── MarkdownRenderer.swift
│   │   ├── AppSettings.swift
│   │   ├── HotKeyManager.swift
│   │   ├── AppIconMaker.swift
│   │   └── Models.swift
│   └── Package.swift
├── VideoClipper/           # VideoClipper 源码
│   ├── VideoClipper/
│   │   ├── main.swift
│   │   ├── AppDelegate.swift
│   │   └── ...
│   └── Package.swift
├── docs/                   # 官网静态页面
│   ├── index.html
│   ├── memoapp.html
│   └── videoclipper.html
├── README.md
└── CLAUDE.md
```

---

## 新增应用

每新增一款应用，请在此 README 的「应用列表」章节追加对应条目，格式参照 MemoApp 部分，并同步更新 `website/index.html`。详见 [CLAUDE.md](./CLAUDE.md)。
