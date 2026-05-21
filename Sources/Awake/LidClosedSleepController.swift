import Foundation

final class LidClosedSleepController {
    private static let daemonLabel = "com.awake.lid-helper"
    private static let sleepDisabledPollDeadline: TimeInterval = 6
    private static let sleepDisabledPollInterval: TimeInterval = 0.25

    private let supportDirectoryURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Awake", isDirectory: true)
    private lazy var commandURL = supportDirectoryURL.appendingPathComponent("lid-closed-enabled")
    private lazy var ownedURL = supportDirectoryURL.appendingPathComponent("lid-closed-owned")
    private let helperPath = "/Library/PrivilegedHelperTools/com.awake.lid-helper.sh"
    private let daemonPath = "/Library/LaunchDaemons/com.awake.lid-helper.plist"

    func startIfNeeded(settings: AwakeSettings) throws {
        guard settings.forceLidClosedAwake else { return }
        if !helperReady {
            try installHelper()
        }
        try FileManager.default.createDirectory(
            at: supportDirectoryURL,
            withIntermediateDirectories: true
        )
        try Data().write(to: commandURL, options: .atomic)
        try waitForSleepDisabled(true)
    }

    func update(settings: AwakeSettings) throws {
        if settings.forceLidClosedAwake {
            try startIfNeeded(settings: settings)
        } else {
            restoreIfNeeded()
        }
    }

    func restoreIfNeeded() {
        try? FileManager.default.removeItem(at: commandURL)
    }

    func restoreSystemSleep() throws {
        restoreIfNeeded()
        if helperReady {
            do {
                try waitForSleepDisabled(false)
                return
            } catch {
                try setSleepDisabled(false)
                return
            }
        }
        try setSleepDisabled(false)
    }

    var helperInstalled: Bool {
        FileManager.default.fileExists(atPath: helperPath)
            && FileManager.default.fileExists(atPath: daemonPath)
    }

    private var helperReady: Bool {
        helperInstalled
            && helperUsesCurrentSignalFiles()
            && helperIsLoaded()
    }

    func installOrRepairHelper() throws {
        try installHelper()
    }

    func uninstallHelper() throws {
        restoreIfNeeded()
        let shellCommand = """
        /bin/launchctl bootout system \(shellQuote(daemonPath)) >/dev/null 2>&1 || true
        /usr/bin/pmset -a disablesleep 0
        /bin/rm -f \(shellQuote(helperPath)) \(shellQuote(daemonPath)) \(shellQuote(ownedURL.path)) /tmp/awake-lid-closed-owned /tmp/awake-lid-closed-enabled
        """
        let script = "do shell script \"\(escapeForAppleScript(shellCommand))\" with administrator privileges"
        _ = try runProcess(path: "/usr/bin/osascript", arguments: ["-e", script])
    }

    func diagnostics() -> AwakeDiagnostics {
        let battery = readBatteryState()
        return AwakeDiagnostics(
            helperInstalled: helperReady,
            sleepDisabled: isSleepDisabled(),
            lidClosed: readClamshellState(),
            batteryPercent: battery.percent,
            powerSource: battery.powerSource
        )
    }

    func isSleepDisabled() -> Bool {
        guard let output = try? runProcess(path: "/usr/bin/pmset", arguments: ["-g"]) else {
            return false
        }

        return output
            .split(separator: "\n")
            .contains { line in
                let columns = line.split(whereSeparator: { $0.isWhitespace })
                return columns.first == "SleepDisabled" && columns.last == "1"
            }
    }

    private func installHelper() throws {
        let shellCommand = """
        /bin/mkdir -p /Library/PrivilegedHelperTools
        /bin/cat > \(shellQuote(helperPath)) <<'AWAKE_HELPER'
        #!/bin/sh
        command_file=\(shellQuote(commandURL.path))
        owned_file=\(shellQuote(ownedURL.path))

        while true; do
          if [ -e "$command_file" ]; then
            if ! /usr/bin/pmset -g | /usr/bin/grep -q "SleepDisabled[[:space:]]*1"; then
              /usr/bin/pmset -a disablesleep 1
              /usr/bin/touch "$owned_file"
            fi
          elif [ -e "$owned_file" ]; then
            /usr/bin/pmset -a disablesleep 0
            /bin/rm -f "$owned_file"
          fi
          /bin/sleep 2
        done
        AWAKE_HELPER
        /bin/chmod 755 \(shellQuote(helperPath))
        /bin/cat > \(shellQuote(daemonPath)) <<'AWAKE_PLIST'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>com.awake.lid-helper</string>
          <key>ProgramArguments</key>
          <array>
            <string>/Library/PrivilegedHelperTools/com.awake.lid-helper.sh</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <true/>
        </dict>
        </plist>
        AWAKE_PLIST
        /bin/chmod 644 \(shellQuote(daemonPath))
        /bin/rm -f /tmp/awake-lid-closed-owned /tmp/awake-lid-closed-enabled
        /bin/launchctl bootout system \(shellQuote(daemonPath)) >/dev/null 2>&1 || true
        /bin/launchctl bootstrap system \(shellQuote(daemonPath))
        """
        let script = "do shell script \"\(escapeForAppleScript(shellCommand))\" with administrator privileges"
        _ = try runProcess(path: "/usr/bin/osascript", arguments: ["-e", script])
    }

    private func waitForSleepDisabled(_ expectedValue: Bool) throws {
        let deadline = Date().addingTimeInterval(Self.sleepDisabledPollDeadline)
        while Date() < deadline {
            if isSleepDisabled() == expectedValue {
                return
            }
            Thread.sleep(forTimeInterval: Self.sleepDisabledPollInterval)
        }

        if isSleepDisabled() == expectedValue {
            return
        }

        throw LidClosedSleepError.sleepDisabledStateTimedOut(expected: expectedValue)
    }

    private func helperUsesCurrentSignalFiles() -> Bool {
        guard let script = try? String(contentsOfFile: helperPath, encoding: .utf8) else {
            return false
        }

        return script.contains("command_file=\(shellQuote(commandURL.path))")
            && script.contains("owned_file=\(shellQuote(ownedURL.path))")
    }

    private func helperIsLoaded() -> Bool {
        (try? runProcess(
            path: "/bin/launchctl",
            arguments: ["print", "system/\(Self.daemonLabel)"]
        )) != nil
    }

    private func setSleepDisabled(_ isDisabled: Bool) throws {
        let value = isDisabled ? "1" : "0"
        let shellCommand = "/usr/bin/pmset -a disablesleep \(value)"
        let script = "do shell script \"\(escapeForAppleScript(shellCommand))\" with administrator privileges"
        _ = try runProcess(path: "/usr/bin/osascript", arguments: ["-e", script])
    }

    private func runProcess(path: String, arguments: [String]) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw LidClosedSleepError.commandFailed(message: errorOutput.isEmpty ? output : errorOutput)
        }

        return output
    }

    private func escapeForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func readClamshellState() -> Bool? {
        guard let output = try? runProcess(path: "/usr/sbin/ioreg", arguments: ["-r", "-k", "AppleClamshellState", "-d", "1"]) else {
            return nil
        }

        if output.contains("\"AppleClamshellState\" = Yes") {
            return true
        }

        if output.contains("\"AppleClamshellState\" = No") {
            return false
        }

        return nil
    }

    private func readBatteryState() -> (percent: Int?, powerSource: String?) {
        guard let output = try? runProcess(path: "/usr/bin/pmset", arguments: ["-g", "batt"]) else {
            return (nil, nil)
        }

        let powerSource = output
            .split(separator: "\n")
            .first?
            .replacingOccurrences(of: "Now drawing from ", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "'"))

        let percentText = output
            .split(separator: "\n")
            .first { $0.contains("%") }?
            .split(separator: ";")
            .first?
            .split(separator: "\t")
            .last?
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespaces)
        let percent = percentText.flatMap { Int($0) }

        return (percent, powerSource)
    }
}

enum LidClosedSleepError: LocalizedError {
    case commandFailed(message: String)
    case sleepDisabledStateTimedOut(expected: Bool)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            let detail = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "Could not update macOS lid-close sleep setting."
            }
            return "Could not update macOS lid-close sleep setting. \(detail)"
        case .sleepDisabledStateTimedOut(let expected):
            if expected {
                return "The lid-closed helper did not enable macOS SleepDisabled before the timeout."
            }
            return "The lid-closed helper did not restore macOS SleepDisabled before the timeout."
        }
    }
}
