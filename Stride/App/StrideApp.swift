import SwiftUI

@main
struct StrideApp: App {
    @State private var store: RunStore

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            // UI tests start with an empty, temporary history.
            let url = URL.temporaryDirectory.appending(path: "stride-uitest.json")
            try? FileManager.default.removeItem(at: url)
            _store = State(initialValue: RunStore(storage: RunStorage(fileURL: url)))
        } else {
            _store = State(initialValue: RunStore())
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Runs", systemImage: "figure.run") {
                RunsView()
            }
            Tab("Insights", systemImage: "chart.bar.xaxis") {
                InsightsView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    let store = RunStore(storage: RunStorage(fileURL: URL.temporaryDirectory.appending(path: "preview.json")))
    store.loadSampleData()
    return ContentView().environment(store)
}
