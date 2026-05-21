import Darwin
import Foundation

final class ProcessMonitor {
    func isRunning(pid: pid_t) -> Bool {
        if kill(pid, 0) == 0 {
            return true
        }
        return errno != ESRCH
    }
}
