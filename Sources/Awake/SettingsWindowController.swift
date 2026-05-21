import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let loginItemController: LoginItemController
    private let onPowerSettingsChanged: () -> Void
    private let onLanguageChanged: () -> Void
    private let diagnosticsProvider: () -> AwakeDiagnostics?
    private let onInstallOrRepairHelper: () throws -> Void
    private let onUninstallHelper: () throws -> Void
    private var hostingView: NSHostingView<AwakeSettingsView>?

    init(
        settingsStore: SettingsStore,
        loginItemController: LoginItemController,
        onPowerSettingsChanged: @escaping () -> Void,
        onLanguageChanged: @escaping () -> Void,
        diagnosticsProvider: @escaping () -> AwakeDiagnostics?,
        onInstallOrRepairHelper: @escaping () throws -> Void,
        onUninstallHelper: @escaping () throws -> Void
    ) {
        self.settingsStore = settingsStore
        self.loginItemController = loginItemController
        self.onPowerSettingsChanged = onPowerSettingsChanged
        self.onLanguageChanged = onLanguageChanged
        self.diagnosticsProvider = diagnosticsProvider
        self.onInstallOrRepairHelper = onInstallOrRepairHelper
        self.onUninstallHelper = onUninstallHelper

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n(language: settingsStore.settings.appLanguage).text(.awakeSettings)
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
            onLanguageChanged: { [weak self] in
                guard let self else { return }
                window?.title = L10n(language: settingsStore.settings.appLanguage).text(.awakeSettings)
                onLanguageChanged()
            },
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
        let l10n = L10n(language: settingsStore.settings.appLanguage)
        alert.messageText = l10n.text(.couldNotUpdateLaunchAtLogin)
        alert.informativeText = l10n.format(.launchAtLoginErrorBody, error.localizedDescription)
        alert.alertStyle = .warning
        alert.addButton(withTitle: l10n.text(.ok))
        alert.beginSheetModal(for: window!)
    }

    private func showHelperError(_ error: Error) {
        let alert = NSAlert()
        let l10n = L10n(language: settingsStore.settings.appLanguage)
        alert.messageText = l10n.text(.couldNotUpdateLidClosedHelper)
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: l10n.text(.ok))
        alert.beginSheetModal(for: window!)
    }
}

private struct AwakeSettingsView: View {
    private let settingsStore: SettingsStore
    private let loginItemController: LoginItemController
    private let onPowerSettingsChanged: () -> Void
    private let onLanguageChanged: () -> Void
    private let onLoginItemError: (Error) -> Void
    private let diagnosticsProvider: () -> AwakeDiagnostics?
    private let onInstallOrRepairHelper: () throws -> Void
    private let onUninstallHelper: () throws -> Void
    private let onHelperError: (Error) -> Void

    @State private var preventDisplaySleep: Bool
    @State private var appLanguage: AppLanguage
    @State private var supportClosedDisplayMode: Bool
    @State private var forceLidClosedAwake: Bool
    @State private var lockScreenForLidClosedAwake: Bool
    @State private var maximumLidClosedSessionMinutes: Int
    @State private var stopLidClosedSessionAtBatteryPercent: Int
    @State private var showCompletionNotification: Bool
    @State private var launchAtLogin: Bool
    @State private var diagnostics: AwakeDiagnostics?
    @State private var helperStatusMessage = ""
    @State private var showAdvancedSettings = false

    init(
        settingsStore: SettingsStore,
        loginItemController: LoginItemController,
        onPowerSettingsChanged: @escaping () -> Void,
        onLanguageChanged: @escaping () -> Void,
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
        self.onLanguageChanged = onLanguageChanged
        self.onLoginItemError = onLoginItemError
        self.diagnosticsProvider = diagnosticsProvider
        self.onInstallOrRepairHelper = onInstallOrRepairHelper
        self.onUninstallHelper = onUninstallHelper
        self.onHelperError = onHelperError
        _appLanguage = State(initialValue: settings.appLanguage)
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
        let l10n = L10n(language: appLanguage)

        VStack(spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(l10n.text(.language))
                        .font(.headline)
                    Text(l10n.text(.languagePickerDescription))
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                Spacer()

                Picker("", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(l10n.languageDisplayName(language)).tag(language)
                    }
                }
                .labelsHidden()
                .frame(width: 190)
                .onChange(of: appLanguage) { newValue in
                    updateLanguage(newValue)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            )

            Form {
                Section(l10n.text(.general)) {
                Toggle(l10n.text(.keepMacAwakeWhenLidClosed), isOn: $forceLidClosedAwake)
                    .onChange(of: forceLidClosedAwake) { newValue in
                        var settings = settingsStore.settings
                        settings.forceLidClosedAwake = newValue
                        settingsStore.settings = settings
                        onPowerSettingsChanged()
                    }

                Toggle(l10n.text(.lockScreenWhenLidCloses), isOn: $lockScreenForLidClosedAwake)
                    .disabled(!forceLidClosedAwake)
                    .onChange(of: lockScreenForLidClosedAwake) { newValue in
                        var settings = settingsStore.settings
                        settings.lockScreenForLidClosedAwake = newValue
                        settingsStore.settings = settings
                        onPowerSettingsChanged()
                    }

                Stepper(
                    maximumLidClosedSessionMinutes == 0
                        ? l10n.text(.noSafetyTimeLimit)
                        : l10n.format(.safetyTimeLimit, l10n.duration(minutes: maximumLidClosedSessionMinutes)),
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
                    l10n.format(.stopIfBatteryDropsBelow, stopLidClosedSessionAtBatteryPercent),
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

                Toggle(l10n.text(.notifyWhenSessionEnds), isOn: $showCompletionNotification)
                    .onChange(of: showCompletionNotification) { newValue in
                        var settings = settingsStore.settings
                        settings.showCompletionNotification = newValue
                        settingsStore.settings = settings
                    }

                Text(l10n.text(.lidClosedModeNotice))
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }

            Section(l10n.text(.startup)) {
                Toggle(l10n.text(.openAwakeAtLogin), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        updateLaunchAtLogin(newValue)
                    }
            }

            Section(l10n.text(.advanced)) {
                DisclosureGroup(l10n.text(.troubleshooting), isExpanded: $showAdvancedSettings) {
                    diagnosticsRows

                    Toggle(l10n.text(.preventDisplaySleep), isOn: $preventDisplaySleep)
                        .onChange(of: preventDisplaySleep) { newValue in
                            var settings = settingsStore.settings
                            settings.preventDisplaySleep = newValue
                            settingsStore.settings = settings
                            onPowerSettingsChanged()
                        }

                    Toggle(l10n.text(.useClosedDisplayNetworkSupport), isOn: $supportClosedDisplayMode)
                        .disabled(!preventDisplaySleep)
                        .onChange(of: supportClosedDisplayMode) { newValue in
                            var settings = settingsStore.settings
                            settings.supportClosedDisplayMode = newValue
                            settingsStore.settings = settings
                            onPowerSettingsChanged()
                        }

                    HStack {
                        Button(l10n.text(.repairHelper)) {
                            runHelperAction(onInstallOrRepairHelper, successMessage: l10n.text(.helperRepaired))
                        }

                        Button(l10n.text(.uninstallHelper)) {
                            runHelperAction(onUninstallHelper, successMessage: l10n.text(.helperUninstalled))
                        }

                        Button(l10n.text(.refresh)) {
                            refreshDiagnostics()
                        }
                    }

                    if !helperStatusMessage.isEmpty {
                        Text(helperStatusMessage)
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
            }
        }
            .formStyle(.grouped)
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 560)
    }

    @ViewBuilder
    private var diagnosticsRows: some View {
        let l10n = L10n(language: appLanguage)

        if let diagnostics {
            LabeledContent(l10n.text(.helper), value: diagnostics.helperInstalled ? l10n.text(.ready) : l10n.text(.needsRepair))
            LabeledContent(l10n.text(.sleepDisabled), value: diagnostics.sleepDisabled ? l10n.text(.on) : l10n.text(.off))
            LabeledContent(l10n.text(.lid), value: optionalBoolText(diagnostics.lidClosed, trueText: l10n.text(.closed), falseText: l10n.text(.open)))
            LabeledContent(l10n.text(.battery), value: diagnostics.batteryPercent.map { "\($0)%" } ?? l10n.text(.unknown))
            LabeledContent(l10n.text(.powerSource), value: diagnostics.powerSource ?? l10n.text(.unknown))
        } else {
            Text(l10n.text(.diagnosticsUnavailable))
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

    private func updateLanguage(_ language: AppLanguage) {
        var settings = settingsStore.settings
        settings.appLanguage = language
        settingsStore.settings = settings
        onLanguageChanged()
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
        guard let value else { return L10n(language: appLanguage).text(.unknown) }
        return value ? trueText : falseText
    }
}
