import SwiftUI

struct SessionListView: View {
    let viewModel: MenuBarViewModel
    @State private var showStale = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "terminal")
                    .font(.title3)
                Text("Claude Code")
                    .font(.headline)
                Spacer()
                Text(viewModel.statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Session list
            if viewModel.activeSessions.isEmpty && viewModel.staleSessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No active sessions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.activeSessions) { session in
                            SessionRowView(session: session)
                            if session.id != viewModel.activeSessions.last?.id {
                                Divider().padding(.leading, 26)
                            }
                        }

                        // Stale sessions (collapsible)
                        if !viewModel.staleSessions.isEmpty {
                            Divider()
                            Button {
                                withAnimation { showStale.toggle() }
                            } label: {
                                HStack {
                                    Text("Stale (\(viewModel.staleSessions.count))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Image(systemName: showStale ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if showStale {
                                ForEach(viewModel.staleSessions) { session in
                                    SessionRowView(session: session)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
            }
        }
        .frame(width: 320)
    }
}
