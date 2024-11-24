import Foundation
import SwiftUI

struct SettingsView: View {
    private enum Tabs: Hashable {
        case serialPort
    }
    var body: some View {
        TabView {
            SerialPortSettings()
                .tabItem {
                    Label("Chip Programmer", systemImage: "memorychip")
                }
                .tag(Tabs.serialPort)
        }
        .padding(20)

#if os(macOS)
        .frame(width: 600, height: 400)
#endif
    }
}

#Preview {
    SettingsView()
}
