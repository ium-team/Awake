import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private let loginItemController = LoginItemController()
    private let appProvider = RunningAppProvider()
    private let notificationController = NotificationController()
    private lazy var sessionController = SessionController(
        powerController: PowerAssertionController(),
        processMonitor: ProcessMonitor(),
        settingsStore: settingsStore
    )

    private var statusItem: NSStatusItem!
    private var selectionWindowController: SelectionWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var hotKeyController: GlobalHotKeyController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupSessionCallbacks()
        setupHotKey()
        notificationController.requestAuthorizationIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyController?.unregister()
        sessionController.stopForQuit()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "Awake")
        statusItem.button?.imagePosition = .imageLeading
        updateStatusItem(for: .idle)
        rebuildMenu()
    }

    private func setupSessionCallbacks() {
        sessionController.onStateChanged = { [weak self] state in
            self?.updateStatusItem(for: state)
            self?.rebuildMenu()
        }

        sessionController.onAutoStopped = { [weak self] session in
            guard let self else { return }
            if self.settingsStore.settings.showCompletionNotification {
                self.notificationController.notifySessionEnded(targetCount: session.targets.count)
            }
        }
    }

    private func setupHotKey() {
        let controller = GlobalHotKeyController { [weak self] in
            Task { @MainActor in
                self?.showSelectionWindow()
            }
        }
        controller.register()
        hotKeyController = controller
    }

    private func updateStatusItem(for state: SessionState) {
        guard let button = statusItem.button else { return }

        switch state {
        case .idle:
            button.title = ""
            button.image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "Awake idle")
        case .active(let session):
            button.title = " \(session.targets.count)"
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Awake active")
        case .error:
            button.title = " !"
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Awake error")
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        switch sessionController.state {
        case .idle:
            menu.addItem(withTitle: "Keep Apps Awake...", action: #selector(showSelectionWindowAction), keyEquivalent: "")
            menu.addItem(withTitle: "Shortcut: Command-Shift-A", action: nil, keyEquivalent: "").isEnabled = false
        case .active(let session):
            let summary = session.targets.map(\.displayName).joined(separator: ", ")
            let summaryItem = menu.addItem(withTitle: "Keeping \(session.targets.count) app\(session.targets.count == 1 ? "" : "s") awake", action: nil, keyEquivalent: "")
            summaryItem.isEnabled = false
            let targetItem = menu.addItem(withTitle: summary, action: nil, keyEquivalent: "")
            targetItem.isEnabled = false
            menu.addItem(.separator())
            menu.addItem(withTitle: "Stop Keeping Awake", action: #selector(stopSessionAction), keyEquivalent: "")
        case .error(let message):
            let item = menu.addItem(withTitle: message, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(withTitle: "Try Again...", action: #selector(showSelectionWindowAction), keyEquivalent: "")
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings...", action: #selector(showSettingsAction), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Awake", action: #selector(quitAction), keyEquivalent: "q")

        for item in menu.items {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func showSelectionWindowAction() {
        showSelectionWindow()
    }

    private func showSelectionWindow() {
        if selectionWindowController == nil {
            selectionWindowController = SelectionWindowController(appProvider: appProvider) { [weak self] targets in
                self?.sessionController.start(targets: targets)
            }
        }
        selectionWindowController?.showWindow(nil)
    }

    @objc private func stopSessionAction() {
        sessionController.stopManually()
    }

    @objc private func showSettingsAction() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                settingsStore: settingsStore,
                loginItemController: loginItemController
            )
        }
        settingsWindowController?.showWindow(nil)
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
