import Foundation

final class SettingsStore {
    private enum Key {
        static let preventDisplaySleep = "preventDisplaySleep"
        static let supportClosedDisplayMode = "supportClosedDisplayMode"
        static let forceLidClosedAwake = "forceLidClosedAwake"
        static let lockScreenForLidClosedAwake = "lockScreenForLidClosedAwake"
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
                showCompletionNotification: defaults.bool(forKey: Key.showCompletionNotification),
                launchAtLogin: defaults.bool(forKey: Key.launchAtLogin)
            )
        }
        set {
            defaults.set(newValue.preventDisplaySleep, forKey: Key.preventDisplaySleep)
            defaults.set(newValue.supportClosedDisplayMode, forKey: Key.supportClosedDisplayMode)
            defaults.set(newValue.forceLidClosedAwake, forKey: Key.forceLidClosedAwake)
            defaults.set(newValue.lockScreenForLidClosedAwake, forKey: Key.lockScreenForLidClosedAwake)
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
            Key.showCompletionNotification: AwakeSettings.defaults.showCompletionNotification,
            Key.launchAtLogin: AwakeSettings.defaults.launchAtLogin
        ])
    }
}
