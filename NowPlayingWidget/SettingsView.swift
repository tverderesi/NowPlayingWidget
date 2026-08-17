import SwiftUI

struct SettingsView: View {
    @State private var snapshot = NowPlayingSnapshot.empty

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Now Playing Widget")
                .font(.title2.bold())

            Text("The helper app runs in the background and feeds the system widget from macOS Now Playing.")
                .foregroundStyle(.secondary)

            Divider()

            LabeledContent("Current track", value: snapshot.title)
            LabeledContent("Artist", value: snapshot.artist ?? "—")
            LabeledContent("Status", value: snapshot.isPlaying ? "Playing" : "Paused / idle")

            HStack {
                Button("Refresh") { refresh() }
                Spacer()
                Button("Quit Helper") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(20)
        .frame(width: 460)
        .task { refresh() }
    }

    private func refresh() {
        NowPlayingBridge.fetch { snapshot = $0 }
    }
}
