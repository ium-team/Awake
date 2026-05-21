import AppKit

@MainActor
final class SelectionWindowController: NSWindowController {
    private let appProvider: RunningAppProvider
    private let onStart: ([AwakeTarget]) -> Void
    private var allApps: [RunningApp] = []
    private var filteredApps: [RunningApp] = []
    private var selectedPIDs = Set<pid_t>()

    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let searchField = NSSearchField()
    private let startButton = NSButton(title: "Start", target: nil, action: nil)
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let detailLabel = NSTextField(labelWithString: "")

    init(appProvider: RunningAppProvider, onStart: @escaping ([AwakeTarget]) -> Void) {
        self.appProvider = appProvider
        self.onStart = onStart

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keep Apps Awake"
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
        guard let contentView = window?.contentView else { return }

        searchField.placeholderString = "Filter apps"
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        refreshButton.target = self
        refreshButton.action = #selector(refreshClicked)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        startButton.target = self
        startButton.action = #selector(startClicked)
        startButton.keyEquivalent = "\r"
        startButton.isEnabled = false
        startButton.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowHeight = 38
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false

        let checkboxColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("selected"))
        checkboxColumn.width = 34
        tableView.addTableColumn(checkboxColumn)

        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appColumn.title = "App"
        appColumn.width = 410
        tableView.addTableColumn(appColumn)

        let windowColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("windows"))
        windowColumn.title = "Windows"
        windowColumn.width = 120
        tableView.addTableColumn(windowColumn)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(searchField)
        contentView.addSubview(refreshButton)
        contentView.addSubview(scrollView)
        contentView.addSubview(detailLabel)
        contentView.addSubview(startButton)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -8),

            refreshButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            refreshButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 90),

            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: detailLabel.topAnchor, constant: -12),

            detailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            detailLabel.trailingAnchor.constraint(equalTo: startButton.leadingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),

            startButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            startButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            startButton.widthAnchor.constraint(equalToConstant: 96)
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
            ? "Select one or more apps. Awake will stop when all selected app processes exit."
            : "\(selectedCount) selected. Display sleep is controlled in Settings."
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
                return checkbox
            case "app":
                let cell = AppCellView()
                cell.configure(app: app)
                return cell
            case "windows":
                let title = app.windows.isEmpty ? "No windows" : "\(app.windows.count) window\(app.windows.count == 1 ? "" : "s")"
                let label = NSTextField(labelWithString: title)
                label.textColor = .secondaryLabelColor
                return label
            default:
                return nil
            }
        }
    }
}

private final class AppCellView: NSView {
    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(app: RunningApp) {
        imageView.image = app.icon
        titleLabel.stringValue = app.name
        subtitleLabel.stringValue = app.bundleIdentifier ?? "PID \(app.pid)"
    }
}
