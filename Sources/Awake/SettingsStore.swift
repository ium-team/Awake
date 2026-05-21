import Foundation

final class SettingsStore {
    private enum Key {
        static let preventDisplaySleep = "preventDisplaySleep"
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
                showCompletionNotification: defaults.bool(forKey: Key.showCompletionNotification),
                launchAtLogin: defaults.bool(forKey: Key.launchAtLogin)
            )
        }
        set {
            defaults.set(newValue.preventDisplaySleep, forKey: Key.preventDisplaySleep)
            defaults.set(newValue.showCompletionNotification, forKey: Key.showCompletionNotification)
            defaults.set(newValue.launchAtLogin, forKey: Key.launchAtLogin)
        }
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.preventDisplaySleep: AwakeSettings.defaults.preventDisplaySleep,
            Key.showCompletionNotification: AwakeSettings.defaults.showCompletionNotification,
            Key.launchAtLogin: AwakeSettings.defaults.launchAtLogin
        ])
    }
}
