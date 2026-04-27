import AppKit
import WebKit

// MARK: - 自定义置顶窗口
final class FloatingWindow: NSWindow {
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupFloating()
    }
    
    private func setupFloating() {
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = NSColor.windowBackgroundColor
        hasShadow = true
        isMovableByWindowBackground = false
    }
}

// MARK: - 工具栏视图
final class ToolbarView: NSView {
    
    var onClose: (() -> Void)?
    var onReload: (() -> Void)?
    var onTogglePin: ((Bool) -> Void)?
    var onZoomIn: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onResetZoom: (() -> Void)?
    var onOpacityChange: ((CGFloat) -> Void)?
    
    private var zoomLabel: NSButton!
    private var isPinned: Bool = true
    private var pinButton: NSButton!
    private var titleLabel: NSTextField!
    
    // 透明度区域
    private var opacityContainer: NSView!   // 右侧容器（图标 + 滑条）
    private var opacitySlider: NSSlider!
    private var opacityIcon: NSButton!       // 👁 图标按钮，点击切换展开/收起
    private var isOpacityExpanded: Bool = false
    private static let sliderWidth: CGFloat = 80
    private static let iconWidth: CGFloat = 32
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.95).cgColor
        
        // 关闭按钮
        let closeBtn = makeButton(title: "✕", color: NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1))
        closeBtn.target = self
        closeBtn.action = #selector(closeTapped)
        addSubview(closeBtn)
        
        // 刷新按钮
        let reloadBtn = makeButton(title: "↻", color: NSColor(white: 0.7, alpha: 1))
        reloadBtn.target = self
        reloadBtn.action = #selector(reloadTapped)
        addSubview(reloadBtn)
        
        // 缩小按钮
        let zoomOutBtn = makeButton(title: "－", color: NSColor(white: 0.7, alpha: 1))
        zoomOutBtn.target = self
        zoomOutBtn.action = #selector(zoomOutTapped)
        addSubview(zoomOutBtn)
        
        // 缩放比例按钮（点击重置）
        let resetBtn = makeButton(title: "100%", color: NSColor(white: 0.6, alpha: 1))
        resetBtn.target = self
        resetBtn.action = #selector(resetZoomTapped)
        resetBtn.frame = NSRect(x: 0, y: 0, width: 50, height: 28)
        zoomLabel = resetBtn
        addSubview(resetBtn)
        
        // 放大按钮
        let zoomInBtn = makeButton(title: "＋", color: NSColor(white: 0.7, alpha: 1))
        zoomInBtn.target = self
        zoomInBtn.action = #selector(zoomInTapped)
        addSubview(zoomInBtn)
        
        // 置顶按钮
        pinButton = makeButton(title: "📌", color: NSColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1))
        pinButton.target = self
        pinButton.action = #selector(pinTapped)
        addSubview(pinButton)
        
        // 标题
        titleLabel = NSTextField(labelWithString: "WebViewer")
        titleLabel.textColor = NSColor(white: 0.85, alpha: 1)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.alignment = .center
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        addSubview(titleLabel)
        
        // ---- 透明度控件 ----
        // 容器（clip 溢出，收起时只显示图标宽度）
        opacityContainer = NSView(frame: .zero)
        opacityContainer.wantsLayer = true
        opacityContainer.layer?.masksToBounds = true
        addSubview(opacityContainer)
        
        // 👁 图标（点击展开/收起滑条）
        opacityIcon = makeButton(title: "👁", color: NSColor(white: 0.75, alpha: 1))
        opacityIcon.target = self
        opacityIcon.action = #selector(toggleOpacitySlider)
        opacityIcon.frame = NSRect(x: 0, y: 0, width: Self.iconWidth, height: 28)
        opacityContainer.addSubview(opacityIcon)
        
        // 滑条（水平，0.2～1.0，默认 1.0）
        opacitySlider = NSSlider(value: 1.0, minValue: 0.2, maxValue: 1.0, target: self, action: #selector(opacitySliderChanged(_:)))
        opacitySlider.sliderType = .linear
        opacitySlider.controlSize = .small
        opacitySlider.frame = NSRect(x: Self.iconWidth, y: 0, width: Self.sliderWidth, height: 28)
        opacityContainer.addSubview(opacitySlider)
    }
    
    private func makeButton(title: String, color: NSColor) -> NSButton {
        let btn = NSButton(frame: NSRect(x: 0, y: 0, width: 32, height: 28))
        btn.title = title
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.font = NSFont.systemFont(ofSize: 13)
        btn.contentTintColor = color
        return btn
    }
    
    override func layout() {
        super.layout()
        let h = bounds.height
        let w = bounds.width
        
        // 右侧按钮组：从右向左排：透明度容器 → 置顶按钮
        let containerWidth = isOpacityExpanded
            ? (Self.iconWidth + Self.sliderWidth)
            : Self.iconWidth
        let containerX = w - CGFloat(containerWidth) - 4
        let containerY: CGFloat = (h - 28) / 2
        opacityContainer.frame = NSRect(x: containerX, y: containerY, width: CGFloat(containerWidth), height: 28)
        opacityIcon.frame = NSRect(x: 0, y: 0, width: Self.iconWidth, height: 28)
        opacitySlider.frame = NSRect(x: Self.iconWidth + 2, y: (28 - 16) / 2, width: Self.sliderWidth - 4, height: 16)

        let pinX = containerX - 32 - 4
        pinButton.frame = NSRect(x: pinX, y: (h - 28) / 2, width: 32, height: 28)
        
        // 左侧按钮从左向右排（跳过 pinButton 和 titleLabel）
        var x: CGFloat = 8
        for subview in subviews {
            guard let btn = subview as? NSButton,
                  btn != pinButton,
                  btn != opacityIcon else { continue }
            btn.frame = NSRect(x: x, y: (h - 28) / 2, width: btn.frame.width, height: 28)
            x += btn.frame.width + 4
        }
        
        // 标题居中
        titleLabel.frame = NSRect(x: w / 2 - 80, y: (h - 20) / 2, width: 160, height: 20)
    }
    
    // MARK: - Actions
    @objc private func closeTapped() { onClose?() }
    @objc private func reloadTapped() { onReload?() }
    @objc private func zoomInTapped() { onZoomIn?() }
    @objc private func zoomOutTapped() { onZoomOut?() }
    @objc private func resetZoomTapped() { onResetZoom?() }
    
    @objc private func pinTapped() {
        isPinned.toggle()
        pinButton.contentTintColor = isPinned
            ? NSColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1)
            : NSColor(white: 0.6, alpha: 1)
        onTogglePin?(isPinned)
    }
    
    @objc private func toggleOpacitySlider() {
        isOpacityExpanded.toggle()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            needsLayout = true
            layoutSubtreeIfNeeded()
        }
    }
    
    @objc private func opacitySliderChanged(_ sender: NSSlider) {
        onOpacityChange?(CGFloat(sender.doubleValue))
    }
    
    // MARK: - 公开更新接口
    func updatePinState(_ pinned: Bool) {
        isPinned = pinned
        pinButton.contentTintColor = pinned
            ? NSColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1)
            : NSColor(white: 0.6, alpha: 1)
    }
    
    func updateTitle(_ title: String) {
        titleLabel.stringValue = title.isEmpty ? "WebViewer" : title
    }
    
    func updateZoomLabel(_ zoom: CGFloat) {
        let pct = Int(zoom * 100)
        zoomLabel.title = "\(pct)%"
    }
    
    func updateOpacitySlider(_ opacity: CGFloat) {
        opacitySlider.doubleValue = Double(opacity)
    }
    
    // MARK: - 拖拽：点在按钮/滑条上则走正常事件，否则拖拽窗口
    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        
        // 检查是否命中按钮或透明度容器内的控件
        let hitInteractive = subviews.contains { view in
            if view == opacityContainer {
                // 把点转到容器坐标，再检查容器内子控件
                let pt = opacityContainer.convert(event.locationInWindow, from: nil)
                return opacityContainer.subviews.contains { $0.frame.contains(pt) }
            }
            return (view is NSButton) && view.frame.contains(localPoint)
        }
        
        if hitInteractive {
            super.mouseDown(with: event)
        } else {
            window?.performDrag(with: event)
        }
    }
}

// MARK: - 主窗口控制器
final class WebWindowController: NSWindowController {
    
    private var webView: WKWebView!
    private var toolbarView: ToolbarView!
    private var currentZoom: CGFloat = 1.0
    private let targetURL = URL(string: "https://km.sankuai.com/xtable/2604948081?table=2604939125")!
    
    init() {
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let windowWidth: CGFloat = 900
        let windowHeight: CGFloat = 680
        let windowX = screenRect.maxX - windowWidth - 20
        let windowY = screenRect.maxY - windowHeight - 20
        
        let window = FloatingWindow(
            contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        setupWindow()
        setupContent()
        loadURL()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        window.title = "WebViewer"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.minSize = NSSize(width: 400, height: 300)
        window.appearance = NSAppearance(named: .darkAqua)
    }
    
    private func setupContent() {
        guard let window = window else { return }
        
        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        
        let toolbarHeight: CGFloat = 36
        let toolbarFrame = NSRect(x: 0, y: contentView.bounds.height - toolbarHeight,
                                   width: contentView.bounds.width, height: toolbarHeight)
        toolbarView = ToolbarView(frame: toolbarFrame)
        toolbarView.autoresizingMask = [.width, .minYMargin]
        
        toolbarView.onClose = { [weak self] in self?.window?.orderOut(nil) }
        toolbarView.onReload = { [weak self] in self?.reload() }
        toolbarView.onZoomIn = { [weak self] in self?.adjustZoom(delta: 0.1) }
        toolbarView.onZoomOut = { [weak self] in self?.adjustZoom(delta: -0.1) }
        toolbarView.onResetZoom = { [weak self] in self?.resetZoom() }
        toolbarView.onTogglePin = { [weak self] pinned in self?.setPinned(pinned) }
        toolbarView.onOpacityChange = { [weak self] opacity in self?.setOpacity(opacity) }
        toolbarView.updatePinState(true)
        
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        let webViewFrame = NSRect(x: 0, y: 0,
                                   width: contentView.bounds.width,
                                   height: contentView.bounds.height - toolbarHeight)
        webView = WKWebView(frame: webViewFrame, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.allowsLinkPreview = true
        webView.allowsBackForwardNavigationGestures = true
        
        contentView.addSubview(webView)
        contentView.addSubview(toolbarView)
        window.contentView = contentView
    }
    
    func loadURL() {
        webView.load(URLRequest(url: targetURL))
    }
    
    func reload() {
        if webView.url != nil { webView.reload() } else { loadURL() }
    }
    
    // MARK: - 缩放（等价于 Chrome Cmd+/-）
    private func adjustZoom(delta: CGFloat) {
        currentZoom = (max(0.25, min(4.0, currentZoom + delta)) * 100).rounded() / 100
        applyZoom()
    }
    
    private func resetZoom() {
        currentZoom = 1.0
        applyZoom()
    }
    
    private func applyZoom() {
        // 使用 CSS transform: scale() 而不是 pageZoom：
        // pageZoom 会降低渲染分辨率导致模糊；
        // transform: scale() 始终以全分辨率渲染页面，再通过 GPU 缩放，清晰度不变（同 Chrome 逻辑）。
        // 同时用 transform-origin: top left + 调整容器尺寸，让缩小后内容从左上角对齐，
        // 并撑开滚动区域，使缩小时不会出现空白。
        let scale = currentZoom
        let js = """
        (function() {
            var s = \(scale);
            var el = document.documentElement;
            el.style.transformOrigin = '0 0';
            el.style.transform = 'scale(' + s + ')';
            // 反向撑大容器，让 scrollWidth/scrollHeight 与原始内容对齐
            el.style.width  = (100 / s) + '%';
            el.style.height = (100 / s) + '%';
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
        toolbarView.updateZoomLabel(currentZoom)
    }
    
    // MARK: - 置顶切换
    private func setPinned(_ pinned: Bool) {
        if pinned {
            window?.level = .floating
            window?.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        } else {
            window?.level = .normal
            window?.collectionBehavior = [.managed]
        }
    }
    
    // MARK: - 透明度调节（0.2 ～ 1.0）
    private func setOpacity(_ opacity: CGFloat) {
        window?.alphaValue = opacity
    }
}

// MARK: - WKNavigationDelegate
extension WebWindowController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let title = webView.title, !title.isEmpty {
            toolbarView.updateTitle(title)
        }
        // 页面加载完成后重新应用缩放（刷新/跳转后 DOM 重置，需重注入）
        if currentZoom != 1.0 {
            applyZoom()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("导航失败: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
