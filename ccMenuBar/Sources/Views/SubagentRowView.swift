import SwiftUI

struct SubagentRowView: View {
    let session: ClaudeSession
    let isLast: Bool
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 0) {
            // Tree connector
            Text(isLast ? "└" : "├")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 20)
                .padding(.leading, 16)

            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .opacity(isPulsing ? 0.4 : 1.0)
                .animation(
                    session.status == .busy
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: isPulsing
                )
                .padding(.trailing, 6)

            // Project name
            Text(session.projectName)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.primary)

            // Tool name
            if let tool = session.toolName {
                Text("· \(tool)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }

            Spacer()

            Text(session.relativeTime)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .padding(.trailing, 8)
        .onAppear {
            if session.status == .busy {
                isPulsing = true
            }
        }
        .onChange(of: session.status) { _, newValue in
            isPulsing = newValue == .busy
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .busy: return .orange
        case .active: return .green
        case .idle: return .green
        case .stale: return .gray
        }
    }
}
