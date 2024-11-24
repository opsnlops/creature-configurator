
import Foundation
import os
import SwiftUI

/**
 This wrapper is a way to isolate the `SerialDeviceManager` away from the MainActor.

 `SerialDeviceManager` is an `actor` since we're dealing with a phsyical piece of hardware, and accessing it from a lot of places will lead to horrible race conditions. This wrapper owns the manager, and isolates it away from the MainActor.
 */

@MainActor
class SerialDeviceManagerWrapper: ObservableObject {

    let logger = Logger(subsystem: "creature.engineering.CreatureConfiguratator", category: "SerialDeviceManagerWrapper")

    @Published var state: SerialState = .disconnected
    @Published var errorMessage: String?
    @Published var status: String?
    @Published var programmerInfo: ProgrammerInfo?

    // The important thing that we're wrapping
    private let serialManager: SerialDeviceManager = SerialDeviceManager()


    func uploadConfigToProgrammer(creatureData: CreatureData) -> Result<String, ProgrammerError> {

        logger.info("Uploading config to programmer")

        var binaryData: Data = Data()

        switch(EEPROMDataGenerator.createEEPROMData(creatureData: creatureData)) {
        case .success(let data):
            binaryData = data
        case .failure(let error):
            let errorMessage = error.localizedDescription
            logger.error("Failed to generate EEPROM data: \(error.localizedDescription)")
            return .failure(.malformedInfo(errorMessage))
        }

        Task {
            await serialManager.loadData(data: binaryData)
        }

        return .success("Loaded data to programmer")

    }

    func burnUploadedDataToEEPROM() -> Result<String, ProgrammerError> {

        logger.info("Telling the programmer to burn the uploaded data")

        Task {

            let burnResult = await serialManager.burnEEPROM()

            switch(burnResult) {
            case .success(let data):
                logger.debug("Got data back from programmer: \(data)")
                status = data

            case .failure(let error):
                errorMessage = error.localizedDescription
                status = errorMessage
                logger.error("Failed to burn the uploaded data: \(error.localizedDescription)")

            }
        }

        return .success("Told the programmer to burn the uploaded data")

    }

    func verifyBurnedEEPROM() -> Result<String, ProgrammerError> {

        logger.info("Telling the programmer to verify the uploaded data")

        Task {

            let burnResult = await serialManager.verifyEEPROM()

            switch(burnResult) {
            case .success(let data):
                logger.debug("Got data back from programmer: \(data)")
                status = data

            case .failure(let error):
                errorMessage = error.localizedDescription
                status = errorMessage
                logger.error("Failed to verify the uploaded data: \(error.localizedDescription)")

            }
        }

        return .success("The programmer was able to verfiy the uploaded data")

    }


    func connect() {
        Task {
            switch(await serialManager.connect()) {
            case .success:
                logger.info("Connected to serial device")
            case .failure(let error):
                errorMessage = error.localizedDescription
                logger.error("Failed to connect to serial device: \(error.localizedDescription)")
                return
            }

            // Get the programmer info
            switch(await serialManager.getProgrammerInfo()) {
            case .success:
                logger.info("Got programmer info")
            case .failure(let error):
                errorMessage = error.localizedDescription
                logger.error("Failed to get programmer info: \(error.localizedDescription)")
            }

            await updateState()
        }
    }

    func disconnect() {
        Task {
            await serialManager.disconnect()
            await updateState()
        }
    }

    private func updateState() async {
        state = await serialManager.serialState
        errorMessage = await serialManager.errorMessage
        status = await serialManager.statusMessage
        programmerInfo = await serialManager.programmerInfo
    }
}

extension SerialDeviceManagerWrapper {
    public static func mock() -> SerialDeviceManagerWrapper {
        let wrapper = SerialDeviceManagerWrapper()
        return wrapper
    }
}
