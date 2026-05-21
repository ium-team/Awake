import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let loginItemController: LoginItemController
    private let onPowerSettingsChanged: () -> Void
    private let diagnosticsProvider: () -> AwakeDiagnostics?
    private let onInstallOrRepairHelper: () throws -> Void
    private let onUninstallHelper: () throws -> Void
    private var hostingView: NSHostingView<AwakeSettingsView>?

    init(
        settingsStore: SettingsStore,
        loginItemController: LoginItemController,
        onPowerSettingsChanged: @escaping () -> Void,
        diagnosticsProvider: @escaping () -> AwakeDiagnostics?,
        onInstallOrRepairHelper: @escaping () throws -> Void,
        onUninstallHelper: @escaping () throws -> Void
    ) {
        self.settingsStore = settingsStore
        self.loginItemController = loginItemController
        self.onPowerSettingsChanged = onPowerSettingsChanged
        self.diagnosticsProvider = diagnosticsProvider
        self.onInstallOrRepairHelper = onInstallOrRepairHelper
        self.onUninstallHelper = onUninstallHelper

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
            },
            diagnosticsProvider: diagnosticsProvider,
            onInstallOrRepairHelper: onInstallOrRepairHelper,
            onUninstallHelper: onUninstallHelper,
            onHelperError: { [weak self] error in
                self?.showHelperError(error)
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

    private func showHelperError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not update lid-closed helper"
        alert.informativeText = error.localizedDescription
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
    private let diagnosticsProvider: () -> AwakeDiagnostics?
    private let onInstallOrRepairHelper: () throws -> Void
    private let onUninstallHelper: () throws -> Void
    private let onHelperError: (Error) -> Void

    @State private var preventDisplaySleep: Bool
    @State private var supportClosedDisplayMode: Bool
    @State private var forceLidClosedAwake: Bool
    @State private var lockScreenForLidClosedAwake: Bool
    @State private var maximumLidClosedSessionMinutes: Int
    @State private var stopLidClosedSessionAtBatteryPercent: Int
    @State private var showCompletionNotification: Bool
    @State private var launchAtLogin: Bool
    @State private var diagnostics: AwakeDiagnostics?
    @State private var helperStatusMessage = ""

    init(
        settingsStore: SettingsStore,
        loginItemController: LoginItemController,
        onPowerSettingsChanged: @escaping () -> Void,
        onLoginItemError: @escaping (Error) -> Void,
        diagnosticsProvider: @escaping () -> AwakeDiagnostics?,
        onInstallOrRepairHelper: @escaping () throws -> Void,
        onUninstallHelper: @escaping () throws -> Void,
        onHelperError: @escaping (Error) -> Void
    ) {
        let settings = settingsStore.settings
        let launchAtLogin = loginItemController.isEnabled
        let diagnostics = diagnosticsProvider()

        self.settingsStore = settingsStore
        self.loginItemController = loginItemController
        self.onPowerSettingsChanged = onPowerSettingsChanged
        self.onLoginItemError = onLoginItemError
        self.diagnosticsProvider = diagnosticsProvider
        self.onInstallOrRepairHelper = onInstallOrRepairHelper
        self.onUninstallHelper = onUninstallHelper
        self.onHelperError = onHelperError
        _preventDisplaySleep = State(initialValue: settings.preventDisplaySleep)
        _supportClosedDisplayMode = State(initialValue: settings.supportClosedDisplayMode)
        _forceLidClosedAwake = State(initialValue: settings.forceLidClosedAwake)
        _lockScreenForLidClosedAwake = State(initialValue: settings.lockScreenForLidClosedAwake)
        _maximumLidClosedSessionMinutes = State(initialValue: settings.maximumLidClosedSessionMinutes)
        _stopLidClosedSessionAtBatteryPercent = State(initialValue: settings.stopLidClosedSessionAtBatteryPercent)
        _showCompletionNotification = State(initialValue: settings.showCompletionNotification)
        _launchAtLogin = State(initialValue: launchAtLogin)
        _diagnostics = State(initialValue: diagnostics)

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
                        onPowerSettingsChanged()
                    }

                Stepper(
                    maximumLidClosedSessionMinutes == 0
                        ? "No lid-closed time limit"
                        : "Stop lid-closed mode after \(maximumLidClosedSessionMinutes) minutes",
                    value: $maximumLidClosedSessionMinutes,
                    in: 0...1440,
                    step: 30
                )
                .disabled(!forceLidClosedAwake)
                .onChange(of: maximumLidClosedSessionMinutes) { newValue in
                    var settings = settingsStore.settings
                    settings.maximumLidClosedSessionMinutes = newValue
                    settingsStore.settings = settings
                }

                Stepper(
                    "Stop lid-closed mode at \(stopLidClosedSessionAtBatteryPercent)% battery",
                    value: $stopLidClosedSessionAtBatteryPercent,
                    in: 1...100,
                    step: 5
                )
                .disabled(!forceLidClosedAwake)
                .onChange(of: stopLidClosedSessionAtBatteryPercent) { newValue in
                    var settings = settingsStore.settings
                    settings.stopLidClosedSessionAtBatteryPercent = newValue
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

            Section("Lid-Closed Helper") {
                diagnosticsRows

                HStack {
                    Button("Install or Repair Helper") {
                        runHelperAction(onInstallOrRepairHelper, successMessage: "Helper installed or repaired.")
                    }

                    Button("Uninstall Helper") {
                        runHelperAction(onUninstallHelper, successMessage: "Helper uninstalled and macOS sleep restored.")
                    }

                    Button("Refresh") {
                        refreshDiagnostics()
                    }
                }

                if !helperStatusMessage.isEmpty {
                    Text(helperStatusMessage)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
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

    @ViewBuilder
    private var diagnosticsRows: some View {
        if let diagnostics {
            LabeledContent("Helper", value: diagnostics.helperInstalled ? "Ready" : "Needs repair")
            LabeledContent("SleepDisabled", value: diagnostics.sleepDisabled ? "On" : "Off")
            LabeledContent("Lid", value: optionalBoolText(diagnostics.lidClosed, trueText: "Closed", falseText: "Open"))
            LabeledContent("Battery", value: diagnostics.batteryPercent.map { "\($0)%" } ?? "Unknown")
            LabeledContent("Power Source", value: diagnostics.powerSource ?? "Unknown")
        } else {
            Text("Diagnostics are not available.")
                .foregroundStyle(.secondary)
        }
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

    private func refreshDiagnostics() {
        diagnostics = diagnosticsProvider()
    }

    private func runHelperAction(_ action: () throws -> Void, successMessage: String) {
        do {
            try action()
            helperStatusMessage = successMessage
            refreshDiagnostics()
        } catch {
            helperStatusMessage = ""
            onHelperError(error)
            refreshDiagnostics()
        }
    }

    private func optionalBoolText(_ value: Bool?, trueText: String, falseText: String) -> String {
        guard let value else { return "Unknown" }
        return value ? trueText : falseText
    }
}
