import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let loginItemController: LoginItemController
    private let onPowerSettingsChanged: () -> Void
    private var hostingView: NSHostingView<AwakeSettingsView>?

    init(
        settingsStore: SettingsStore,
        loginItemController: LoginItemController,
        onPowerSettingsChanged: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.loginItemController = loginItemController
        self.onPowerSettingsChanged = onPowerSettingsChanged

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Awake Settings"
        window.center()
        super.init(window: window)
        setupUI()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        hostingView?.rootView = makeSettingsView()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        let hostingView = NSHostingView(rootView: makeSettingsView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostingView)
        self.hostingView = hostingView

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func makeSettingsView() -> AwakeSettingsView {
        AwakeSettingsView(
            settingsStore: settingsStore,
            loginItemController: loginItemController,
            onPowerSettingsChanged: onPowerSettingsChanged,
            onLoginItemError: { [weak self] error in
                self?.showLoginItemError(error)
            }
        )
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

private struct AwakeSettingsView: View {
    private let settingsStore: SettingsStore
    private let loginItemController: LoginItemController
    private let onPowerSettingsChanged: () -> Void
    private let onLoginItemError: (Error) -> Void

    @State private var preventDisplaySleep: Bool
    @State private var supportClosedDisplayMode: Bool
    @State private var forceLidClosedAwake: Bool
    @State private var lockScreenForLidClosedAwake: Bool
    @State private var showCompletionNotification: Bool
    @State private var launchAtLogin: Bool

    init(
        settingsStore: SettingsStore,
        loginItemController: LoginItemController,
        onPowerSettingsChanged: @escaping () -> Void,
        onLoginItemError: @escaping (Error) -> Void
    ) {
        let settings = settingsStore.settings
        let launchAtLogin = loginItemController.isEnabled

        self.settingsStore = settingsStore
        self.loginItemController = loginItemController
        self.onPowerSettingsChanged = onPowerSettingsChanged
        self.onLoginItemError = onLoginItemError
        _preventDisplaySleep = State(initialValue: settings.preventDisplaySleep)
        _supportClosedDisplayMode = State(initialValue: settings.supportClosedDisplayMode)
        _forceLidClosedAwake = State(initialValue: settings.forceLidClosedAwake)
        _lockScreenForLidClosedAwake = State(initialValue: settings.lockScreenForLidClosedAwake)
        _showCompletionNotification = State(initialValue: settings.showCompletionNotification)
        _launchAtLogin = State(initialValue: launchAtLogin)

        if launchAtLogin != settings.launchAtLogin {
            var syncedSettings = settings
            syncedSettings.launchAtLogin = launchAtLogin
            settingsStore.settings = syncedSettings
        }
    }

    var body: some View {
        Form {
            Section("Session") {
                Toggle("Prevent display sleep", isOn: $preventDisplaySleep)
                    .onChange(of: preventDisplaySleep) { newValue in
                        var settings = settingsStore.settings
                        settings.preventDisplaySleep = newValue
                        settingsStore.settings = settings
                        onPowerSettingsChanged()
                    }

                Toggle("Best-effort closed-display support", isOn: $supportClosedDisplayMode)
                    .disabled(!preventDisplaySleep)
                    .onChange(of: supportClosedDisplayMode) { newValue in
                        var settings = settingsStore.settings
                        settings.supportClosedDisplayMode = newValue
                        settingsStore.settings = settings
                        onPowerSettingsChanged()
                    }

                Toggle("Keep awake when lid is closed", isOn: $forceLidClosedAwake)
                    .onChange(of: forceLidClosedAwake) { newValue in
                        var settings = settingsStore.settings
                        settings.forceLidClosedAwake = newValue
                        settingsStore.settings = settings
                        onPowerSettingsChanged()
                    }

                Toggle("Lock screen when the lid closes", isOn: $lockScreenForLidClosedAwake)
                    .disabled(!forceLidClosedAwake)
                    .onChange(of: lockScreenForLidClosedAwake) { newValue in
                        var settings = settingsStore.settings
                        settings.lockScreenForLidClosedAwake = newValue
                        settingsStore.settings = settings
                    }

                Toggle("Notify when Awake stops automatically", isOn: $showCompletionNotification)
                    .onChange(of: showCompletionNotification) { newValue in
                        var settings = settingsStore.settings
                        settings.showCompletionNotification = newValue
                        settingsStore.settings = settings
                    }

                Text("Lid-closed mode asks for administrator approval once to install a helper. The screen locks only when the lid is closed. Do not use it in a bag or confined space.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }

            Section("Auto Run") {
                Toggle("Open Awake at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        updateLaunchAtLogin(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 600, minHeight: 500)
    }

    private func updateLaunchAtLogin(_ isEnabled: Bool) {
        do {
            try loginItemController.setEnabled(isEnabled)
            var settings = settingsStore.settings
            settings.launchAtLogin = isEnabled
            settingsStore.settings = settings
        } catch {
            launchAtLogin = loginItemController.isEnabled
            onLoginItemError(error)
        }
    }
}
