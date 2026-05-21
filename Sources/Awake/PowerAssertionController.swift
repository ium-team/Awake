import Foundation
import IOKit.pwr_mgt

final class PowerAssertionController {
    private var userIdleSystemSleepAssertion: IOPMAssertionID = 0
    private var displaySleepAssertion: IOPMAssertionID = 0
    private var networkClientAssertion: IOPMAssertionID = 0

    var isActive: Bool {
        userIdleSystemSleepAssertion != 0 || displaySleepAssertion != 0 || networkClientAssertion != 0
    }

    func start(settings: AwakeSettings, reason: String) throws {
        if isActive {
            stop()
        }

        let userIdleSystemResult = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &userIdleSystemSleepAssertion
        )

        guard userIdleSystemResult == kIOReturnSuccess else {
            userIdleSystemSleepAssertion = 0
            throw PowerAssertionError.createFailed(code: userIdleSystemResult)
        }

        if settings.preventDisplaySleep {
            do {
                try createDisplaySleepAssertion(reason: reason)
                if settings.supportClosedDisplayMode {
                    try createNetworkClientAssertion(reason: reason)
                }
            } catch {
                stop()
                throw error
            }
        }
    }

    func update(settings: AwakeSettings, reason: String) throws {
        guard isActive else { return }

        if settings.preventDisplaySleep {
            try createDisplaySleepAssertion(reason: reason)
            if settings.supportClosedDisplayMode {
                try createNetworkClientAssertion(reason: reason)
            } else {
                releaseNetworkClientAssertion()
            }
        } else if displaySleepAssertion != 0 {
            IOPMAssertionRelease(displaySleepAssertion)
            displaySleepAssertion = 0
            releaseNetworkClientAssertion()
        }
    }

    func stop() {
        if userIdleSystemSleepAssertion != 0 {
            IOPMAssertionRelease(userIdleSystemSleepAssertion)
            userIdleSystemSleepAssertion = 0
        }

        if displaySleepAssertion != 0 {
            IOPMAssertionRelease(displaySleepAssertion)
            displaySleepAssertion = 0
        }

        releaseNetworkClientAssertion()
    }

    deinit {
        stop()
    }

    private func createDisplaySleepAssertion(reason: String) throws {
        guard displaySleepAssertion == 0 else { return }

        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &displaySleepAssertion
        )

        guard displayResult == kIOReturnSuccess else {
            displaySleepAssertion = 0
            throw PowerAssertionError.createFailed(code: displayResult)
        }
    }

    private func createNetworkClientAssertion(reason: String) throws {
        guard networkClientAssertion == 0 else { return }

        let networkClientResult = IOPMAssertionCreateWithName(
            kIOPMAssertNetworkClientActive as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &networkClientAssertion
        )

        guard networkClientResult == kIOReturnSuccess else {
            networkClientAssertion = 0
            throw PowerAssertionError.createFailed(code: networkClientResult)
        }
    }

    private func releaseNetworkClientAssertion() {
        if networkClientAssertion != 0 {
            IOPMAssertionRelease(networkClientAssertion)
            networkClientAssertion = 0
        }
    }
}

enum PowerAssertionError: LocalizedError {
    case createFailed(code: IOReturn)

    var errorDescription: String? {
        switch self {
        case .createFailed(let code):
            "Could not create macOS power assertion. IOKit returned \(code)."
        }
    }
}
