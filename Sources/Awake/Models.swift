import AppKit
import Foundation

struct RunningWindow: Hashable {
    let id: UInt32
    let title: String
    let ownerPID: pid_t
}

struct RunningApp: Hashable {
    let pid: pid_t
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage?
    let windows: [RunningWindow]
}

struct AwakeTarget: Hashable {
    let pid: pid_t
    let bundleIdentifier: String?
    let displayName: String
}

struct AwakeSettings {
    var preventDisplaySleep: Bool
    var showCompletionNotification: Bool
    var launchAtLogin: Bool

    static let monitorInterval: TimeInterval = 5

    static let defaults = AwakeSettings(
        preventDisplaySleep: false,
        showCompletionNotification: true,
        launchAtLogin: false
    )
}

enum SessionState: Equatable {
    case idle
    case active(AwakeSession)
    case error(String)
}

struct AwakeSession: Equatable {
    let id: UUID
    let startedAt: Date
    let targets: [AwakeTarget]
}
