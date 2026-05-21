import AppKit
import CoreGraphics
import Foundation

final class RunningAppProvider {
    func snapshot() -> [RunningApp] {
        let windowsByPID = visibleWindowsByPID()

        return NSWorkspace.shared.runningApplications
            .filter { app in
                app.processIdentifier > 0 &&
                app.activationPolicy == .regular &&
                app.bundleIdentifier != Bundle.main.bundleIdentifier
            }
            .map { app in
                let pid = app.processIdentifier
                return RunningApp(
                    pid: pid,
                    name: app.localizedName ?? app.bundleIdentifier ?? "Process \(pid)",
                    bundleIdentifier: app.bundleIdentifier,
                    icon: app.icon,
                    windows: windowsByPID[pid] ?? []
                )
            }
            .sorted { lhs, rhs in
                if lhs.windows.isEmpty != rhs.windows.isEmpty {
                    return !lhs.windows.isEmpty
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func visibleWindowsByPID() -> [pid_t: [RunningWindow]] {
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return [:]
        }

        var windows: [pid_t: [RunningWindow]] = [:]

        for info in infoList {
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                let windowNumber = info[kCGWindowNumber as String] as? UInt32,
                let layer = info[kCGWindowLayer as String] as? Int,
                layer == 0
            else {
                continue
            }

            let title = (info[kCGWindowName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let window = RunningWindow(
                id: windowNumber,
                title: title?.isEmpty == false ? title! : "Untitled Window",
                ownerPID: ownerPID
            )
            windows[ownerPID, default: []].append(window)
        }

        return windows.mapValues { value in
            value.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }
}
