import SwiftUI
import AppKit

// MARK: - 节点布局信息（计算后存储位置）
struct NodeLayout: Identifiable {
    let id: String
    let node: KnowledgeNode
    var position: CGPoint        // 画布坐标（中心点）
    var size: CGSize             // 节点卡片尺寸
    var depth: Int
    var angle: CGFloat           // 相对父节点的角度（用于布局参考）
    var parentId: String?

    var frame: CGRect {
        CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

// MARK: - 布局引擎
final class MindMapLayout {

    // 节点尺寸估算
    static func nodeSize(for node: KnowledgeNode, depth: Int) -> CGSize {
        let titleLen = CGFloat(node.title.count)
        let baseW = max(60, min(160, titleLen * 13 + 24))
        let h: CGFloat = node.tags.isEmpty ? 30 : 44
        return CGSize(width: baseW, height: h)
    }

    // 每层的连线半径
    static func radius(for depth: Int) -> CGFloat {
        switch depth {
        case 0: return 0
        case 1: return 180
        case 2: return 320
        case 3: return 460
        default: return CGFloat(depth) * 160 + 100
        }
    }

    // 计算全部节点的布局位置
    // center: 根节点在画布中的坐标
    static func compute(root: KnowledgeNode, center: CGPoint) -> [NodeLayout] {
        var result: [NodeLayout] = []
        let rootSize = nodeSize(for: root, depth: 0)
        let rootLayout = NodeLayout(
            id: root.id,
            node: root,
            position: center,
            size: rootSize,
            depth: 0,
            angle: 0,
            parentId: nil
        )
        result.append(rootLayout)

        if root.isExpanded {
            let children = root.children
            guard !children.isEmpty else { return result }
            // 根节点子节点均匀分布 360°
            let sectorAngle = (2 * CGFloat.pi) / CGFloat(children.count)
            for (i, child) in children.enumerated() {
                // 从顶部开始，顺时针
                let startAngle: CGFloat = -.pi / 2
                let angle = startAngle + sectorAngle * CGFloat(i)
                let r = radius(for: 1)
                let pos = CGPoint(
                    x: center.x + cos(angle) * r,
                    y: center.y + sin(angle) * r
                )
                let sub = computeSubtree(
                    node: child,
                    depth: 1,
                    centerAngle: angle,
                    sectorAngle: sectorAngle,
                    parentPos: center,
                    pos: pos,
                    parentId: root.id,
                    result: &result
                )
                _ = sub
            }
        }
        return result
    }

    @discardableResult
    private static func computeSubtree(
        node: KnowledgeNode,
        depth: Int,
        centerAngle: CGFloat,
        sectorAngle: CGFloat,
        parentPos: CGPoint,
        pos: CGPoint,
        parentId: String,
        result: inout [NodeLayout]
    ) -> NodeLayout {
        let size = nodeSize(for: node, depth: depth)
        let layout = NodeLayout(
            id: node.id,
            node: node,
            position: pos,
            size: size,
            depth: depth,
            angle: centerAngle,
            parentId: parentId
        )
        result.append(layout)

        guard node.isExpanded, !node.children.isEmpty else { return layout }

        let children = node.children
        let count = children.count

        // 子节点在父方向上展开一个扇区，扇区角度随深度收窄
        let fanAngle: CGFloat = min(sectorAngle * 0.85, CGFloat.pi * 1.0)
        let childSector: CGFloat = count > 1 ? fanAngle / CGFloat(count - 1) : 0
        let startAngle = centerAngle - fanAngle / 2

        let r = radius(for: depth + 1) - radius(for: depth)

        for (i, child) in children.enumerated() {
            let childAngle = count > 1 ? startAngle + childSector * CGFloat(i) : centerAngle
            let childPos = CGPoint(
                x: pos.x + cos(childAngle) * r,
                y: pos.y + sin(childAngle) * r
            )
            computeSubtree(
                node: child,
                depth: depth + 1,
                centerAngle: childAngle,
                sectorAngle: childSector > 0 ? childSector : CGFloat.pi / 4,
                parentPos: pos,
                pos: childPos,
                parentId: node.id,
                result: &result
            )
        }
        return layout
    }

    // 计算所有节点的包围盒，用于确定画布大小
    static func boundingRect(of layouts: [NodeLayout]) -> CGRect {
        guard !layouts.isEmpty else { return CGRect(x: 0, y: 0, width: 800, height: 600) }
        let minX = layouts.map { $0.frame.minX }.min()! - 60
        let minY = layouts.map { $0.frame.minY }.min()! - 60
        let maxX = layouts.map { $0.frame.maxX }.max()! + 60
        let maxY = layouts.map { $0.frame.maxY }.max()! + 60
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - 知识树主视图（放射状思维导图）
struct KnowledgeTreeView: View {
    @EnvironmentObject var store: KnowledgeStore
    let tree: KnowledgeTree

    // 画布变换（offset 是画布中心相对视口中心的偏移）
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    // 弹窗
    @State private var showAddNodeSheet = false
    @State private var addNodeParentId: String = ""

    // 布局缓存
    @State private var layouts: [NodeLayout] = []
    @State private var canvasSize: CGSize = CGSize(width: 2400, height: 2000)

    var themeColor: Color {
        Color(NSColor(hex: tree.themeColor) ?? .systemBlue)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景
                CanvasBackgroundView()

                // 底层交互捕获层（最先渲染，z-order 最低）
                // 负责接收拖拽和滚轮，不遮挡节点点击
                CanvasInteractionView(scale: $scale, offset: $offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 画布内容（连线 + 节点）
                ZStack(alignment: .topLeading) {
                    // 连线层
                    Canvas { ctx, size in
                        drawEdges(ctx: ctx, layouts: layouts)
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .allowsHitTesting(false)

                    // 节点层
                    ForEach(layouts) { layout in
                        MindMapNodeView(
                            layout: layout,
                            treeId: tree.id,
                            themeColor: themeColor,
                            isSelected: store.selectedNodeId == layout.id,
                            animState: store.nodeAnimations[layout.id] ?? .idle,
                            onTap: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    store.selectNode(layout.id)
                                }
                            },
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    store.toggleExpand(layout.id, in: tree.id)
                                }
                            },
                            onAddChild: {
                                addNodeParentId = layout.id
                                showAddNodeSheet = true
                            }
                        )
                        .position(layout.position)
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .scaleEffect(scale)
                .offset(offset)
                // 节点本身不拦截背景拖拽：让空白区域可以拖动
                .allowsHitTesting(true)
            }
            .clipped()
            // 控制栏
            .overlay(alignment: .bottomTrailing) {
                MindMapControlBar(
                    scale: $scale,
                    onReset: { resetView(geo: geo) },
                    onFit: { fitToScreen(geo: geo) }
                )
                .padding(16)
            }
            .overlay(alignment: .topTrailing) {
                TreeStatsView(tree: tree, themeColor: themeColor)
                    .padding(12)
            }
            .onAppear {
                recomputeLayout(geo: geo)
            }
            .onChange(of: tree.root) { _ in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    recomputeLayout(geo: geo)
                }
            }
        }
        .sheet(isPresented: $showAddNodeSheet) {
            AddNodeSheet(parentId: addNodeParentId, treeId: tree.id) {
                showAddNodeSheet = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .expandAll)) { _ in
            expandCollapseAll(expand: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .collapseAll)) { _ in
            expandCollapseAll(expand: false)
        }
        .navigationTitle(tree.name)
    }

    // MARK: - 布局计算

    private func recomputeLayout(geo: GeometryProxy) {
        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
        let computed = MindMapLayout.compute(root: tree.root, center: center)
        let bounds = MindMapLayout.boundingRect(of: computed)

        // 画布至少覆盖视口
        let w = max(geo.size.width, bounds.width + abs(bounds.minX) * 2)
        let h = max(geo.size.height, bounds.height + abs(bounds.minY) * 2)
        canvasSize = CGSize(width: w, height: h)
        layouts = computed
    }

    private func resetView(geo: GeometryProxy) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            scale = 1.0
            offset = .zero
        }
    }

    private func fitToScreen(geo: GeometryProxy) {
        guard !layouts.isEmpty else { return }
        let bounds = MindMapLayout.boundingRect(of: layouts)
        let scaleX = geo.size.width / bounds.width
        let scaleY = geo.size.height / bounds.height
        let newScale = min(scaleX, scaleY, 1.5) * 0.9
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            scale = newScale
            offset = .zero
        }
    }

    // MARK: - 连线绘制（Canvas）

    private func drawEdges(ctx: GraphicsContext, layouts: [NodeLayout]) {
        let layoutMap = Dictionary(uniqueKeysWithValues: layouts.map { ($0.id, $0) })

        for layout in layouts {
            guard let parentId = layout.parentId,
                  let parentLayout = layoutMap[parentId] else { continue }

            let from = parentLayout.position
            let to = layout.position

            // 贝塞尔曲线连线
            var path = Path()
            path.move(to: from)

            let ctrlOffset = CGPoint(
                x: (to.x - from.x) * 0.5,
                y: (to.y - from.y) * 0.5
            )
            let ctrl1 = CGPoint(x: from.x + ctrlOffset.x * 0.6, y: from.y + ctrlOffset.y * 0.3)
            let ctrl2 = CGPoint(x: to.x - ctrlOffset.x * 0.6, y: to.y - ctrlOffset.y * 0.3)
            path.addCurve(to: to, control1: ctrl1, control2: ctrl2)

            // 根据深度调整线宽和透明度
            let lineWidth: CGFloat = layout.depth == 1 ? 2.0 : (layout.depth == 2 ? 1.5 : 1.0)
            let alpha: Double = layout.depth == 1 ? 0.55 : (layout.depth == 2 ? 0.4 : 0.28)

            // 用节点颜色（如果有）或主题色
            let edgeColor: Color
            if let hex = layout.node.color, let c = NSColor(hex: hex) {
                edgeColor = Color(c).opacity(alpha)
            } else {
                edgeColor = themeColor.opacity(alpha)
            }

            ctx.stroke(
                path,
                with: .color(edgeColor),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    // MARK: - 展开/折叠

    private func expandCollapseAll(expand: Bool) {
        guard let idx = store.trees.firstIndex(where: { $0.id == tree.id }) else { return }
        store.trees[idx].root = setAllExpanded(store.trees[idx].root, expanded: expand)
        store.markDirty(tree.id)
    }

    private func setAllExpanded(_ node: KnowledgeNode, expanded: Bool) -> KnowledgeNode {
        var n = node
        n.isExpanded = expanded
        n.children = n.children.map { setAllExpanded($0, expanded: expanded) }
        return n
    }
}

// MARK: - 画布交互层（统一处理拖拽 + 滚轮缩放）
// 放在 ZStack 最底层，透明但能接收鼠标事件
struct CanvasInteractionView: NSViewRepresentable {
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    func makeNSView(context: Context) -> CanvasInteractNSView {
        let v = CanvasInteractNSView()
        v.onDrag = { dx, dy in
            offset.width += dx
            offset.height += dy
        }
        v.onScroll = { deltaY in
            // 触控板向上滑（双指拉开）= deltaY > 0 = 放大
            let factor: CGFloat = deltaY > 0 ? 1.06 : 0.94
            scale = (scale * factor).clamped(to: 0.15...4.0)
        }
        return v
    }

    func updateNSView(_ nsView: CanvasInteractNSView, context: Context) {}
}

class CanvasInteractNSView: NSView {
    var onDrag: ((CGFloat, CGFloat) -> Void)?
    var onScroll: ((CGFloat) -> Void)?

    private var lastDragLocation: NSPoint?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    // 滚轮/触控板双指滑动
    override func scrollWheel(with event: NSEvent) {
        // phase == .changed 是触控板连续滑动
        // phase == .none 是普通滚轮
        let dy = event.scrollingDeltaY
        if abs(dy) > 0.1 {
            onScroll?(dy)
        }
    }

    // 鼠标按下开始拖拽
    override func mouseDown(with event: NSEvent) {
        lastDragLocation = event.locationInWindow
        window?.makeFirstResponder(self)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let last = lastDragLocation else { return }
        let current = event.locationInWindow
        let dx = current.x - last.x
        let dy = -(current.y - last.y) // NSView y轴向上，SwiftUI向下，取反
        onDrag?(dx, dy)
        lastDragLocation = current
    }

    override func mouseUp(with event: NSEvent) {
        lastDragLocation = nil
    }

    // 让鼠标事件不穿透到底层（但节点视图在上层会优先响应）
    override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(range.upperBound, self))
    }
}

// MARK: - 思维导图节点视图
struct MindMapNodeView: View {
    let layout: NodeLayout
    let treeId: String
    let themeColor: Color
    let isSelected: Bool
    let animState: NodeAnimationState
    let onTap: () -> Void
    let onToggleExpand: () -> Void
    let onAddChild: () -> Void

    @State private var isHovered = false
    @State private var showDeleteConfirm = false

    @EnvironmentObject var store: KnowledgeStore

    var node: KnowledgeNode { layout.node }
    var depth: Int { layout.depth }

    var nodeColor: Color {
        if let hex = node.color, let c = NSColor(hex: hex) { return Color(c) }
        return depthColor
    }

    // 根据层级赋予不同默认色（类似截图）
    var depthColor: Color {
        if let hex = node.color, let c = NSColor(hex: hex) { return Color(c) }
        switch depth {
        case 0: return Color(NSColor(hex: tree?.themeColor ?? "#4A90D9") ?? .systemBlue)
        case 1:
            let palette: [Color] = [
                Color(NSColor(hex: "#FF7875") ?? .systemRed),
                Color(NSColor(hex: "#69C0FF") ?? .systemBlue),
                Color(NSColor(hex: "#95DE64") ?? .systemGreen),
                Color(NSColor(hex: "#FFC069") ?? .systemOrange),
                Color(NSColor(hex: "#B37FEB") ?? .systemPurple),
                Color(NSColor(hex: "#5CDBD3") ?? .systemTeal),
                Color(NSColor(hex: "#FF85C2") ?? .systemPink),
            ]
            // 根据 layout.angle 映射到调色板
            let idx = Int(abs(layout.angle / (.pi * 2 / 7))) % palette.count
            return palette[idx]
        default:
            return themeColor.opacity(0.85)
        }
    }

    var tree: KnowledgeTree? {
        store.trees.first(where: { $0.id == treeId })
    }

    // 节点背景色：使用颜色的淡色
    var bgColor: Color {
        if depth == 0 { return nodeColor }
        return nodeColor.opacity(isSelected ? 0.22 : (isHovered ? 0.16 : 0.12))
    }

    var borderColor: Color {
        nodeColor.opacity(isSelected ? 1.0 : (isHovered ? 0.7 : 0.45))
    }

    var shadowColor: Color {
        nodeColor.opacity(animState == .appearing ? 0.6 : (isSelected ? 0.3 : 0))
    }

    var body: some View {
        ZStack {
            if depth == 0 {
                // 根节点：圆形
                rootNodeView
            } else {
                // 子节点：圆角矩形
                childNodeView
            }
        }
        // 新增弹入动画
        .scaleEffect(animState == .appearing ? 1.12 : 1.0)
        .brightness(animState == .highlighting ? 0.18 : 0)
        .shadow(color: shadowColor, radius: animState == .appearing ? 16 : (isSelected ? 8 : 3), x: 0, y: 2)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: animState == .appearing)
        .animation(.easeInOut(duration: 0.25), value: animState == .highlighting)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            if !node.children.isEmpty { onToggleExpand() }
        }
        .onTapGesture(count: 1) { onTap() }
        .contextMenu {
            Button("添加子节点") { onAddChild() }
            Button("编辑节点") { onTap() }
            if !node.children.isEmpty {
                Button(node.isExpanded ? "折叠" : "展开") { onToggleExpand() }
            }
            Divider()
            if tree?.root.id != node.id {
                Button("删除节点", role: .destructive) { showDeleteConfirm = true }
            }
        }
        .confirmationDialog("确定要删除「\(node.title)」及其所有子节点吗？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) { store.deleteNode(node.id, in: treeId) }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 根节点（圆形 + 渐变）
    var rootNodeView: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [nodeColor, nodeColor.opacity(0.7)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 44
                    )
                )
                .frame(width: 88, height: 88)
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.white.opacity(0.8) : Color.white.opacity(0.25),
                            lineWidth: isSelected ? 3 : 1.5
                        )
                )
                .shadow(color: nodeColor.opacity(0.5), radius: 12, x: 0, y: 4)

            VStack(spacing: 3) {
                if let iconName = node.icon, !iconName.isEmpty {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text(node.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 76)
            }
        }
        .frame(width: 88, height: 88)
        // 展开/折叠按钮
        .overlay(alignment: .bottomTrailing) {
            if !node.children.isEmpty {
                collapseButton
                    .offset(x: 4, y: 4)
            }
        }
        // hover 时的添加按钮
        .overlay(alignment: .topTrailing) {
            if isHovered || isSelected {
                addButton
                    .offset(x: 4, y: -4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - 子节点（圆角矩形）
    var childNodeView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: depth <= 2 ? 10 : 8)
                .fill(bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: depth <= 2 ? 10 : 8)
                        .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1.2)
                )
                .frame(width: layout.size.width, height: layout.size.height)

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    if let iconName = node.icon, !iconName.isEmpty {
                        Image(systemName: iconName)
                            .font(.system(size: depth <= 1 ? 12 : 10))
                            .foregroundColor(nodeColor)
                    }
                    Text(node.title)
                        .font(.system(size: depth == 1 ? 13 : 12, weight: depth <= 1 ? .semibold : .medium))
                        .foregroundColor(depth == 1 ? nodeColor : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                if !node.tags.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(node.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .foregroundColor(nodeColor.opacity(0.8))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(nodeColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .overlay(alignment: .topTrailing) {
            if !node.children.isEmpty {
                collapseButton
                    .offset(x: 8, y: -8)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isHovered || isSelected {
                addButton
                    .offset(x: 8, y: 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - 折叠按钮
    var collapseButton: some View {
        Button(action: onToggleExpand) {
            ZStack {
                Circle()
                    .fill(nodeColor)
                    .frame(width: 18, height: 18)
                Image(systemName: node.isExpanded ? "minus" : "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .help(node.isExpanded ? "折叠子节点" : "展开子节点")
    }

    // MARK: - 添加子节点按钮
    var addButton: some View {
        Button(action: onAddChild) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 18, height: 18)
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .help("添加子节点")
    }
}

// MARK: - 控制栏（缩放 + 复位 + 适应）
struct MindMapControlBar: View {
    @Binding var scale: CGFloat
    let onReset: () -> Void
    let onFit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: { withAnimation(.spring()) { scale = max(0.2, scale - 0.15) } }) {
                Image(systemName: "minus").frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))

            Text("\(Int(scale * 100))%")
                .font(.system(size: 12, weight: .medium)).monospacedDigit()
                .frame(width: 46).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .onTapGesture { withAnimation(.spring()) { scale = 1.0 } }
                .help("点击重置缩放")

            Button(action: { withAnimation(.spring()) { scale = min(3.0, scale + 0.15) } }) {
                Image(systemName: "plus").frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))

            Divider().frame(height: 20)

            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise").frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .help("复位视图")

            Button(action: onFit) {
                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass").frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .help("适应屏幕")
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 保留的复用视图

struct TagBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(color)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(color.opacity(0.1)).clipShape(Capsule())
    }
}

struct IconActionButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color)
            .background(RoundedRectangle(cornerRadius: 5).fill(color.opacity(configuration.isPressed ? 0.2 : 0.1)))
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 树统计信息
struct TreeStatsView: View {
    let tree: KnowledgeTree
    let themeColor: Color
    var body: some View {
        HStack(spacing: 12) {
            StatBadge(icon: "square.3.layers.3d", value: "\(tree.root.totalCount)", label: "节点", color: themeColor)
            StatBadge(icon: "arrow.down.to.line", value: "\(tree.root.maxDepth)", label: "深度", color: themeColor)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
            Text(value).font(.system(size: 13, weight: .semibold))
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
    }
}

// MARK: - 背景画布（网格）
struct CanvasBackgroundView: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let spacing: CGFloat = 32
                let dotColor = Color.primary.opacity(0.05)
                var x: CGFloat = 0
                while x < size.width {
                    var y: CGFloat = 0
                    while y < size.height {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                            with: .color(dotColor)
                        )
                        y += spacing
                    }
                    x += spacing
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 添加节点弹窗（保留）
struct AddNodeSheet: View {
    @EnvironmentObject var store: KnowledgeStore
    let parentId: String
    let treeId: String
    var onDismiss: () -> Void

    @State private var title = ""
    @State private var content = ""
    @State private var tagsInput = ""
    @State private var selectedIcon = ""
    @State private var selectedColor = ""

    let iconOptions: [(String, String)] = [
        ("无", ""), ("书籍", "book"), ("灯泡", "lightbulb"), ("代码", "chevron.left.forwardslash.chevron.right"),
        ("星星", "star"), ("心形", "heart"), ("旗帜", "flag"), ("文档", "doc.text"),
        ("链接", "link"), ("脑图", "brain"), ("图表", "chart.bar"), ("时钟", "clock"),
        ("笔记", "pencil"), ("问题", "questionmark.circle"), ("检查", "checkmark.circle"),
        ("地图", "map"), ("网格", "square.grid.2x2"), ("终端", "terminal"),
    ]

    var parentNode: KnowledgeNode? {
        store.trees.first(where: { $0.id == treeId })?.root.findNode(id: parentId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("添加子节点")
                    .font(.headline)
                if let parent = parentNode {
                    Text("→ \(parent.title)")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            Group {
                VStack(alignment: .leading, spacing: 4) {
                    Label("节点标题 *", systemImage: "textformat").font(.caption).foregroundColor(.secondary)
                    TextField("输入节点名称", text: $title).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Label("内容（支持 Markdown）", systemImage: "doc.text").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: $content)
                        .font(.system(size: 13)).frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Label("标签（逗号分隔）", systemImage: "tag").font(.caption).foregroundColor(.secondary)
                    TextField("例如：基础, 重要", text: $tagsInput).textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("图标", systemImage: "square.grid.2x2").font(.caption).foregroundColor(.secondary)
                        Picker("图标", selection: $selectedIcon) {
                            ForEach(iconOptions, id: \.0) { name, icon in
                                if icon.isEmpty { Text("无").tag(icon) }
                                else { Label(name, systemImage: icon).tag(icon) }
                            }
                        }
                        .frame(width: 160)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Label("颜色", systemImage: "paintbrush").font(.caption).foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(NSColor.nodeColors, id: \.hex) { item in
                                Button(action: { selectedColor = item.hex }) {
                                    ZStack {
                                        Circle().fill(Color(NSColor(hex: item.hex)!)).frame(width: 24, height: 24)
                                        if selectedColor == item.hex {
                                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                        }
                                    }
                                }.buttonStyle(.plain)
                            }
                            Button(action: { selectedColor = "" }) {
                                Image(systemName: "xmark").font(.system(size: 10)).foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1))
                            }.buttonStyle(.plain).help("使用继承色")
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("取消") { onDismiss() }
                Spacer()
                Button("添加节点") {
                    let tags = tagsInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    store.addNode(to: parentId, in: treeId, title: title, content: content,
                                  tags: tags, icon: selectedIcon.isEmpty ? nil : selectedIcon,
                                  color: selectedColor.isEmpty ? nil : selectedColor)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(20)
        .frame(width: 480, height: 400)
    }
}
