import SwiftUI

@main
struct LowBeamApp: App {
    @StateObject private var store = PackStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
