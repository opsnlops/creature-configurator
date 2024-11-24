
import Combine
import Foundation
import os
import SwiftSerial
import SwiftUI

actor SerialDeviceManager {

    let logger = Logger(subsystem: "creature.engineering.CreatureConfiguratator", category: "SerialDeviceManager")

    @AppStorage("programmerSerialPort") private var programmerSerialPort: String = ""
    @AppStorage("programmerSerialBaud") private var programmerSerialBaud: Int = 19200

    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var serialState: SerialState = .disconnected
    @Published var programmerInfo: ProgrammerInfo?

    private var serialPort: SerialPort?

    // Chunk size and delay settings
    private let chunkSize = 6 // Number of bytes per chunk
    private let interChunkDelay: TimeInterval = 0.03 // 30 ms delay


    // MARK: Establishing and stopping a connection

    func connect() async -> Result<String, Error> {

        serialState = .connecting

        logger.debug("Connecting to \(self.programmerSerialPort) at \(self.programmerSerialBaud) baud")
        serialPort = SerialPort(path: programmerSerialPort)

        // If this didn't work, bail out
        if let serialPort {
            do {
                logger.debug("opening the port")
                try serialPort.openPort()

                logger.debug("setting the baud rate")
                try serialPort.setSettings(baudRateSetting: .symmetrical(.baud115200), minimumBytesToRead: 1)
            }
            catch {
                return .failure(error)
            }

        }

        // Hooray, we're connected!
        serialState = .connected

        return .success("Connected to \(programmerSerialPort) at \(programmerSerialBaud) baud")
    }

    func disconnect() {

        if let serialPort {
            logger.debug("closing the port")
            serialPort.closePort()
            programmerInfo = nil
        }
        else {
            logger.debug("already disconnected")
        }
        serialState = .disconnected
    }


    // MARK: Working with programmer

    func getProgrammerInfo() async -> Result<ProgrammerInfo, ProgrammerError> {
        // Ensure we're connected
        guard serialState == .connected else {
            logger.error("Unable to get programmer info while not connected")
            return .failure(.notConnected("Not connected"))
        }

        // Ensure the serial port is valid
        guard let serialPort else {
            logger.error("Unable to get programmer info because serialPort is nil")
            return .failure(.notConnected("Serial port is nil"))
        }

        do {
            // Send the command to the device
            let bytesWritten = try serialPort.writeString("I\n")
            logger.debug("Requested programmer info, \(bytesWritten) bytes written")

            // Read async lines
            for try await line in try serialPort.asyncLines() {
                logger.debug("Received line: \(line)")

                // Attempt to decode JSON
                if let data = line.data(using: .utf8) {
                    do {
                        let programmerInfo = try JSONDecoder().decode(ProgrammerInfo.self, from: data)
                        self.programmerInfo = programmerInfo
                        logger.debug("Decoded programmer info: \(programmerInfo.version)")
                        return .success(programmerInfo)
                    } catch {
                        logger.error("JSON decoding error: \(error.localizedDescription)")
                        return .failure(.decodingError("JSON decoding error: \(error.localizedDescription)"))
                    }
                }
            }

            // No valid JSON found
            logger.error("No valid JSON received before timeout")
            return .failure(.timeout("Timeout while waiting for programmer info"))
        } catch {
            logger.error("Error while reading from serial port: \(error.localizedDescription)")
            return .failure(.readingError("Serial port read error: \(error.localizedDescription)"))
        }
    }


    func burnEEPROM() async -> Result<String, ProgrammerError> {
        // Ensure we're connected
        guard serialState == .connected else {
            logger.error("Unable to burn an EEPROM while not connected")
            return .failure(.notConnected("Not connected"))
        }

        // Ensure the serial port is valid
        guard let serialPort else {
            logger.error("Unable to burn an EEPROM because serialPort is nil")
            return .failure(.notConnected("Serial port is nil"))
        }

        do {
            let bytesWritten = try serialPort.writeString("B\n")
            logger.debug("Told the programmer to burn the EEPROM (bytes written: \(bytesWritten))")

            // Wait for the "OK" response
            logger.debug("Waiting for the programmer to tell us it burned the EEPROM")
            for await line in readLines() {
                logger.debug("Received line: \(line)")
                if line == "OK\n" {
                    logger.info("Programmer confirmed the EEPROM was burned")
                    return .success("Programmer confirmed the EEPROM was burned")
                }
                else {
                    logger.warning("Got a message we didn't expect on a burn: \(line)")
                    return .failure(.writingError("Got a message we didn't expect on a burn: \(line)"))
                }
            }

        } catch {
            logger.error("Error while burning the EEPROM: \(error.localizedDescription)")
            return .failure(.writingError("Error while burning the EEPROM: \(error.localizedDescription)"))
        }

        logger.error("Got to the end of burnEEPROM without seeing an OK")
        return .failure(.writingError("Got to the end of burnEEPROM without seeing an OK"))
    }


    func verifyEEPROM() async -> Result<String, ProgrammerError> {
        // Ensure we're connected
        guard serialState == .connected else {
            logger.error("Unable to verify a burn while not connected")
            return .failure(.notConnected("Not connected"))
        }

        // Ensure the serial port is valid
        guard let serialPort else {
            logger.error("Unable to verify a burn because serialPort is nil")
            return .failure(.notConnected("Serial port is nil"))
        }

        do {
            let bytesWritten = try serialPort.writeString("V\n")
            logger.debug("Told the programmer to verify the EEPROM (bytes written: \(bytesWritten))")

            // Wait for the "OK" response
            logger.debug("Waiting for the programmer to tell us it verified the EEPROM")
            for await line in readLines() {
                logger.debug("Received line: \(line)")
                if line == "OK\n" {
                    logger.info("Programmer confirmed the EEPROM was verified")
                    return .success("Programmer confirmed the EEPROM was verified")
                }
                else {
                    logger.warning("Got a message we didn't expect on a verify: \(line)")
                    return .failure(.writingError("Got a message we didn't expect on a verify: \(line)"))
                }
            }

        } catch {
            logger.error("Error while verifying the EEPROM: \(error.localizedDescription)")
            return .failure(.writingError("Error while verifying the EEPROM: \(error.localizedDescription)"))
        }

        logger.error("Got to the end of verifyEEPROM without seeing an OK")
        return .failure(.writingError("Got to the end of verifyEEPROM without seeing an OK"))
    }


    func loadData(data: Data) async -> Result<String, ProgrammerError> {

        // Ensure we're connected
        guard serialState == .connected else {
            logger.error("Unable to get programmer info while not connected")
            return .failure(.notConnected("Not connected"))
        }

        // Ensure the serial port is valid
        guard let serialPort else {
            logger.error("Unable to get programmer info because serialPort is nil")
            return .failure(.notConnected("Serial port is nil"))
        }


        do {
            // Send the load command
            var bytesWritten = try serialPort.writeString("L\(data.count)\n")
            logger.debug("Told the programmer we want to write \(data.count) bytes. (\(bytesWritten) bytes written)")

            // Wait for the "GO_AHEAD" response
            logger.debug("Waiting for the programmer to tell us to go ahead...")
            for await line in readLines() {
                logger.debug("Received line: \(line)")
                if line == "GO_AHEAD\n" {

                    bytesWritten = 0

                    // Start sending data in chunks
                    var offset = 0
                    var numberOfChunks = 0
                    while offset < data.count {
                        let end = min(offset + chunkSize, data.count)
                        let chunk = data[offset..<end]
                        numberOfChunks += 1
                        bytesWritten += try serialPort.writeData(chunk)

                        // Introduce a delay between chunks
                        try await Task.sleep(nanoseconds: UInt64(interChunkDelay * 1_000_000_000))

                        if numberOfChunks % 10 == 0 {
                            logger.debug("Number of chunks: \(numberOfChunks)")
                        }
                        offset = end
                    }

                } else if line == "OK\n" {

                    logger.info("programmer said OK (\(bytesWritten) bytes written.)")
                    return .success("Data sent successfully. (\(bytesWritten) bytes written.)")

                }
                else {
                    logger.warning("Unexpected response: \(line)")
                    return .failure(.writingError("Unexpected response: \(line)"))
                }
            }

        } catch {

            logger.warning("Error writing data to the programmer: \(error)")
            return .failure(.writingError("Error writing data to the programmer: \(error)"))

        }

        logger.error("Got to end of loadData()")
        return .failure(.writingError("Got to end of loadData()"))
    }


    // Read lines asynchronously
    func readLines() -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                guard let serialPort = serialPort else {
                    continuation.finish()
                    return
                }

                do {
                    let asyncLines = try serialPort.asyncLines()
                    for try await line in asyncLines {
                        continuation.yield(line)
                    }
                } catch {
                    logger.error("Error reading lines: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }



}

extension SerialDeviceManager {
    static func mock() -> SerialDeviceManager {
        return SerialDeviceManager()
    }
}
