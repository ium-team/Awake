import Foundation
import IOKit.pwr_mgt

final class PowerAssertionController {
    private var idleSleepAssertion: IOPMAssertionID = 0
    private var displaySleepAssertion: IOPMAssertionID = 0

    var isActive: Bool {
        idleSleepAssertion != 0 || displaySleepAssertion != 0
    }

    func start(preventDisplaySleep: Bool, reason: String) throws {
        if isActive {
            stop()
        }

        let idleResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &idleSleepAssertion
        )

        guard idleResult == kIOReturnSuccess else {
            idleSleepAssertion = 0
            throw PowerAssertionError.createFailed(code: idleResult)
        }

        if preventDisplaySleep {
            let displayResult = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &displaySleepAssertion
            )

            guard displayResult == kIOReturnSuccess else {
                stop()
                throw PowerAssertionError.createFailed(code: displayResult)
            }
        }
    }

    func stop() {
        if idleSleepAssertion != 0 {
            IOPMAssertionRelease(idleSleepAssertion)
            idleSleepAssertion = 0
        }

        if displaySleepAssertion != 0 {
            IOPMAssertionRelease(displaySleepAssertion)
            displaySleepAssertion = 0
        }
    }

    deinit {
        stop()
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
