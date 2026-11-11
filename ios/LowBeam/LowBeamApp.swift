import SwiftUI

@main
struct LowBeamApp: App {
    @StateObject private var store: PackStore
    @StateObject private var scripts: ScriptStore
    @StateObject private var connection: ConnectionManager

    init() {
        let store = PackStore()
        _store = StateObject(wrappedValue: store)
        _scripts = StateObject(wrappedValue: ScriptStore())
        _connection = StateObject(wrappedValue: ConnectionManager(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(scripts)
                .environmentObject(connection)
        }
    }
}
