import Foundation

enum ProtocolConstants {
    static let magic: UInt16 = 0x5955
    static let version1: UInt8 = 0x01
    static let headerSize = 7
    
    static let typeGetHome: UInt8 = 0x01
    static let typeHomeData: UInt8 = 0x02
    static let typeGameDataUpload: UInt8 = 0x03
    static let typeGameDataResponse: UInt8 = 0x04
    static let typeViewerRegister: UInt8 = 0x05
    static let typeHeartbeat: UInt8 = 0x06
    static let typeHeartbeatAck: UInt8 = 0x07
    
    static let flagIncremental: UInt8 = 0x01
    static let flagCompressed: UInt8 = 0x02
    
    static let defaultWSPort = 8887
    static let heartbeatIntervalMs: TimeInterval = 5.0
    static let roomRefreshIntervalMs: TimeInterval = 5.0
    static let maxReconnectAttempts = 8
    static let connectTimeout: TimeInterval = 10.0
}
