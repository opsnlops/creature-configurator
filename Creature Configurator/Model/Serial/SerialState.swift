
import Foundation

public enum SerialState: Sendable {
    case connected
    case disconnected
    case connecting

    var description: String {
        switch self {
        case .connected:
            return "Connected"
        case .disconnected:
            return "Not connected"
        case .connecting:
            return "Attempting to connect..."
        }
    }
}
