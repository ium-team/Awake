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
    private let headerSubtitleLabel = NSTextField(labelWithString: "Select apps to keep awake until their processes finish.")
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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
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

        backgroundView.material = .underWindowBackground
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.16).cgColor
        window.contentView = backgroundView

        let contentView = backgroundView

        headerTitleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        headerTitleLabel.textColor = .labelColor
        headerTitleLabel.lineBreakMode = .byTruncatingTail
        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        headerSubtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        headerSubtitleLabel.textColor = .secondaryLabelColor
        headerSubtitleLabel.lineBreakMode = .byTruncatingTail
        headerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        toolbarView.material = .popover
        toolbarView.blendingMode = .withinWindow
        toolbarView.state = .active
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.wantsLayer = true
        toolbarView.layer?.cornerRadius = 10
        toolbarView.layer?.cornerCurve = .continuous
        toolbarView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.28).cgColor
        toolbarView.layer?.borderWidth = 1

        searchField.placeholderString = "Search apps"
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
        tableView.rowHeight = 64
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsMultipleSelection = false
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        let cardColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("card"))
        cardColumn.width = 460
        cardColumn.minWidth = 360
        cardColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(cardColumn)

        listContainerView.material = .popover
        listContainerView.blendingMode = .withinWindow
        listContainerView.state = .active
        listContainerView.translatesAutoresizingMaskIntoConstraints = false
        listContainerView.wantsLayer = true
        listContainerView.layer?.cornerRadius = 12
        listContainerView.layer?.cornerCurve = .continuous
        listContainerView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.28).cgColor
        listContainerView.layer?.borderWidth = 1

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
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
            headerTitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 38),
            headerTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),

            headerSubtitleLabel.leadingAnchor.constraint(equalTo: headerTitleLabel.leadingAnchor),
            headerSubtitleLabel.topAnchor.constraint(equalTo: headerTitleLabel.bottomAnchor, constant: 4),
            headerSubtitleLabel.trailingAnchor.constraint(equalTo: headerTitleLabel.trailingAnchor),

            toolbarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            toolbarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            toolbarView.topAnchor.constraint(equalTo: headerSubtitleLabel.bottomAnchor, constant: 18),
            toolbarView.heightAnchor.constraint(equalToConstant: 46),

            searchField.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor, constant: 12),
            searchField.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            searchField.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -8),

            refreshButton.trailingAnchor.constraint(equalTo: toolbarView.trailingAnchor, constant: -10),
            refreshButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 34),
            refreshButton.heightAnchor.constraint(equalToConstant: 30),

            listContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            listContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            listContainerView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor, constant: 12),
            listContainerView.bottomAnchor.constraint(equalTo: footerView.topAnchor, constant: -12),

            scrollView.leadingAnchor.constraint(equalTo: listContainerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: listContainerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: listContainerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: listContainerView.bottomAnchor),

            footerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            footerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            footerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -22),
            footerView.heightAnchor.constraint(equalToConstant: 54),

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
            ? "Select one or more apps."
            : "\(selectedCount) selected. Awake stops when all selected apps quit."
        startButton.isEnabled = selectedCount > 0
    }

    @objc private func searchChanged() {
        applyFilter()
    }

    @objc private func refreshClicked() {
        reloadApps()
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
            guard filteredApps.indices.contains(row), tableColumn != nil else { return nil }
            let app = filteredApps[row]

            let cell = AppListCellView()
            cell.configure(
                app: app,
                isSelected: selectedPIDs.contains(app.pid)
            )
            return cell
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

private final class AppListCellView: NSView {
    private let appIconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let checkImageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        appIconView.translatesAutoresizingMaskIntoConstraints = false
        appIconView.imageScaling = .scaleProportionallyUpOrDown

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        checkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkImageView.imageScaling = .scaleProportionallyDown
        checkImageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)

        addSubview(appIconView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(checkImageView)

        NSLayoutConstraint.activate([
            appIconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            appIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            appIconView.widthAnchor.constraint(equalToConstant: 34),
            appIconView.heightAnchor.constraint(equalToConstant: 34),

            titleLabel.leadingAnchor.constraint(equalTo: appIconView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: checkImageView.leadingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 13),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),

            checkImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            checkImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkImageView.widthAnchor.constraint(equalToConstant: 22),
            checkImageView.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(app: RunningApp, isSelected: Bool) {
        appIconView.image = app.icon
        titleLabel.stringValue = app.name
        let windowText = app.windows.isEmpty ? "No visible windows" : "\(app.windows.count) visible window\(app.windows.count == 1 ? "" : "s")"
        subtitleLabel.stringValue = "\(windowText) - PID \(app.pid)"
        titleLabel.textColor = isSelected ? .controlAccentColor : .labelColor
        checkImageView.image = NSImage(systemSymbolName: isSelected ? "checkmark.circle.fill" : "circle", accessibilityDescription: nil)
        checkImageView.contentTintColor = isSelected ? .controlAccentColor : .tertiaryLabelColor
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
            color = NSColor.controlAccentColor.withAlphaComponent(0.14)
        } else if isHovering {
            color = NSColor.controlAccentColor.withAlphaComponent(0.07)
        } else {
            color = NSColor.controlBackgroundColor.withAlphaComponent(0.24)
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
