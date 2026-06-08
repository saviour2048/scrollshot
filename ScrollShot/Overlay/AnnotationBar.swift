import AppKit

/// The floating toolbar shown next to a selection: drawing tools + color +
/// stroke width + undo, then the save / copy / cancel actions.
final class AnnotationBar: NSView {
    var onSelectTool: ((AnnotationTool) -> Void)?
    var onColor: ((NSColor) -> Void)?
    var onWidth: ((CGFloat) -> Void)?
    var onUndo: (() -> Void)?
    var onSave: (() -> Void)?
    var onCopy: (() -> Void)?
    var onCancel: (() -> Void)?
    var onLongCapture: (() -> Void)?

    private static let orderedTools: [AnnotationTool] = [.arrow, .rectangle, .ellipse, .pen, .text, .mosaic]
    private static let widthValues: [CGFloat] = [2, 4, 7]

    private let showsLongCapture: Bool
    private var toolButtons: [AnnotationTool: NSButton] = [:]
    private let colorWell = NSColorWell()
    private let stack = NSStackView()
    /// Liquid Glass background (renders as Liquid Glass on macOS Tahoe, vibrancy
    /// on earlier systems). Lets the screenshot show through the toolbar.
    private let glass = NSVisualEffectView()

    init(showsLongCapture: Bool = true) {
        self.showsLongCapture = showsLongCapture
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 18                                             // capsule-like (Apple Music feel)
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor  // glass highlight edge
        // Standard controls render in dark mode for contrast on the glass.
        appearance = NSAppearance(named: .darkAqua)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var currentColor: NSColor { colorWell.color }
    var currentWidth: CGFloat { Self.widthValues[1] }

    /// The natural size of the toolbar content. Computed from the stack itself
    /// (not tied to this view's frame) so it is never collapsed to zero.
    var contentSize: NSSize {
        stack.layoutSubtreeIfNeeded()
        return stack.fittingSize
    }

    override func layout() {
        super.layout()
        glass.frame = bounds
        stack.frame = bounds
    }

    private func buildUI() {
        glass.material = .hudWindow
        glass.blendingMode = .withinWindow
        glass.state = .active
        addSubview(glass)

        var views: [NSView] = []

        for (index, tool) in Self.orderedTools.enumerated() {
            let button = tool == .text
                ? labeledToolButton(title: "文字", tag: index)
                : toolButton(symbol: symbol(for: tool), tip: tip(for: tool), tag: index)
            toolButtons[tool] = button
            views.append(button)
        }

        views.append(separator())

        colorWell.color = .systemRed
        colorWell.target = self
        colorWell.action = #selector(colorChanged)
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.widthAnchor.constraint(equalToConstant: 38).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 22).isActive = true
        views.append(colorWell)

        let widthControl = NSSegmentedControl(
            labels: ["细", "中", "粗"],
            trackingMode: .selectOne,
            target: self,
            action: #selector(widthChanged(_:))
        )
        widthControl.selectedSegment = 1
        views.append(widthControl)

        views.append(actionButton(title: "撤销", action: #selector(undoTapped)))
        views.append(separator())
        if showsLongCapture {
            let longButton = actionButton(title: "长截图", action: #selector(longCaptureTapped))
            longButton.bezelColor = .systemTeal
            views.append(longButton)
        }
        let saveButton = actionButton(title: "保存", action: #selector(saveTapped))
        saveButton.bezelColor = .controlAccentColor   // make the primary action stand out
        views.append(saveButton)
        views.append(actionButton(title: "复制", action: #selector(copyTapped)))
        views.append(actionButton(title: "取消", action: #selector(cancelTapped)))

        views.forEach { stack.addArrangedSubview($0) }
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        // Don't let any control be compressed out of view; the bar is sized to
        // the stack's full content via `contentSize`.
        stack.setHuggingPriority(.required, for: .horizontal)
        stack.setClippingResistancePriority(.required, for: .horizontal)
        addSubview(stack)
    }

    func setActiveTool(_ tool: AnnotationTool?) {
        for (candidate, button) in toolButtons {
            let color: NSColor = (candidate == tool) ? .controlAccentColor : .white
            button.contentTintColor = color
            if !button.title.isEmpty { applyTitleColor(color, to: button) }
        }
    }

    private func applyTitleColor(_ color: NSColor, to button: NSButton) {
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: 12, weight: .medium)
            ]
        )
    }

    // MARK: Builders

    private func toolButton(symbol: String, tip: String, tag: Int) -> NSButton {
        let button = NSButton()
        button.title = ""                       // no default "按钮" title
        button.imagePosition = .imageOnly
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
        button.imageScaling = .scaleProportionallyDown
        button.isBordered = false
        button.bezelStyle = .texturedRounded
        button.contentTintColor = .white
        button.toolTip = tip
        button.tag = tag
        button.target = self
        button.action = #selector(toolTapped(_:))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return button
    }

    /// A tool button that shows a text label (e.g. 「文字」) instead of an icon.
    private func labeledToolButton(title: String, tag: Int) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(toolTapped(_:)))
        button.isBordered = false
        button.bezelStyle = .texturedRounded
        button.font = .systemFont(ofSize: 12, weight: .medium)
        button.contentTintColor = .white
        button.tag = tag
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        applyTitleColor(.white, to: button)   // visible on the dark toolbar
        return button
    }

    private func actionButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 1).isActive = true
        box.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return box
    }

    private func symbol(for tool: AnnotationTool) -> String {
        switch tool {
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .pen: return "pencil.tip"
        case .text: return "textformat"
        case .mosaic: return "square.grid.3x3.fill"
        }
    }

    private func tip(for tool: AnnotationTool) -> String {
        switch tool {
        case .arrow: return "箭头"
        case .rectangle: return "矩形"
        case .ellipse: return "椭圆"
        case .pen: return "画笔"
        case .text: return "文字"
        case .mosaic: return "马赛克"
        }
    }

    // MARK: Actions

    @objc private func toolTapped(_ sender: NSButton) {
        let tool = Self.orderedTools[sender.tag]
        setActiveTool(tool)
        onSelectTool?(tool)
    }

    @objc private func colorChanged() { onColor?(colorWell.color) }

    @objc private func widthChanged(_ sender: NSSegmentedControl) {
        let index = max(0, min(Self.widthValues.count - 1, sender.selectedSegment))
        onWidth?(Self.widthValues[index])
    }

    @objc private func undoTapped() { onUndo?() }
    @objc private func longCaptureTapped() { onLongCapture?() }
    @objc private func saveTapped() { onSave?() }
    @objc private func copyTapped() { onCopy?() }
    @objc private func cancelTapped() { onCancel?() }
}
