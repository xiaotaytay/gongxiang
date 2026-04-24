import Foundation

struct DeltaEntity {
    let id: Int32
    let dx: Int16
    let dy: Int16
}

class BinaryFrame {
    var version: UInt8 = ProtocolConstants.version1
    var type: UInt8 = 0
    var flag: UInt8 = 0
    var clientId: String?
    var targetClientId: String?
    var gameDataPayload: String?
    var roomListStr: String?
    var deltaEntities: [DeltaEntity]?
    
    static func createGetHome() -> BinaryFrame {
        let f = BinaryFrame()
        f.type = ProtocolConstants.typeGetHome
        return f
    }
    
    static func createViewerRegister(clientId: String, targetClientId: String) -> BinaryFrame {
        let f = BinaryFrame()
        f.type = ProtocolConstants.typeViewerRegister
        f.clientId = clientId
        f.targetClientId = targetClientId
        return f
    }
    
    static func createHeartbeat() -> BinaryFrame {
        let f = BinaryFrame()
        f.type = ProtocolConstants.typeHeartbeat
        return f
    }
    
    static func decode(_ data: Data) -> BinaryFrame? {
        guard data.count >= 9 else { return nil }
        
        let magic = readUInt16(data, offset: 0)
        guard magic == ProtocolConstants.magic else { return nil }
        
        let version = data[2]
        let length = readUInt32(data, offset: 3)
        guard length <= UInt32(data.count - 7) else { return nil }
        
        let type = data[7]
        let flag = data[8]
        
        let frame = BinaryFrame()
        frame.version = version
        frame.type = type
        frame.flag = flag
        
        let payloadData = data.subdata(in: 9..<data.count)
        
        switch type {
        case ProtocolConstants.typeHomeData:
            frame.roomListStr = String(data: payloadData, encoding: .utf8)
        case ProtocolConstants.typeGameDataResponse:
            if (flag & ProtocolConstants.flagIncremental) != 0 {
                frame.deltaEntities = decodeDeltaEntities(payloadData)
            } else {
                frame.gameDataPayload = decodeFullGameData(payloadData)
            }
        case ProtocolConstants.typeHeartbeatAck:
            break
        default:
            break
        }
        
        return frame
    }
    
    private static func readUInt16(_ data: Data, offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }
    
    private static func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 |
               UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
    }
    
    private static func readInt32(_ data: Data, offset: Int) -> Int32 {
        return Int32(bitPattern: readUInt32(data, offset: offset))
    }
    
    private static func readInt16(_ data: Data, offset: Int) -> Int16 {
        return Int16(bitPattern: readUInt16(data, offset: offset))
    }
    
    private static func decodeFullGameData(_ data: Data) -> String? {
        guard data.count >= 2 else { return nil }
        let dataLen = Int(readUInt16(data, offset: 0))
        guard data.count >= 2 + dataLen, dataLen > 0 else { return nil }
        return String(data: data.subdata(in: 2..<(2 + dataLen)), encoding: .utf8)
    }
    
    private static func decodeDeltaEntities(_ data: Data) -> [DeltaEntity] {
        guard data.count >= 2 else { return [] }
        let count = Int(readUInt16(data, offset: 0))
        var entities: [DeltaEntity] = []
        var offset = 2
        for _ in 0..<count where offset + 8 <= data.count {
            let id = readInt32(data, offset: offset)
            let dx = readInt16(data, offset: offset + 4)
            let dy = readInt16(data, offset: offset + 6)
            entities.append(DeltaEntity(id: id, dx: dx, dy: dy))
            offset += 8
        }
        return entities
    }
    
    func encode() -> Data {
        let payload = encodePayload()
        let payloadLen = UInt32(payload.count + 2)
        var result = Data(capacity: 7 + payload.count + 2)
        
        result.append(UInt8(ProtocolConstants.magic >> 8))
        result.append(UInt8(ProtocolConstants.magic & 0xFF))
        result.append(version)
        result.append(UInt8(payloadLen >> 24))
        result.append(UInt8((payloadLen >> 16) & 0xFF))
        result.append(UInt8((payloadLen >> 8) & 0xFF))
        result.append(UInt8(payloadLen & 0xFF))
        result.append(type)
        result.append(flag)
        result.append(payload)
        
        return result
    }
    
    private func encodePayload() -> Data {
        switch type {
        case ProtocolConstants.typeGetHome, ProtocolConstants.typeHeartbeat:
            return Data()
        case ProtocolConstants.typeViewerRegister:
            return encodeViewerRegister()
        default:
            return Data()
        }
    }
    
    private func encodeViewerRegister() -> Data {
        var result = Data()
        if let cid = clientId?.data(using: .utf8) {
            result.append(cid)
        }
        result.append(0)
        if let tid = targetClientId?.data(using: .utf8) {
            result.append(tid)
        }
        result.append(0)
        return result
    }
}
