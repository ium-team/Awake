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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 300),
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
        stack.alignment = .leading
        stack.spacing = 28
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let sessionSection = makeSection(
            title: "Session",
            rows: [
                makeToggleRow(
                    title: "Prevent display sleep",
                    subtitle: "Keep the screen on while selected apps are running.",
                    toggle: preventDisplaySleepSwitch
                ),
                makeToggleRow(
                    title: "Notify when Awake stops",
                    subtitle: "Show a notification after all selected apps finish.",
                    toggle: completionNotificationSwitch
                )
            ]
        )

        let autoRunSection = makeSection(
            title: "Auto Run",
            rows: [
                makeToggleRow(
                    title: "Launch Awake at login",
                    subtitle: "Start the menu bar app automatically after you sign in.",
                    toggle: launchAtLoginSwitch
                )
            ]
        )

        stack.addArrangedSubview(sessionSection)
        stack.addArrangedSubview(autoRunSection)

        preventDisplaySleepSwitch.target = self
        preventDisplaySleepSwitch.action = #selector(saveSettings)
        completionNotificationSwitch.target = self
        completionNotificationSwitch.action = #selector(saveSettings)
        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(launchAtLoginChanged)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -18)
        ])
    }

    private func makeSection(title: String, rows: [NSView]) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 10
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor

        let card = NSStackView()
        card.orientation = .vertical
        card.alignment = .leading
        card.spacing = 0
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        for (index, row) in rows.enumerated() {
            card.addArrangedSubview(row)
            if index < rows.count - 1 {
                card.addArrangedSubview(makeDivider())
            }
        }

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(card)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 484),
            card.widthAnchor.constraint(equalTo: container.widthAnchor)
        ])

        return container
    }

    private func makeToggleRow(title: String, subtitle: String, toggle: NSSwitch) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        toggle.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(titleLabel)
        row.addSubview(subtitleLabel)
        row.addSubview(toggle)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 62),

            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            row.widthAnchor.constraint(equalToConstant: 484)
        ])

        return row
    }

    private func makeDivider() -> NSView {
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            divider.heightAnchor.constraint(equalToConstant: 1),
            divider.widthAnchor.constraint(equalToConstant: 456)
        ])
        return divider
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
