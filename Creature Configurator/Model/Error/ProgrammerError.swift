import Foundation

public enum ProgrammerError: Error, LocalizedError {
    case notConnected(String)
    case malformedInfo(String)
    case readingError(String)
    case writingError(String)
    case decodingError(String)
    case timeout(String)
    case notReady(String)


    public var errorDescription: String? {
        switch self {
        case .notConnected(let message),
             .malformedInfo(let message),
             .readingError(let message),
             .writingError(let message),
             .decodingError(let message),
             .timeout(let message),
             .notReady(let message):
             return message
        }
    }
}

