import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let loginItemController: LoginItemController

    private let preventDisplaySleepSwitch = NSSwitch()
    private let completionNotificationSwitch = NSSwitch()
    private let launchAtLoginSwitch = NSSwitch()

    init(settingsStore: SettingsStore, loginItemController: LoginItemController) {
        self.settingsStore = settingsStore
        self.loginItemController = loginItemController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Awake Settings"
        window.center()
        super.init(window: window)
        setupUI()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        loadSettings()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        stack.addArrangedSubview(makeHeader())
        stack.addArrangedSubview(
            makeTogglePanel(rows: [
                makeToggleRow(
                    title: "Keep the display awake",
                    subtitle: "Adds display sleep prevention to active protection sessions.",
                    toggle: preventDisplaySleepSwitch
                ),
                makeToggleRow(
                    title: "Completion notifications",
                    subtitle: "Notify when all selected apps finish and Awake releases protection.",
                    toggle: completionNotificationSwitch
                ),
                makeToggleRow(
                    title: "Open at login",
                    subtitle: "Start Awake as a menu bar app when you sign in.",
                    toggle: launchAtLoginSwitch
                )
            ])
        )
        stack.addArrangedSubview(makeFooterNote())

        preventDisplaySleepSwitch.target = self
        preventDisplaySleepSwitch.action = #selector(saveSettings)
        completionNotificationSwitch.target = self
        completionNotificationSwitch.action = #selector(saveSettings)
        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(launchAtLoginChanged)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    private func makeHeader() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 6
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Settings")
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .labelColor

        let subtitleLabel = NSTextField(labelWithString: "Choose how Awake behaves while a protection session is active.")
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        return container
    }

    private func makeTogglePanel(rows: [NSView]) -> NSView {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.alignment = .width
        panel.spacing = 0
        panel.edgeInsets = NSEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        panel.wantsLayer = true
        panel.layer?.cornerRadius = 10
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        panel.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        panel.layer?.borderWidth = 1
        panel.translatesAutoresizingMaskIntoConstraints = false

        for (index, row) in rows.enumerated() {
            panel.addArrangedSubview(row)
            if index < rows.count - 1 {
                panel.addArrangedSubview(makeDivider())
            }
        }

        return panel
    }

    private func makeToggleRow(title: String, subtitle: String, toggle: NSSwitch) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)

        row.addSubview(titleLabel)
        row.addSubview(subtitleLabel)
        row.addSubview(toggle)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 72),

            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -18),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 15),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -18),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -14),

            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -18),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func makeDivider() -> NSView {
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
        return divider
    }

    private func makeFooterNote() -> NSView {
        let label = NSTextField(
            labelWithString: "Awake prevents normal idle sleep during active sessions. Lid-close behavior can still vary by Mac, power, display, and managed device policy."
        )
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func loadSettings() {
        let settings = settingsStore.settings
        preventDisplaySleepSwitch.state = settings.preventDisplaySleep ? .on : .off
        completionNotificationSwitch.state = settings.showCompletionNotification ? .on : .off

        let launchAtLogin = loginItemController.isEnabled
        launchAtLoginSwitch.state = launchAtLogin ? .on : .off
        if launchAtLogin != settings.launchAtLogin {
            var syncedSettings = settings
            syncedSettings.launchAtLogin = launchAtLogin
            settingsStore.settings = syncedSettings
        }
    }

    @objc private func saveSettings() {
        var settings = settingsStore.settings
        settings.preventDisplaySleep = preventDisplaySleepSwitch.state == .on
        settings.showCompletionNotification = completionNotificationSwitch.state == .on
        settingsStore.settings = settings
    }

    @objc private func launchAtLoginChanged() {
        let isEnabled = launchAtLoginSwitch.state == .on

        do {
            try loginItemController.setEnabled(isEnabled)
            var settings = settingsStore.settings
            settings.launchAtLogin = isEnabled
            settingsStore.settings = settings
        } catch {
            launchAtLoginSwitch.state = loginItemController.isEnabled ? .on : .off
            showLoginItemError(error)
        }
    }

    private func showLoginItemError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not update launch at login"
        alert.informativeText = "Open Awake from the app bundle and try again. macOS returned: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window!)
    }
}
