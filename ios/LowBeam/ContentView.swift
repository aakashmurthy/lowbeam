import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connection: ConnectionManager
    @EnvironmentObject private var store: PackStore
    @EnvironmentObject private var scripts: ScriptStore

    @AppStorage("hasOnboarded") private var hasOnboarded = false

    @State private var showConnect = false
    @State private var showWelcome = false
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            GarageView(showConnect: $showConnect)
                .tabItem { Label("Garage", systemImage: "car.fill") }
                .tag(0)

            ScriptsView()
                .tabItem { Label("Scripts", systemImage: "play.circle.fill") }
                .tag(1)

            BuildView()
                .tabItem { Label("Build", systemImage: "slider.horizontal.3") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(LBTheme.accent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showConnect) {
            ConnectView()
        }
        .fullScreenCover(isPresented: $showWelcome) {
            WelcomeView(
                onConnect: {
                    hasOnboarded = true
                    showWelcome = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showConnect = true
                    }
                },
                onOffline: {
                    hasOnboarded = true
                    showWelcome = false
                }
            )
            .interactiveDismissDisabled()
        }
        .onAppear {
            if !hasOnboarded {
                showWelcome = true
            }
        }
    }
}
