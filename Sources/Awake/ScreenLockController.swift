import Foundation
import IOKit
import IOKit.pwr_mgt

@MainActor
final class ScreenLockController {
    private static let clamshellStateChangeMessage = UInt32(0xe0034100)

    private var rootDomain: io_connect_t = 0
    private var notificationPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var pollTimer: Timer?
    private var isMonitoring = false
    private var hasLockedForCurrentClosure = false

    func startMonitoring(settings: AwakeSettings) {
        guard settings.forceLidClosedAwake, settings.lockScreenForLidClosedAwake, !isMonitoring else { return }
        enforceImmediatePasswordRequirement()
        isMonitoring = true
        startPollingClamshellState()

        rootDomain = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
        guard rootDomain != 0 else { return }

        guard let notificationPort = IONotificationPortCreate(kIOMainPortDefault) else {
            IOServiceClose(rootDomain)
            rootDomain = 0
            return
        }

        self.notificationPort = notificationPort
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let result = IOServiceAddInterestNotification(
            notificationPort,
            rootDomain,
            kIOGeneralInterest,
            { refcon, _, messageType, messageArgument in
                guard let refcon else { return }
                let controller = Unmanaged<ScreenLockController>
                    .fromOpaque(refcon)
                    .takeUnretainedValue()
                Task { @MainActor in
                    controller.handlePowerMessage(type: messageType, argument: messageArgument)
                }
            },
            refcon,
            &notifier
        )

        guard result == kIOReturnSuccess else {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
            IOServiceClose(rootDomain)
            rootDomain = 0
            return
        }

        if let runLoopSource = IONotificationPortGetRunLoopSource(notificationPort)?.takeUnretainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        pollTimer?.invalidate()
        pollTimer = nil
        hasLockedForCurrentClosure = false

        if let notificationPort,
           let runLoopSource = IONotificationPortGetRunLoopSource(notificationPort)?.takeUnretainedValue() {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if notifier != 0 {
            IOObjectRelease(notifier)
            notifier = 0
        }

        if let notificationPort {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }

        if rootDomain != 0 {
            IOServiceClose(rootDomain)
            rootDomain = 0
        }

        isMonitoring = false
    }

    private func handlePowerMessage(type: UInt32, argument: UnsafeMutableRawPointer?) {
        guard type == Self.clamshellStateChangeMessage else { return }

        let flags = UInt(bitPattern: argument)
        guard flags & UInt(kClamshellStateBit) != 0 else { return }

        lockForLidClose()
    }

    private func startPollingClamshellState() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollClamshellState()
            }
        }
        pollTimer?.tolerance = 0.2
        pollClamshellState()
    }

    private func pollClamshellState() {
        guard let isClosed = readClamshellState() else { return }

        if isClosed {
            lockForLidClose()
        } else {
            hasLockedForCurrentClosure = false
        }
    }

    private func lockForLidClose() {
        guard !hasLockedForCurrentClosure else { return }
        hasLockedForCurrentClosure = true
        enforceImmediatePasswordRequirement()
        try? turnDisplayOff()
        try? startScreenSaver()
    }

    private func readClamshellState() -> Bool? {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-r", "-k", "AppleClamshellState", "-d", "1"]
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let output = String(
            data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        if output.contains("\"AppleClamshellState\" = Yes") {
            return true
        }

        if output.contains("\"AppleClamshellState\" = No") {
            return false
        }

        return nil
    }

    private func enforceImmediatePasswordRequirement() {
        let commands = [
            ["-currentHost", "write", "com.apple.screensaver", "askForPassword", "-int", "1"],
            ["-currentHost", "write", "com.apple.screensaver", "askForPasswordDelay", "-int", "0"]
        ]

        for arguments in commands {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            process.arguments = arguments
            try? process.run()
            process.waitUntilExit()
        }
    }

    private func startScreenSaver() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [
            "/System/Library/CoreServices/ScreenSaverEngine.app"
        ]
        try process.run()
    }

    private func turnDisplayOff() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try process.run()
    }
}
