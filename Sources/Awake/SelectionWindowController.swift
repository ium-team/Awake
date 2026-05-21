import AppKit

@MainActor
final class SelectionWindowController: NSWindowController {
    private let appProvider: RunningAppProvider
    private let onStart: ([AwakeTarget]) -> Void
    private var allApps: [RunningApp] = []
    private var filteredApps: [RunningApp] = []
    private var selectedPIDs = Set<pid_t>()

    private let backgroundView = NSVisualEffectView()
    private let headerTitleLabel = NSTextField(labelWithString: "Keep Apps Awake")
    private let headerSubtitleLabel = NSTextField(labelWithString: "Choose the apps that should keep your Mac awake until they finish.")
    private let toolbarView = NSVisualEffectView()
    private let listContainerView = NSVisualEffectView()
    private let footerView = NSVisualEffectView()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let searchField = NSSearchField()
    private let startButton = NSButton(title: "Start", target: nil, action: nil)
    private let refreshButton = NSButton(title: "", target: nil, action: nil)
    private let detailLabel = NSTextField(labelWithString: "")

    init(appProvider: RunningAppProvider, onStart: @escaping ([AwakeTarget]) -> Void) {
        self.appProvider = appProvider
        self.onStart = onStart

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Keep Apps Awake"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        super.init(window: window)
        setupUI()
        reloadApps()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        reloadApps()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupUI() {
        guard let window else { return }

        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.wantsLayer = true
        window.contentView = backgroundView

        let contentView = backgroundView

        headerTitleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        headerTitleLabel.textColor = .labelColor
        headerTitleLabel.lineBreakMode = .byTruncatingTail
        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        headerSubtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        headerSubtitleLabel.textColor = .secondaryLabelColor
        headerSubtitleLabel.lineBreakMode = .byTruncatingTail
        headerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        toolbarView.material = .sidebar
        toolbarView.blendingMode = .withinWindow
        toolbarView.state = .active
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.wantsLayer = true
        toolbarView.layer?.cornerRadius = 13
        toolbarView.layer?.cornerCurve = .continuous
        toolbarView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        toolbarView.layer?.borderWidth = 1

        searchField.placeholderString = "Filter apps"
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.bezelStyle = .roundedBezel
        searchField.focusRingType = .none
        searchField.translatesAutoresizingMaskIntoConstraints = false

        refreshButton.target = self
        refreshButton.action = #selector(refreshClicked)
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        refreshButton.imagePosition = .imageOnly
        refreshButton.bezelStyle = .texturedRounded
        refreshButton.toolTip = "Refresh app list"
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        startButton.target = self
        startButton.action = #selector(startClicked)
        startButton.keyEquivalent = "\r"
        startButton.isEnabled = false
        startButton.bezelStyle = .rounded
        startButton.controlSize = .large
        startButton.translatesAutoresizingMaskIntoConstraints = false

        footerView.material = .menu
        footerView.blendingMode = .withinWindow
        footerView.state = .active
        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerView.wantsLayer = true
        footerView.layer?.cornerRadius = 14
        footerView.layer?.cornerCurve = .continuous
        footerView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        footerView.layer?.borderWidth = 1

        detailLabel.textColor = .secondaryLabelColor
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowHeight = 58
        tableView.intercellSpacing = NSSize(width: 0, height: 6)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsMultipleSelection = false

        let checkboxColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("selected"))
        checkboxColumn.width = 48
        tableView.addTableColumn(checkboxColumn)

        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appColumn.title = "App"
        appColumn.width = 450
        tableView.addTableColumn(appColumn)

        let windowColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("windows"))
        windowColumn.title = "Windows"
        windowColumn.width = 120
        tableView.addTableColumn(windowColumn)

        listContainerView.material = .contentBackground
        listContainerView.blendingMode = .withinWindow
        listContainerView.state = .active
        listContainerView.translatesAutoresizingMaskIntoConstraints = false
        listContainerView.wantsLayer = true
        listContainerView.layer?.cornerRadius = 18
        listContainerView.layer?.cornerCurve = .continuous
        listContainerView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        listContainerView.layer?.borderWidth = 1

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(headerTitleLabel)
        contentView.addSubview(headerSubtitleLabel)
        contentView.addSubview(toolbarView)
        toolbarView.addSubview(searchField)
        toolbarView.addSubview(refreshButton)
        contentView.addSubview(listContainerView)
        listContainerView.addSubview(scrollView)
        contentView.addSubview(footerView)
        footerView.addSubview(detailLabel)
        footerView.addSubview(startButton)

        NSLayoutConstraint.activate([
            headerTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            headerTitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 42),
            headerTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),

            headerSubtitleLabel.leadingAnchor.constraint(equalTo: headerTitleLabel.leadingAnchor),
            headerSubtitleLabel.topAnchor.constraint(equalTo: headerTitleLabel.bottomAnchor, constant: 4),
            headerSubtitleLabel.trailingAnchor.constraint(equalTo: headerTitleLabel.trailingAnchor),

            toolbarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            toolbarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            toolbarView.topAnchor.constraint(equalTo: headerSubtitleLabel.bottomAnchor, constant: 20),
            toolbarView.heightAnchor.constraint(equalToConstant: 52),

            searchField.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor, constant: 12),
            searchField.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            searchField.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -8),

            refreshButton.trailingAnchor.constraint(equalTo: toolbarView.trailingAnchor, constant: -10),
            refreshButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 34),
            refreshButton.heightAnchor.constraint(equalToConstant: 30),

            listContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            listContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            listContainerView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor, constant: 14),
            listContainerView.bottomAnchor.constraint(equalTo: footerView.topAnchor, constant: -14),

            scrollView.leadingAnchor.constraint(equalTo: listContainerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: listContainerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: listContainerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: listContainerView.bottomAnchor),

            footerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            footerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            footerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -22),
            footerView.heightAnchor.constraint(equalToConstant: 58),

            detailLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 16),
            detailLabel.trailingAnchor.constraint(equalTo: startButton.leadingAnchor, constant: -16),
            detailLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),

            startButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -12),
            startButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 104)
        ])
    }

    private func reloadApps() {
        allApps = appProvider.snapshot()
        applyFilter()
    }

    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredApps = allApps
        } else {
            filteredApps = allApps.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        tableView.reloadData()
        updateFooter()
    }

    private func updateFooter() {
        let selectedCount = selectedPIDs.count
        detailLabel.stringValue = selectedCount == 0
            ? "Select one or more apps. Awake stops when all selected app processes exit."
            : "\(selectedCount) selected. Display sleep behavior follows Settings."
        startButton.isEnabled = selectedCount > 0
    }

    @objc private func searchChanged() {
        applyFilter()
    }

    @objc private func refreshClicked() {
        reloadApps()
    }

    @objc private func checkboxChanged(_ sender: NSButton) {
        let row = sender.tag
        guard filteredApps.indices.contains(row) else { return }
        let pid = filteredApps[row].pid
        if sender.state == .on {
            selectedPIDs.insert(pid)
        } else {
            selectedPIDs.remove(pid)
        }
        tableView.reloadData()
        updateFooter()
    }

    @objc private func startClicked() {
        let targets = allApps
            .filter { selectedPIDs.contains($0.pid) }
            .map { AwakeTarget(pid: $0.pid, bundleIdentifier: $0.bundleIdentifier, displayName: $0.name) }

        guard !targets.isEmpty else { return }
        window?.orderOut(nil)
        onStart(targets)
    }
}

extension SelectionWindowController: NSTableViewDataSource, NSTableViewDelegate {
    nonisolated func numberOfRows(in tableView: NSTableView) -> Int {
        MainActor.assumeIsolated {
            filteredApps.count
        }
    }

    nonisolated func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        MainActor.assumeIsolated {
            guard filteredApps.indices.contains(row), let tableColumn else { return nil }
            let app = filteredApps[row]

            switch tableColumn.identifier.rawValue {
            case "selected":
                let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxChanged(_:)))
                checkbox.tag = row
                checkbox.state = selectedPIDs.contains(app.pid) ? .on : .off
                checkbox.controlSize = .large
                checkbox.translatesAutoresizingMaskIntoConstraints = false
                return CenteredControlCell(control: checkbox)
            case "app":
                let cell = AppCellView()
                cell.configure(app: app, isSelected: selectedPIDs.contains(app.pid))
                return cell
            case "windows":
                let title = app.windows.isEmpty ? "No windows" : "\(app.windows.count) window\(app.windows.count == 1 ? "" : "s")"
                return WindowCountView(title: title, isSelected: selectedPIDs.contains(app.pid))
            default:
                return nil
            }
        }
    }

    nonisolated func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        MainActor.assumeIsolated {
            guard filteredApps.indices.contains(row) else { return nil }
            return AppRowView(isAwakeSelected: selectedPIDs.contains(filteredApps[row].pid))
        }
    }

    nonisolated func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        MainActor.assumeIsolated {
            guard filteredApps.indices.contains(row) else { return false }
            let pid = filteredApps[row].pid
            if selectedPIDs.contains(pid) {
                selectedPIDs.remove(pid)
            } else {
                selectedPIDs.insert(pid)
            }
            tableView.reloadData()
            updateFooter()
            return false
        }
    }
}

private final class AppCellView: NSView {
    private let imageView = NSImageView()
    private let iconBackgroundView = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        iconBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        iconBackgroundView.wantsLayer = true
        iconBackgroundView.layer?.cornerRadius = 10
        iconBackgroundView.layer?.cornerCurve = .continuous
        iconBackgroundView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72).cgColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconBackgroundView)
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            iconBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconBackgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconBackgroundView.widthAnchor.constraint(equalToConstant: 38),
            iconBackgroundView.heightAnchor.constraint(equalToConstant: 38),

            imageView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 28),
            imageView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: iconBackgroundView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(app: RunningApp, isSelected: Bool) {
        imageView.image = app.icon
        titleLabel.stringValue = app.name
        subtitleLabel.stringValue = app.bundleIdentifier ?? "PID \(app.pid)"
        titleLabel.textColor = isSelected ? .controlAccentColor : .labelColor
    }
}

private final class AppRowView: NSTableRowView {
    private let isAwakeSelected: Bool
    private var isHovering = false
    private var trackingArea: NSTrackingArea?

    init(isAwakeSelected: Bool) {
        self.isAwakeSelected = isAwakeSelected
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func drawBackground(in dirtyRect: NSRect) {
        let insetBounds = bounds.insetBy(dx: 2, dy: 1)
        let path = NSBezierPath(roundedRect: insetBounds, xRadius: 13, yRadius: 13)
        let color: NSColor

        if isAwakeSelected {
            color = NSColor.controlAccentColor.withAlphaComponent(0.16)
        } else if isHovering {
            color = NSColor.controlAccentColor.withAlphaComponent(0.08)
        } else {
            color = NSColor.controlBackgroundColor.withAlphaComponent(0.46)
        }

        color.setFill()
        path.fill()

        NSColor.separatorColor.withAlphaComponent(isAwakeSelected ? 0.55 : 0.22).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }
}

private final class WindowCountView: NSView {
    private let label = NSTextField(labelWithString: "")

    init(title: String, isSelected: Bool) {
        super.init(frame: .zero)
        label.stringValue = title
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = isSelected ? .controlAccentColor : .secondaryLabelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = (isSelected ? NSColor.controlAccentColor : NSColor.controlBackgroundColor)
            .withAlphaComponent(isSelected ? 0.13 : 0.56)
            .cgColor

        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 24),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class CenteredControlCell: NSView {
    init(control: NSControl) {
        super.init(frame: .zero)
        addSubview(control)

        NSLayoutConstraint.activate([
            control.centerXAnchor.constraint(equalTo: centerXAnchor),
            control.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}
