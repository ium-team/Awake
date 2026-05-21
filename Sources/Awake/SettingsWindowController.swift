import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let preventDisplaySleepButton = NSButton(checkboxWithTitle: "Prevent display sleep while a session is active", target: nil, action: nil)
    private let completionNotificationButton = NSButton(checkboxWithTitle: "Notify when Awake stops automatically", target: nil, action: nil)
    private let intervalPopup = NSPopUpButton()

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 180),
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

        let intervalLabel = NSTextField(labelWithString: "Check selected apps every")
        intervalPopup.addItems(withTitles: ["2 seconds", "5 seconds", "10 seconds", "30 seconds"])

        for view in [preventDisplaySleepButton, completionNotificationButton, intervalLabel, intervalPopup] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }

        preventDisplaySleepButton.target = self
        preventDisplaySleepButton.action = #selector(saveSettings)
        completionNotificationButton.target = self
        completionNotificationButton.action = #selector(saveSettings)
        intervalPopup.target = self
        intervalPopup.action = #selector(saveSettings)

        NSLayoutConstraint.activate([
            preventDisplaySleepButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            preventDisplaySleepButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            preventDisplaySleepButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),

            completionNotificationButton.leadingAnchor.constraint(equalTo: preventDisplaySleepButton.leadingAnchor),
            completionNotificationButton.trailingAnchor.constraint(equalTo: preventDisplaySleepButton.trailingAnchor),
            completionNotificationButton.topAnchor.constraint(equalTo: preventDisplaySleepButton.bottomAnchor, constant: 16),

            intervalLabel.leadingAnchor.constraint(equalTo: preventDisplaySleepButton.leadingAnchor),
            intervalLabel.topAnchor.constraint(equalTo: completionNotificationButton.bottomAnchor, constant: 22),

            intervalPopup.leadingAnchor.constraint(equalTo: intervalLabel.trailingAnchor, constant: 12),
            intervalPopup.centerYAnchor.constraint(equalTo: intervalLabel.centerYAnchor),
            intervalPopup.widthAnchor.constraint(equalToConstant: 130)
        ])
    }

    private func loadSettings() {
        let settings = settingsStore.settings
        preventDisplaySleepButton.state = settings.preventDisplaySleep ? .on : .off
        completionNotificationButton.state = settings.showCompletionNotification ? .on : .off

        switch settings.monitorInterval {
        case 2: intervalPopup.selectItem(withTitle: "2 seconds")
        case 10: intervalPopup.selectItem(withTitle: "10 seconds")
        case 30: intervalPopup.selectItem(withTitle: "30 seconds")
        default: intervalPopup.selectItem(withTitle: "5 seconds")
        }
    }

    @objc private func saveSettings() {
        let interval: TimeInterval
        switch intervalPopup.titleOfSelectedItem {
        case "2 seconds": interval = 2
        case "10 seconds": interval = 10
        case "30 seconds": interval = 30
        default: interval = 5
        }

        settingsStore.settings = AwakeSettings(
            preventDisplaySleep: preventDisplaySleepButton.state == .on,
            showCompletionNotification: completionNotificationButton.state == .on,
            monitorInterval: interval
        )
    }
}
