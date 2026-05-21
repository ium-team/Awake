import Foundation

@MainActor
final class SessionController {
    private let powerController: PowerAssertionController
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

    init(
        powerController: PowerAssertionController,
        processMonitor: ProcessMonitor,
        settingsStore: SettingsStore
    ) {
        self.powerController = powerController
        self.processMonitor = processMonitor
        self.settingsStore = settingsStore
    }

    func start(targets: [AwakeTarget]) {
        guard !targets.isEmpty else { return }

        let session = AwakeSession(id: UUID(), startedAt: Date(), targets: targets)
        do {
            try powerController.start(
                preventDisplaySleep: settingsStore.settings.preventDisplaySleep,
                reason: "Awake is keeping selected apps running"
            )
            state = .active(session)
            startTimer()
        } catch {
            stopTimer()
            powerController.stop()
            state = .error(error.localizedDescription)
        }
    }

    func stopManually() {
        stopTimer()
        powerController.stop()
        state = .idle
    }

    func stopForQuit() {
        stopTimer()
        powerController.stop()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: settingsStore.settings.monitorInterval, repeats: true) { [weak self] _ in
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

        guard !anyRunning else { return }

        stopTimer()
        powerController.stop()
        state = .idle
        onAutoStopped?(session)
    }
}
