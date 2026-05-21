import Foundation
@testable import Awake

let awakeSettingsStoreValidation: Void = {
    let defaults = makeIsolatedDefaults()
    let store = SettingsStore(defaults: defaults)
    let settings = store.settings

    precondition(settings.appLanguage == .system)
    precondition(settings.preventDisplaySleep)
    precondition(settings.supportClosedDisplayMode)
    precondition(settings.forceLidClosedAwake)
    precondition(settings.lockScreenForLidClosedAwake)
    precondition(settings.maximumLidClosedSessionMinutes == 240)
    precondition(settings.stopLidClosedSessionAtBatteryPercent == 20)
    precondition(settings.showCompletionNotification)
    precondition(!settings.launchAtLogin)

    var changedSettings = settings
    changedSettings.appLanguage = .ko
    changedSettings.maximumLidClosedSessionMinutes = 90
    changedSettings.stopLidClosedSessionAtBatteryPercent = 35
    store.settings = changedSettings

    let reloadedStore = SettingsStore(defaults: defaults)
    precondition(reloadedStore.settings.appLanguage == .ko)
    precondition(reloadedStore.settings.maximumLidClosedSessionMinutes == 90)
    precondition(reloadedStore.settings.stopLidClosedSessionAtBatteryPercent == 35)
}()

private func makeIsolatedDefaults() -> UserDefaults {
    let suiteName = "AwakeTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
