import SwiftUI

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
