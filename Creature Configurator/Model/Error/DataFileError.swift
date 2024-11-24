import Foundation

public enum DataFileError: Error, LocalizedError {
    case unableToReadFile(String)
    case unableToWriteFile(String)
    case invalidMagicNumber(String)
    case canceled(String)
    case invalidData(String)

    public var errorDescription: String? {
        switch self {
        case .unableToReadFile(let message),
             .unableToWriteFile(let message),
             .invalidMagicNumber(let message),
             .canceled(let message),
             .invalidData(let message):
             return message
        }
    }
}
