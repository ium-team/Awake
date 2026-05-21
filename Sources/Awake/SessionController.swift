import Foundation

@MainActor
final class SessionController {
    private static let assertionReason = "Awake is keeping selected apps running"

    private let powerController: PowerAssertionController
    private let lidClosedSleepController: LidClosedSleepController
    private let screenLockController: ScreenLockController
    private let processMonitor: ProcessMonitor
    private let settingsStore: SettingsStore
    private var timer: Timer?

    private(set) var state: SessionState = .idle {
        didSet {
            onStateChanged?(state)
        }
    }

    var onStateChanged: ((SessionState) -> Void)?
    var onAutoStopped: ((AwakeSession) -> Void)?
    var onSafetyStopped: ((String) -> Void)?

    init(
        powerController: PowerAssertionController,
        lidClosedSleepController: LidClosedSleepController,
        screenLockController: ScreenLockController,
        processMonitor: ProcessMonitor,
        settingsStore: SettingsStore
    ) {
        self.powerController = powerController
        self.lidClosedSleepController = lidClosedSleepController
        self.screenLockController = screenLockController
        self.processMonitor = processMonitor
        self.settingsStore = settingsStore
    }

    func start(targets: [AwakeTarget]) {
        guard !targets.isEmpty else { return }

        let session = AwakeSession(id: UUID(), startedAt: Date(), targets: targets)
        do {
            try powerController.start(
                settings: settingsStore.settings,
                reason: Self.assertionReason
            )
            try lidClosedSleepController.startIfNeeded(settings: settingsStore.settings)
            state = .active(session)
            startTimer()
            screenLockController.startMonitoring(settings: settingsStore.settings)
        } catch {
            stopTimer()
            powerController.stop()
            lidClosedSleepController.restoreIfNeeded()
            screenLockController.stopMonitoring()
            state = .error(error.localizedDescription)
        }
    }

    func stopManually() {
        stopTimer()
        powerController.stop()
        lidClosedSleepController.restoreIfNeeded()
        screenLockController.stopMonitoring()
        state = .idle
    }

    func refreshPowerSettings() {
        guard case .active = state else { return }

        do {
            try powerController.update(
                settings: settingsStore.settings,
                reason: Self.assertionReason
            )
            try lidClosedSleepController.update(settings: settingsStore.settings)
            screenLockController.stopMonitoring()
            screenLockController.startMonitoring(settings: settingsStore.settings)
        } catch {
            stopTimer()
            powerController.stop()
            lidClosedSleepController.restoreIfNeeded()
            screenLockController.stopMonitoring()
            state = .error(error.localizedDescription)
        }
    }

    func stopForQuit() {
        stopTimer()
        powerController.stop()
        lidClosedSleepController.restoreIfNeeded()
        screenLockController.stopMonitoring()
    }

    func restoreSystemSleep() throws {
        lidClosedSleepController.restoreIfNeeded()
        try lidClosedSleepController.restoreSystemSleep()
    }

    func isSystemSleepDisabled() -> Bool {
        lidClosedSleepController.isSleepDisabled()
    }

    func diagnostics() -> AwakeDiagnostics {
        lidClosedSleepController.diagnostics()
    }

    func installOrRepairHelper() throws {
        try lidClosedSleepController.installOrRepairHelper()
    }

    func uninstallHelper() throws {
        try lidClosedSleepController.uninstallHelper()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: AwakeSettings.monitorInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkTargets()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func checkTargets() {
        guard case .active(let session) = state else { return }

        let anyRunning = session.targets.contains { target in
            processMonitor.isRunning(pid: target.pid)
        }

        guard anyRunning else {
            finishSession(session: session)
            return
        }

        if let stopReason = safetyStopReason(for: session) {
            stopTimer()
            powerController.stop()
            lidClosedSleepController.restoreIfNeeded()
            screenLockController.stopMonitoring()
            state = .idle
            onSafetyStopped?(stopReason)
        }
    }

    private func finishSession(session: AwakeSession) {
        stopTimer()
        powerController.stop()
        lidClosedSleepController.restoreIfNeeded()
        screenLockController.stopMonitoring()
        state = .idle
        onAutoStopped?(session)
    }

    private func safetyStopReason(for session: AwakeSession) -> String? {
        let settings = settingsStore.settings
        guard settings.forceLidClosedAwake else { return nil }

        let elapsedMinutes = Int(Date().timeIntervalSince(session.startedAt) / 60)
        if settings.maximumLidClosedSessionMinutes > 0,
           elapsedMinutes >= settings.maximumLidClosedSessionMinutes {
            return L10n(language: settings.appLanguage).text(.safetyTimeLimitReached)
        }

        let diagnostics = lidClosedSleepController.diagnostics()
        if diagnostics.powerSource?.localizedCaseInsensitiveContains("Battery") == true,
           let batteryPercent = diagnostics.batteryPercent,
           batteryPercent <= settings.stopLidClosedSessionAtBatteryPercent {
            return L10n(language: settings.appLanguage).format(.batteryReached, batteryPercent)
        }

        return nil
    }
}
