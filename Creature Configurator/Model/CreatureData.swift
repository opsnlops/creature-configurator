
import Foundation

/**
 Very simple struct that contains the data we need
 */
struct CreatureData: Hashable, Equatable, Sendable {

    var usbVID: String = "2E8A"
    var usbPID: String = ""
    var versionMajor: Int = 1
    var versionMinor: Int = 0
    var loggingLevel: Int = 3
    var serialNumber: String = ""
    var productName: String = ""
    var manufacturer: String = "April's Creature Workshop"
    var customStrings: [String] = [] // Start with zero custom strings

}
