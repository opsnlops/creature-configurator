
import os
import Foundation
import SwiftUI

struct DataFileCreator {

    static let logger = Logger(subsystem: "creature.engineering.CreatureConfiguratator", category: "DataFileCreator")

    // MARK: Generate files

    @MainActor
    static func generateConfigFiles(data: CreatureData) -> Result<String, DataFileError> {

        logger.info("Creating the binary data")
        var binaryData: Data

        switch(EEPROMDataGenerator.createEEPROMData(creatureData: data)) {
        case .success(let data):
            binaryData = data
        case .failure(let error):
            logger.error("Failed to generate the binary data: \(error.localizedDescription)")
            return .failure(error)
        }

        // Save the binary file
        switch(saveBinaryFile(binaryData: binaryData)){
        case .success(let message):
            logger.info("Binary file successfully saved: \(message)")
        case .failure(let error):
            logger.error("Failed to save binary file: \(error.localizedDescription)")
            return .failure(error)
        }

        // Save the C source file
        switch(saveCFile(data: binaryData)) {
        case .success(let message):
            logger.info("C file successfully saved: \(message)")
        case .failure(let error):
            logger.error("C to save binary file: \(error.localizedDescription)")
            return .failure(error)
        }

        return .success("Files successfully generated")
    }

    static func generateCSourceCode(from data: Data) -> String {
        var cFileString = "const char config_array[] = {\n    "
        let hexArray = data.map { String(format: "0x%02X", $0) }
        cFileString += hexArray.enumerated().map { (index, element) in
            return element + ((index + 1) % 8 == 0 ? ",\n    " : ", ")
        }.joined()

        cFileString += "\n};\n\n"
        cFileString += "int gSizeFullFlashArray = sizeof(config_array);\n"

        logger.log("Generated C file content")
        return cFileString
    }


    // MARK: Save files to disk

    @MainActor
    static func saveBinaryFile(binaryData: Data) -> Result<String, DataFileError> {
        let savePanel = NSSavePanel()
        savePanel.title = "Save Binary File"
        savePanel.nameFieldStringValue = "config.bin"
        savePanel.allowedContentTypes = [.data]

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try binaryData.write(to: url)
                    return .success("Binary file successfully saved at: \(url.path)")
            } catch {
                return .failure(.unableToWriteFile("Failed to save binary file: \(error.localizedDescription)"))
              }
        } else {
            return .failure(.canceled("Binary file save panel was canceled"))
        }
    }

    @MainActor
    static func saveCFile(data: Data) -> Result<String, DataFileError> {
        let savePanel = NSSavePanel()
        savePanel.title = "Save C File"
        savePanel.nameFieldStringValue = "config_array.c"
        savePanel.allowedContentTypes = [.cSource]

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let cFileString = generateCSourceCode(from: data)
                try cFileString.write(to: url, atomically: true, encoding: .utf8)
                return .success("C file successfully saved at: \(url.path)")
            } catch {
                return .failure(.unableToWriteFile("Failed to save C file: \(error.localizedDescription)"))
            }
        } else {
            return .failure(.canceled("C file save panel was canceled"))
        }
    }




    // MARK: - Reading from a .bin File

    @MainActor
    static func readFromFile() -> Result<CreatureData, DataFileError> {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Configuration Binary File"
        openPanel.allowedContentTypes = [.data]
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let fileData = try Data(contentsOf: url)
                logger.info("Loaded .bin file with \(fileData.count) bytes")
                return parseBinaryData(fileData)
            } catch {
                let errorMessage = "Failed to read file: \(error.localizedDescription)"
                return .failure(.unableToReadFile(errorMessage))
            }
        } else {
            return .failure(.canceled("Open panel was canceled"))
        }
    }

    static func parseBinaryData(_ data: Data) -> Result<CreatureData, DataFileError> {

        guard data.count >= 8 else {
            let errorMessage = "Invalid .bin file: File is too short"
            return .failure(.unableToReadFile(errorMessage))
        }
        
        var offset = 0

        var creatureData = CreatureData()

        // Read "HOP!" magic number (4 bytes)
        let magicNumber = String(bytes: data[offset..<offset+4], encoding: .ascii)
        offset += 4

        guard magicNumber == "HOP!" else {
            return .failure(.invalidMagicNumber("Invalid magic number: \(magicNumber ?? "Unknown")"))
        }

        // Read VID (2 bytes)
        let vidData = data[offset..<offset+2]
        creatureData.usbVID = vidData.map { String(format: "%02X", $0) }.joined()
        offset += 2

        // Read PID (2 bytes)
        let pidData = data[offset..<offset+2]
        creatureData.usbPID = pidData.map { String(format: "%02X", $0) }.joined()
        offset += 2

        // Read Version (BCD format, 2 bytes)
        let versionData = data[offset..<offset+2]
        let versionBCD = UInt16(bigEndian: versionData.withUnsafeBytes { $0.load(as: UInt16.self) })
        creatureData.versionMajor = Int((versionBCD & 0xFF00) >> 8)
        creatureData.versionMinor = Int(versionBCD & 0x00FF)
        offset += 2

        // Read Logging level (1 byte)
        creatureData.loggingLevel = Int(data[offset])
        offset += 1

        // Read Serial Number (length + string)
        let serialLength = Int(data[offset])
        offset += 1
        creatureData.serialNumber = String(bytes: data[offset..<offset+serialLength], encoding: .utf8) ?? ""
        offset += serialLength

        // Read Product Name (length + string)
        let productLength = Int(data[offset])
        offset += 1
        creatureData.productName = String(bytes: data[offset..<offset+productLength], encoding: .utf8) ?? ""
        offset += productLength

        // Read Manufacturer (length + string)
        let manufacturerLength = Int(data[offset])
        offset += 1
        creatureData.manufacturer = String(bytes: data[offset..<offset+manufacturerLength], encoding: .utf8) ?? ""
        offset += manufacturerLength

        // Read Custom Strings
        creatureData.customStrings.removeAll()
        while offset < data.count {
            let stringLength = Int(data[offset])
            offset += 1
            let customString = String(bytes: data[offset..<offset+stringLength], encoding: .utf8) ?? ""
            creatureData.customStrings.append(customString)
            offset += stringLength
        }

        logger.log("Parsed .bin file successfully")
        return .success(creatureData)
    }
}
