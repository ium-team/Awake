import Foundation

final class SettingsStore {
    private enum Key {
        static let preventDisplaySleep = "preventDisplaySleep"
        static let showCompletionNotification = "showCompletionNotification"
        static let monitorInterval = "monitorInterval"
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
                monitorInterval: defaults.double(forKey: Key.monitorInterval)
            )
        }
        set {
            defaults.set(newValue.preventDisplaySleep, forKey: Key.preventDisplaySleep)
            defaults.set(newValue.showCompletionNotification, forKey: Key.showCompletionNotification)
            defaults.set(newValue.monitorInterval, forKey: Key.monitorInterval)
        }
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.preventDisplaySleep: AwakeSettings.defaults.preventDisplaySleep,
            Key.showCompletionNotification: AwakeSettings.defaults.showCompletionNotification,
            Key.monitorInterval: AwakeSettings.defaults.monitorInterval
        ])
    }
}
