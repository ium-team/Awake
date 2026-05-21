import Foundation
import IOKit
import IOKit.pwr_mgt

final class ScreenLockController {
    private static let clamshellStateChangeMessage = UInt32(0xe0034100)

    private var rootDomain: io_connect_t = 0
    private var notificationPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var isMonitoring = false

    func startMonitoring(settings: AwakeSettings) {
        guard settings.forceLidClosedAwake, settings.lockScreenForLidClosedAwake, !isMonitoring else { return }

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
                controller.handlePowerMessage(type: messageType, argument: messageArgument)
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
            isMonitoring = true
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

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

        enforceImmediatePasswordRequirement()
        try? startScreenSaver()
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

    deinit {
        stopMonitoring()
    }
}
