
import Foundation
import os
import SwiftUI
import UniformTypeIdentifiers


struct ContentView: View {

    @EnvironmentObject var serialManager: SerialDeviceManagerWrapper

    // VID 0x2E8A has been set aside for Pico-based projects for folks that don't have
    // a VID of their own assigned from the USB-IF.
    @State private var usbVID: String = "2E8A"
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


    @State private var connectTask: Task<Void, Never>? = nil
    @State private var disconnectTask: Task<Void, Never>? = nil
    @State private var burnTask: Task<Void, Never>? = nil

    let logger = Logger(subsystem: "creature.engineering.CreatureConfiguratator", category: "ContentView")

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

    // MARK: View Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Creature Configuration Generator")
                    .font(.largeTitle)
                    .padding(.bottom, 5)

                Button(action: readFromFile) {
                    Label("Read existing configuration from .bin file", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                .padding(.bottom, 10)

                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                }

                Divider().padding(.vertical, 10)

                Text("USB Device Configuration")
                    .font(.title2)


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


                HStack {
                    Text("Version:")
                    Stepper(value: $versionMajor, in: 0...99) {
                        Text("Major: \(versionMajor)")
                    }.frame(width: 120)

                    Stepper(value: $versionMinor, in: 0...99) {
                        Text("Minor: \(versionMinor)")
                    }.frame(width: 120)
                }

                Divider().padding(.vertical, 10)






                Text("Application Config")
                    .font(.title2)

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

                VStack {
                    Picker("Logging Level:", selection: $loggingLevel) {
                        ForEach(logLevels, id: \.1) { level in
                            Text(level.0).tag(level.1)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                }

                Divider().padding(.vertical, 10)

                Text("Custom Strings")
                    .font(.title2)

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


                Button(action: {
                    customStrings.append("")
                }) {
                    Label("Add a Custom String", systemImage: "plus")
                }
                .padding(.vertical)
                .buttonStyle(.automatic)

                Divider().padding(.vertical, 10)


                HStack {

                    Button(action: {
                        logger.log("Write EEPROM data button pressed")
                        if isValid {
                            uploadAndBurnConfigToProgrammer()
                        } else {
                            showValidationError()
                        }
                    }) {
                        Label("Write data to EEPROM", systemImage: "memorychip")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid || (serialManager.state != .connected))
                    .cornerRadius(5)

                    Spacer()

                    Button(action: {
                        logger.log("Generate Configuration Files button pressed")
                        if isValid {
                            generateConfigFiles()
                        } else {
                            showValidationError()
                        }
                    }) {
                        Label("Generate Configuration Files", systemImage: "square.and.arrow.down.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                    .cornerRadius(5)
                }

                Divider()
                    .padding(.vertical, 10)

                HStack {

                    Button(action: {
                        logger.debug("Programmer connection button clicked")
                        if serialManager.state == .disconnected {
                            connectToSerialPort()
                        }
                        else {
                            disconnectFromSerialPort()
                        }
                    }) {
                        Image(systemName: serialManager.state == .connected ? "cable.connector" : "cable.connector.slash")
                            .contentTransition(.symbolEffect(.replace))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.borderless)
                    .symbolRenderingMode(.palette)



                    Text(serialManager.state.description)
                        .font(.caption)

                    Spacer()

                    if let programmerInfo = serialManager.programmerInfo {
                        Text("\(programmerInfo.version)")
                            .font(.caption)
                    }




                }





            }
            .frame(maxHeight: .infinity)
            .padding(10)
        }
        .padding(0)
        .frame(width: 550)
    }

    // MARK: - Validation Functions

    func isValidVID() -> Bool {
        return usbVID.count == 4 && UInt16(usbVID, radix: 16) != nil
    }

    func isValidPID() -> Bool {
        return usbPID.count == 4 && UInt16(usbPID, radix: 16) != nil
    }

    func showValidationError() {
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



    // MARK: - File Manipulation Functions

    func createCreatureData() -> CreatureData {
        CreatureData(
            usbVID: usbVID,
            usbPID: usbPID,
            versionMajor: versionMajor,
            versionMinor: versionMinor,
            loggingLevel: loggingLevel,
            serialNumber: serialNumber,
            productName: productName,
            manufacturer: manufacturer,
            customStrings: customStrings
        )
    }

    /**
     Populate our data from a `CreatureData` object
     */
    func populateCreatureData(creatureData: CreatureData) {
        DispatchQueue.main.async {
            usbVID = creatureData.usbVID
            usbPID = creatureData.usbPID
            versionMajor = creatureData.versionMajor
            versionMinor = creatureData.versionMinor
            loggingLevel = creatureData.loggingLevel
            serialNumber = creatureData.serialNumber
            productName = creatureData.productName
            manufacturer = creatureData.manufacturer
            customStrings = creatureData.customStrings
        }
    }


    /**
     Populate our data from a file already on disk
     */
    func readFromFile() {

        let readResult = DataFileCreator.readFromFile()

        switch(readResult) {
        case .success(let creatureData):
            populateCreatureData(creatureData: creatureData)

        case .failure(let error):
            logger.error("Error reading from file: \(error.localizedDescription)")

            DispatchQueue.main.async {
                alertMessage = "Error reading from file: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }


    func generateConfigFiles() {

        let creatureData = createCreatureData()

        let generateResult = DataFileCreator.generateConfigFiles(data: creatureData)
        switch(generateResult) {

        case .success(let message):
            logger.info("Files created: \(message)")

        case .failure(let error):
            DispatchQueue.main.async {
                alertMessage = "Error reading from file: \(error.localizedDescription)"
                showAlert = true
            }
        }

    }


    // MARK: - Serial Port Functions


    func uploadAndBurnConfigToProgrammer() {


        if let burnTask {
            burnTask.cancel()
        }

        burnTask = Task {

            logger.info("🎉 starting the upload and burn process")

            logger.debug("starting upload")
            await uploadConfigToProgrammer()

            logger.debug("starting burn")
            await burnUploadedConfigToEEPROM()

            logger.debug("verifying burn")
            await verifyBurnedEEPROM()

            logger.info("upload and burn process complete")
        }


    }


    func uploadConfigToProgrammer() async {
        logger.debug("uploading data to the programmer")

        let uploadResult = serialManager.uploadConfigToProgrammer(creatureData: createCreatureData())
        switch(uploadResult) {
        case .success:
            logger.info("uploaded data to the programmer")

        case .failure(let error):
            logger.error("Error uploading data to the programmer: \(error.localizedDescription)")
            DispatchQueue.main.async {
                alertMessage = "Error uploading data to the programmer: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    func burnUploadedConfigToEEPROM() async {
        logger.debug("telling the programmer to burn the EEPROM")

        let burnResult = serialManager.burnUploadedDataToEEPROM()
        switch(burnResult) {
        case .success:
            logger.info("the programmer has burned the EEPROM")

        case .failure(let error):
            logger.error("Error burning the uploaded data to the EEPROM: \(error.localizedDescription)")
            DispatchQueue.main.async {
                alertMessage = "Error burning the uploaded data to the EEPROM: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    func verifyBurnedEEPROM() async {
        logger.debug("asking the programmer to verify the EEPROM")

        let verifyResult = serialManager.verifyBurnedEEPROM()
        switch(verifyResult) {
        case .success:
            logger.info("the programmer has verifed the EEPROM")

        case .failure(let error):
            logger.error("Error verifying the data on the EEPROM: \(error.localizedDescription)")
            DispatchQueue.main.async {
                alertMessage = "Error verifying the data on the EEPROM: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }


    func connectToSerialPort() {

        logger.info("attempting to connect to the programmer")

        // If there's one of these already, stop it
        if let connectTask {
            connectTask.cancel()
        }

        connectTask = Task {
            serialManager.connect()
        }

    }

    func disconnectFromSerialPort() {

        logger.info("attempting to disconnect from the programmer")

        // If there's one of these already, stop it
        if let disconnectTask {
            disconnectTask.cancel()
        }

        disconnectTask = Task {
            serialManager.disconnect()
        }

    }

}


// MARK: Preview
#Preview {
    ContentView()
        .environmentObject(SerialDeviceManagerWrapper.mock())
}
