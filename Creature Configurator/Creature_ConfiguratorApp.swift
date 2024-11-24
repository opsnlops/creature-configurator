
import SwiftUI

@main
struct CreatureConfigurator: App {


    init () {

        // Register the default prefs
        let defaultPreferences: [String: Any] = [
               "programmerSerialPort": "/dev/cu.usbmodem1420",
               "programmerSerialBaud": 115200
            ]
        UserDefaults.standard.register(defaults: defaultPreferences)
    }

    var body: some Scene {

        WindowGroup {
            ContentView()
        }

        Settings {
            SettingsView()
        }
    }
}
