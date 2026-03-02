import SwiftUI

struct DiffView: View {
    let diffText: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(diffText.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    DiffLineView(line: line)
                }
            }
            .padding()
        }
        .background(Color(NSColor.textBackgroundColor))
        .textSelection(.enabled)
    }
}

private struct DiffLineView: View {
    let line: String

    var body: some View {
        Text(line.isEmpty ? " " : line)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .background(backgroundColor)
    }

    private var foregroundColor: Color {
        if line.hasPrefix("+++") || line.hasPrefix("---") {
            return .orange
        } else if line.hasPrefix("+") {
            return Color(.systemGreen)
        } else if line.hasPrefix("-") {
            return Color(.systemRed)
        } else if line.hasPrefix("@@") {
            return .cyan
        } else if line.hasPrefix("diff --git") {
            return .orange
        } else if line.hasPrefix("===") {
            return .purple
        } else {
            return .primary
        }
    }

    private var backgroundColor: Color {
        if line.hasPrefix("+++") || line.hasPrefix("---") {
            return Color.orange.opacity(0.08)
        } else if line.hasPrefix("+") {
            return Color.green.opacity(0.08)
        } else if line.hasPrefix("-") {
            return Color.red.opacity(0.08)
        } else if line.hasPrefix("@@") {
            return Color.cyan.opacity(0.08)
        } else if line.hasPrefix("diff --git") {
            return Color.orange.opacity(0.08)
        } else if line.hasPrefix("===") {
            return Color.purple.opacity(0.08)
        } else {
            return .clear
        }
    }
}
