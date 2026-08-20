import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Text("Home")
                .tabItem { Label("Home", systemImage: "house") }

            Text("Transactions")
                .tabItem { Label("Transactions", systemImage: "list.bullet") }

            Text("Plan")
                .tabItem { Label("Plan", systemImage: "calendar") }

            Text("Insights")
                .tabItem { Label("Insights", systemImage: "chart.bar") }

            Text("Settings")
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
