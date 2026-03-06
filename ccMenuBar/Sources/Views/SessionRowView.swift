import SwiftUI

struct SessionRowView: View {
    let session: ClaudeSession
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 10) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .opacity(isPulsing ? 0.4 : 1.0)
                .animation(
                    session.status == .busy
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: isPulsing
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.projectName)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)

                    if let branch = session.gitBranch {
                        Text(branch)
                            .font(.caption)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 4) {
                    Text(session.status.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let tool = session.toolName {
                        Text("· \(tool)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(session.relativeTime)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
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
