import SwiftUI

@main
struct PeppyApp: App {
    @State private var dependencies = Dependencies.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .withDependencies(dependencies)
                .preferredColorScheme(.dark)
        }
    }
}
