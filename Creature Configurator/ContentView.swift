import SwiftUI
import UniformTypeIdentifiers
import os

struct ContentView: View {
    @State private var usbVID: String = ""
    @State private var usbPID: String = ""
    @State private var versionMajor: Int = 1
    @State private var versionMinor: Int = 0
    @State private var loggingLevel: Int = 3
    @State private var serialNumber: String = ""
    @State private var productName: String = ""
    @State private var manufacturer: String = "April's Creature Workshop"
    @State private var customStrings: [String] = [] // Start with zero custom strings
    @State private var showAlert = false
    @State private var alertMessage: String = ""

    let logger = Logger(subsystem: "creature.engineering.CreatureConfiguratator", category: "fileGeneration")

    var isValid: Bool {
        return isValidVID() && isValidPID() && !serialNumber.isEmpty && !productName.isEmpty && !manufacturer.isEmpty && customStrings.allSatisfy { !$0.isEmpty }
    }

    let logLevels = [
        ("Verbose", 5),
        ("Debug", 4),
        ("Info", 3),
        ("Warning", 2),
        ("Error", 1),
        ("Fatal", 0)
    ]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Creature Configuration Generator")
                .font(.largeTitle)
                .padding(.bottom, 20)

            HStack {
                Text("USB VID:")
                TextField("Enter VID", text: $usbVID)
                    .frame(width: 100)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            HStack {
                Text("USB PID:")
                TextField("Enter PID", text: $usbPID)
                    .frame(width: 100)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            Divider().padding(.vertical, 10)

            HStack {
                Text("Version:")
                Stepper(value: $versionMajor, in: 0...99) {
                    Text("Major: \(versionMajor)")
                }.frame(width: 120)

                Stepper(value: $versionMinor, in: 0...99) {
                    Text("Minor: \(versionMinor)")
                }.frame(width: 120)
            }

            HStack {
                Text("Logging Level:")
                Picker("Select Logging Level", selection: $loggingLevel) {
                    ForEach(logLevels, id: \.1) { level in
                        Text(level.0).tag(level.1)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 300)
            }

            Divider().padding(.vertical, 10)

            HStack {
                Text("Serial Number:")
                TextField("Enter Serial Number", text: $serialNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            HStack {
                Text("Product Name:")
                TextField("Enter Product Name", text: $productName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            HStack {
                Text("Manufacturer:")
                TextField("Enter Manufacturer", text: $manufacturer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            Divider().padding(.vertical, 10)

            // Custom user-defined strings
            ForEach(0..<customStrings.count, id: \.self) { index in
                HStack {
                    Text("Custom String \(index + 1):")
                    TextField("Enter Custom String", text: $customStrings[index])
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(action: {
                        customStrings.remove(at: index)
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            // Button to add more custom strings
            Button(action: {
                customStrings.append("")
            }) {
                Text("Add Another Custom String")
                    .fontWeight(.bold)
            }
            .padding(.vertical)

            Divider().padding(.vertical, 10)

            Button(action: {
                logger.log("Generate Configuration Files button pressed")
                if isValid {
                    generateConfigFiles()
                } else {
                    showError()
                }
            }) {
                Text("Generate Configuration Files")
                    .fontWeight(.bold)
            }
            .padding()
            .background(isValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(5)
            .disabled(!isValid)

            Button(action: readFromFile) {
                Text("Read Configuration from .bin File")
                    .fontWeight(.bold)
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(5)

            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    // MARK: - Validation Functions

    func isValidVID() -> Bool {
        return usbVID.count == 4 && UInt16(usbVID, radix: 16) != nil
    }

    func isValidPID() -> Bool {
        return usbPID.count == 4 && UInt16(usbPID, radix: 16) != nil
    }

    func showError() {
        if !isValidVID() {
            alertMessage = "Invalid USB VID. Please enter a 4-digit hexadecimal value."
        } else if !isValidPID() {
            alertMessage = "Invalid USB PID. Please enter a 4-digit hexadecimal value."
        } else if serialNumber.isEmpty {
            alertMessage = "Serial number cannot be empty."
        } else if productName.isEmpty {
            alertMessage = "Product name cannot be empty."
        } else if manufacturer.isEmpty {
            alertMessage = "Manufacturer cannot be empty."
        } else if customStrings.contains(where: { $0.isEmpty }) {
            alertMessage = "Custom strings cannot be empty if they are added."
        }
        showAlert = true
        logger.error("Validation failed: \(alertMessage)")
    }

    // MARK: - File Generation Functions

    func generateConfigFiles() {
        guard let vid = UInt16(usbVID, radix: 16), let pid = UInt16(usbPID, radix: 16) else {
            logger.error("Invalid USB VID or PID")
            return
        }

        logger.log("Generating binary and C file content")
        let serialData = Array(serialNumber.utf8)
        let productData = Array(productName.utf8)
        let manufacturerData = Array(manufacturer.utf8)

        var binaryData = Data()

        // "HOP!" magic number
        binaryData.append("HOP!".data(using: .ascii)!)

        // VID, PID
        binaryData.append(contentsOf: withUnsafeBytes(of: vid.bigEndian) { Data($0) })
        binaryData.append(contentsOf: withUnsafeBytes(of: pid.bigEndian) { Data($0) })

        // Version (BCD format)
        let versionBCD = UInt16((versionMajor << 8) | versionMinor)
        binaryData.append(contentsOf: withUnsafeBytes(of: versionBCD.bigEndian) { Data($0) })

        // Logging level
        binaryData.append(UInt8(loggingLevel))

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
        for customString in customStrings {
            let stringData = Array(customString.utf8)
            binaryData.append(UInt8(stringData.count))
            binaryData.append(contentsOf: stringData)
        }

        logger.log("Binary data generated: \(binaryData.count) bytes")

        // Save the binary file
        saveBinaryFile(binaryData: binaryData)

        // Save the C source file
        saveCFile(data: binaryData)
    }

    func saveBinaryFile(binaryData: Data) {
        let savePanel = NSSavePanel()
        savePanel.title = "Save Binary File"
        savePanel.nameFieldStringValue = "config.bin"
        savePanel.allowedContentTypes = [.data]

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try binaryData.write(to: url)
                logger.log("Binary file successfully saved at: \(url.path)")
            } catch {
                logger.error("Failed to save binary file: \(error.localizedDescription)")
            }
        } else {
            logger.log("Save panel was canceled")
        }
    }

    func saveCFile(data: Data) {
        let savePanel = NSSavePanel()
        savePanel.title = "Save C File"
        savePanel.nameFieldStringValue = "config_array.c"
        savePanel.allowedContentTypes = [.cSource]

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let cFileString = generateCSourceCode(from: data)
                try cFileString.write(to: url, atomically: true, encoding: .utf8)
                logger.log("C file successfully saved at: \(url.path)")
            } catch {
                logger.error("Failed to save C file: \(error.localizedDescription)")
            }
        } else {
            logger.log("Save panel was canceled")
        }
    }

    func generateCSourceCode(from data: Data) -> String {
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

    // MARK: - Reading from a .bin File

    func readFromFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Configuration Binary File"
        openPanel.allowedContentTypes = [.data]
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let fileData = try Data(contentsOf: url)
                logger.log("Loaded .bin file with \(fileData.count) bytes")
                parseBinaryData(fileData)
            } catch {
                logger.error("Failed to read file: \(error.localizedDescription)")
            }
        } else {
            logger.log("Open panel was canceled")
        }
    }

    func parseBinaryData(_ data: Data) {
        var offset = 0

        // Read "HOP!" magic number (4 bytes)
        let magicNumber = String(bytes: data[offset..<offset+4], encoding: .ascii)
        offset += 4

        guard magicNumber == "HOP!" else {
            logger.error("Invalid magic number: \(magicNumber ?? "Unknown")")
            return
        }

        // Read VID (2 bytes)
        let vidData = data[offset..<offset+2]
        usbVID = vidData.map { String(format: "%02X", $0) }.joined()
        offset += 2

        // Read PID (2 bytes)
        let pidData = data[offset..<offset+2]
        usbPID = pidData.map { String(format: "%02X", $0) }.joined()
        offset += 2

        // Read Version (BCD format, 2 bytes)
        let versionData = data[offset..<offset+2]
        let versionBCD = UInt16(bigEndian: versionData.withUnsafeBytes { $0.load(as: UInt16.self) })
        versionMajor = Int((versionBCD & 0xFF00) >> 8)
        versionMinor = Int(versionBCD & 0x00FF)
        offset += 2

        // Read Logging level (1 byte)
        loggingLevel = Int(data[offset])
        offset += 1

        // Read Serial Number (length + string)
        let serialLength = Int(data[offset])
        offset += 1
        serialNumber = String(bytes: data[offset..<offset+serialLength], encoding: .utf8) ?? ""
        offset += serialLength

        // Read Product Name (length + string)
        let productLength = Int(data[offset])
        offset += 1
        productName = String(bytes: data[offset..<offset+productLength], encoding: .utf8) ?? ""
        offset += productLength

        // Read Manufacturer (length + string)
        let manufacturerLength = Int(data[offset])
        offset += 1
        manufacturer = String(bytes: data[offset..<offset+manufacturerLength], encoding: .utf8) ?? ""
        offset += manufacturerLength

        // Read Custom Strings
        customStrings.removeAll()
        while offset < data.count {
            let stringLength = Int(data[offset])
            offset += 1
            let customString = String(bytes: data[offset..<offset+stringLength], encoding: .utf8) ?? ""
            customStrings.append(customString)
            offset += stringLength
        }

        logger.log("Parsed .bin file successfully")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

