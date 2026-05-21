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
    var appLanguage: AppLanguage
    var preventDisplaySleep: Bool
    var supportClosedDisplayMode: Bool
    var forceLidClosedAwake: Bool
    var lockScreenForLidClosedAwake: Bool
    var maximumLidClosedSessionMinutes: Int
    var stopLidClosedSessionAtBatteryPercent: Int
    var showCompletionNotification: Bool
    var launchAtLogin: Bool

    static let monitorInterval: TimeInterval = 5

    static let defaults = AwakeSettings(
        appLanguage: .system,
        preventDisplaySleep: true,
        supportClosedDisplayMode: true,
        forceLidClosedAwake: true,
        lockScreenForLidClosedAwake: true,
        maximumLidClosedSessionMinutes: 240,
        stopLidClosedSessionAtBatteryPercent: 20,
        showCompletionNotification: true,
        launchAtLogin: false
    )
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case ko
    case zhHans
    case ja
    case en

    var id: String { rawValue }

    var effectiveCode: String {
        switch self {
        case .system:
            return Self.resolveSystemLanguageCode()
        case .ko:
            return "ko"
        case .zhHans:
            return "zh-Hans"
        case .ja:
            return "ja"
        case .en:
            return "en"
        }
    }

    private static func resolveSystemLanguageCode() -> String {
        let preferredLanguages = Locale.preferredLanguages
        for language in preferredLanguages {
            let normalized = language.replacingOccurrences(of: "_", with: "-").lowercased()
            if normalized.hasPrefix("ko") { return "ko" }
            if normalized.hasPrefix("zh") { return "zh-Hans" }
            if normalized.hasPrefix("ja") { return "ja" }
            if normalized.hasPrefix("en") { return "en" }
        }
        return "en"
    }
}

struct AwakeDiagnostics {
    let helperInstalled: Bool
    let sleepDisabled: Bool
    let lidClosed: Bool?
    let batteryPercent: Int?
    let powerSource: String?
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
