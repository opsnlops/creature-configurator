
import SwiftUI

@main
struct CreatureConfigurator: App {

    // There should only ever be one of these
    @StateObject private var serialManager = SerialDeviceManagerWrapper()

    init () {

        // Register the default prefs
        let defaultPreferences: [String: Any] = [
               "programmerSerialPort": "/dev/cu.usbmodem1420",
               "programmerSerialBaud": 19200
            ]
        UserDefaults.standard.register(defaults: defaultPreferences)
    }

    var body: some Scene {

        WindowGroup {
            ContentView()
        }
        .environmentObject(serialManager)

        Settings {
            SettingsView()
        }
    }
}
