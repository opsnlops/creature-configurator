
import Foundation

/**
 This represent the state of the programmer. It's sent when then `I` command is sent.
 */
final class ProgrammerInfo: Codable, Equatable, Hashable, Sendable {
    public let version: String
    public let freeHeap: UInt32
    public let uptime: UInt32

    enum CodingKeys: String, CodingKey {
           case version
           case freeHeap = "free_heap"
           case uptime
    }

    public init(version: String, freeHeap: UInt32, uptime: UInt32) {
        self.version = version
        self.freeHeap = freeHeap
        self.uptime = uptime
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        freeHeap = try container.decode(UInt32.self, forKey: .freeHeap)
        uptime = try container.decode(UInt32.self, forKey: .uptime)
    }

    public static func == (lhs: ProgrammerInfo, rhs: ProgrammerInfo) -> Bool {
        lhs.version == rhs.version &&
        lhs.freeHeap == rhs.freeHeap &&
        lhs.uptime == rhs.uptime
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(version)
        hasher.combine(freeHeap)
        hasher.combine(uptime)
    }

}


// MARK: Mock

extension ProgrammerInfo {
    public static func mock() -> ProgrammerInfo {
        return ProgrammerInfo(
            version: "6.6.6",
            freeHeap: UInt32.random(in: 0..<200000),
            uptime: UInt32.random(in: 0..<10000000)
        )
    }
}
