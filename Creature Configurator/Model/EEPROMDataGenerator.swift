
import Foundation
import os

struct EEPROMDataGenerator {

    static let logger = Logger(subsystem: "creature.engineering.CreatureConfiguratator", category: "EEPROMDataGenerator")


    static public func createEEPROMData(creatureData: CreatureData) -> Result<Data, DataFileError> {

        logger.debug("Creating EEPROM data")
        
        guard let vid = UInt16(creatureData.usbVID, radix: 16), let pid = UInt16(creatureData.usbPID, radix: 16) else {
            logger.error("Invalid USB VID or PID")
            return .failure(.invalidData("Invalid USB VID or PID"))
        }

        logger.debug("Generating binary content")
        let serialData = Array(creatureData.serialNumber.utf8)
        let productData = Array(creatureData.productName.utf8)
        let manufacturerData = Array(creatureData.manufacturer.utf8)

        var binaryData = Data()

        // "HOP!" magic number
        binaryData.append("HOP!".data(using: .ascii)!)

        // VID, PID
        binaryData.append(contentsOf: withUnsafeBytes(of: vid.bigEndian) { Data($0) })
        binaryData.append(contentsOf: withUnsafeBytes(of: pid.bigEndian) { Data($0) })

        // Version (BCD format)
        let versionBCD = UInt16((creatureData.versionMajor << 8) | creatureData.versionMinor)
        binaryData.append(contentsOf: withUnsafeBytes(of: versionBCD.bigEndian) { Data($0) })

        // Logging level
        binaryData.append(UInt8(creatureData.loggingLevel))

        // Serial number
        binaryData.append(UInt8(serialData.count))
        binaryData.append(contentsOf: serialData)

        // Product name
        binaryData.append(UInt8(productData.count))
        binaryData.append(contentsOf: productData)

        // Manufacturer
        binaryData.append(UInt8(manufacturerData.count))
        binaryData.append(contentsOf: manufacturerData)

        // Append custom strings if they exist
        for customString in creatureData.customStrings {
            let stringData = Array(customString.utf8)
            binaryData.append(UInt8(stringData.count))
            binaryData.append(contentsOf: stringData)
        }


        logger.debug("Binary data generated: \(binaryData.count) bytes")
        return .success(binaryData)
    }

}

