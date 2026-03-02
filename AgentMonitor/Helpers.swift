import SwiftUI
import Foundation

/// Standard PATH for shell processes — Finder-launched apps have a minimal PATH
/// that doesn't include Homebrew or user-local bins.
let shellPATH: String = {
    // Start with the current environment PATH (works when launched from terminal)
    var paths = (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        .split(separator: ":").map(String.init)

    // Ensure common tool locations are included
    let extras = [
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "\(NSHomeDirectory())/.local/bin",
        "\(NSHomeDirectory())/.nvm/current/bin"
    ]
    for p in extras where !paths.contains(p) {
        paths.append(p)
    }
    return paths.joined(separator: ":")
}()

/// Configure a Process with the full PATH so it can find gh, claude, etc.
func configureProcess(_ process: Process) {
    var env = ProcessInfo.processInfo.environment
    env["PATH"] = shellPATH
    process.environment = env
}

func timeAgo(_ date: Date) -> String {
    let seconds = Int(Date().timeIntervalSince(date))
    if seconds < 10 {
        return "just now"
    } else if seconds < 60 {
        return "\(seconds)s ago"
    } else {
        let minutes = seconds / 60
        return "\(minutes)m ago"
    }
}

struct StatusIndicator: View {
    let isLoading: Bool

    var body: some View {
        Circle()
            .fill(isLoading ? Color.yellow : Color.green)
            .frame(width: 8, height: 8)
    }
}
