import SwiftUI

/// Three tabs: Home (lockmaster picker → session setup), History, Settings.
struct MainTabView: View {
    @EnvironmentObject var session: SessionEngine

    var body: some View {
        TabView {
            NavigationStack {
                LockmasterPickerView()
            }
            .tabItem { Label("Home", systemImage: "lock.fill") }

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Palette.brass)
    }
}
