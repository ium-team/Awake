import Foundation

final class LidClosedSleepController {
    private let commandURL = URL(fileURLWithPath: "/tmp/awake-lid-closed-enabled")
    private let helperPath = "/Library/PrivilegedHelperTools/com.awake.lid-helper.sh"
    private let daemonPath = "/Library/LaunchDaemons/com.awake.lid-helper.plist"

    func startIfNeeded(settings: AwakeSettings) throws {
        guard settings.forceLidClosedAwake else { return }
        if !isHelperInstalled() {
            try installHelper()
        }
        FileManager.default.createFile(atPath: commandURL.path, contents: Data())
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
        if !isHelperInstalled() {
            try setSleepDisabled(false)
        }
    }

    func isSleepDisabled() -> Bool {
        guard let output = try? runProcess(path: "/usr/bin/pmset", arguments: ["-g"]) else {
            return false
        }

        return output
            .split(separator: "\n")
            .contains { line in
                line.trimmingCharacters(in: .whitespaces).hasPrefix("SleepDisabled")
                    && line.contains("1")
            }
    }

    private func isHelperInstalled() -> Bool {
        FileManager.default.fileExists(atPath: helperPath)
            && FileManager.default.fileExists(atPath: daemonPath)
    }

    private func installHelper() throws {
        let shellCommand = """
        /bin/mkdir -p /Library/PrivilegedHelperTools
        /bin/cat > \(shellQuote(helperPath)) <<'AWAKE_HELPER'
        #!/bin/sh
        command_file="/tmp/awake-lid-closed-enabled"
        owned_file="/tmp/awake-lid-closed-owned"

        while true; do
          if [ -e "$command_file" ]; then
            if ! /usr/bin/pmset -g | /usr/bin/grep -q "SleepDisabled[[:space:]]*1"; then
              /usr/bin/pmset -a disablesleep 1
            fi
            /usr/bin/touch "$owned_file"
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
        /bin/launchctl bootout system \(shellQuote(daemonPath)) >/dev/null 2>&1 || true
        /bin/launchctl bootstrap system \(shellQuote(daemonPath))
        """
        let script = "do shell script \"\(escapeForAppleScript(shellCommand))\" with administrator privileges"
        _ = try runProcess(path: "/usr/bin/osascript", arguments: ["-e", script])
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
}

enum LidClosedSleepError: LocalizedError {
    case commandFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            let detail = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "Could not update macOS lid-close sleep setting."
            }
            return "Could not update macOS lid-close sleep setting. \(detail)"
        }
    }
}
