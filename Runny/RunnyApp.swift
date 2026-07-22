import SwiftUI

@main
struct RunnyApp: App {
    @State private var store = RunStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
