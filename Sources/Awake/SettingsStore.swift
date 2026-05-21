import Foundation

final class SettingsStore {
    private enum Key {
        static let preventDisplaySleep = "preventDisplaySleep"
        static let supportClosedDisplayMode = "supportClosedDisplayMode"
        static let forceLidClosedAwake = "forceLidClosedAwake"
        static let lockScreenForLidClosedAwake = "lockScreenForLidClosedAwake"
        static let maximumLidClosedSessionMinutes = "maximumLidClosedSessionMinutes"
        static let stopLidClosedSessionAtBatteryPercent = "stopLidClosedSessionAtBatteryPercent"
        static let showCompletionNotification = "showCompletionNotification"
        static let launchAtLogin = "launchAtLogin"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    var settings: AwakeSettings {
        get {
            AwakeSettings(
                preventDisplaySleep: defaults.bool(forKey: Key.preventDisplaySleep),
                supportClosedDisplayMode: defaults.bool(forKey: Key.supportClosedDisplayMode),
                forceLidClosedAwake: defaults.bool(forKey: Key.forceLidClosedAwake),
                lockScreenForLidClosedAwake: defaults.bool(forKey: Key.lockScreenForLidClosedAwake),
                maximumLidClosedSessionMinutes: defaults.integer(forKey: Key.maximumLidClosedSessionMinutes),
                stopLidClosedSessionAtBatteryPercent: defaults.integer(forKey: Key.stopLidClosedSessionAtBatteryPercent),
                showCompletionNotification: defaults.bool(forKey: Key.showCompletionNotification),
                launchAtLogin: defaults.bool(forKey: Key.launchAtLogin)
            )
        }
        set {
            defaults.set(newValue.preventDisplaySleep, forKey: Key.preventDisplaySleep)
            defaults.set(newValue.supportClosedDisplayMode, forKey: Key.supportClosedDisplayMode)
            defaults.set(newValue.forceLidClosedAwake, forKey: Key.forceLidClosedAwake)
            defaults.set(newValue.lockScreenForLidClosedAwake, forKey: Key.lockScreenForLidClosedAwake)
            defaults.set(newValue.maximumLidClosedSessionMinutes, forKey: Key.maximumLidClosedSessionMinutes)
            defaults.set(newValue.stopLidClosedSessionAtBatteryPercent, forKey: Key.stopLidClosedSessionAtBatteryPercent)
            defaults.set(newValue.showCompletionNotification, forKey: Key.showCompletionNotification)
            defaults.set(newValue.launchAtLogin, forKey: Key.launchAtLogin)
        }
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.preventDisplaySleep: AwakeSettings.defaults.preventDisplaySleep,
            Key.supportClosedDisplayMode: AwakeSettings.defaults.supportClosedDisplayMode,
            Key.forceLidClosedAwake: AwakeSettings.defaults.forceLidClosedAwake,
            Key.lockScreenForLidClosedAwake: AwakeSettings.defaults.lockScreenForLidClosedAwake,
            Key.maximumLidClosedSessionMinutes: AwakeSettings.defaults.maximumLidClosedSessionMinutes,
            Key.stopLidClosedSessionAtBatteryPercent: AwakeSettings.defaults.stopLidClosedSessionAtBatteryPercent,
            Key.showCompletionNotification: AwakeSettings.defaults.showCompletionNotification,
            Key.launchAtLogin: AwakeSettings.defaults.launchAtLogin
        ])
    }
}
