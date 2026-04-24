import Foundation

struct MonsterData {
    let cd: Int
    let id: String
    let x: Float
    let y: Float
    
    static let fullCDValues = [0, 60, 70, 90, 120, 240]
    
    static func parse(_ raw: String) -> MonsterData? {
        let fields = raw.split(separator: ",", omittingEmptySubsequences: false)
        guard fields.count >= 5 else { return nil }
        
        let cd = Int(String(fields[1])) ?? 0
        let id = String(fields[2]).trimmingCharacters(in: .whitespaces)
        let x = Float(String(fields[3])) ?? 0
        let y = Float(String(fields[4])) ?? 0
        
        return MonsterData(cd: cd, id: id, x: x, y: y)
    }
    
    var isFullCD: Bool {
        MonsterData.fullCDValues.contains(cd)
    }
}
