import Foundation

struct HeroData {
    let id: Int
    let x: Float
    let y: Float
    let hp: Int
    let team: Int
    let ultCD: Int
    let skillCD: Int
    let summoner1CD: Int
    let summoner2CD: Int
    let level: Int
    
    static func parse(_ raw: String) -> HeroData? {
        let fields = raw.split(separator: ",", omittingEmptySubsequences: false)
        guard fields.count >= 7 else { return nil }
        
        let id = Int(fields[0].trimmingCharacters(in: .whitespaces)) ?? 0
        let level = parseLevel(String(fields[1]), String(fields[2]))
        let ultCD = clamp(Int(String(fields[3])) ?? 0, 0, 180)
        let skillCD = clamp(Int(String(fields[4])) ?? 0, 0, 180)
        let x = Float(String(fields[5])) ?? 0
        let y = Float(String(fields[6])) ?? 0
        let hp = fields.count > 7 ? clamp(Int(String(fields[7])) ?? 100, 0, 100) : 100
        let team = fields.count > 8 ? clamp(Int(String(fields[8])) ?? 0, 0, 2) : 0
        let s1 = fields.count > 9 ? clamp(Int(String(fields[9])) ?? 0, 0, 300) : 0
        let s2 = fields.count > 10 ? clamp(Int(String(fields[10])) ?? 0, 0, 300) : 0
        
        return HeroData(id: id, x: x, y: y, hp: hp, team: team,
                        ultCD: ultCD, skillCD: skillCD,
                        summoner1CD: s1, summoner2CD: s2, level: level)
    }
    
    private static func parseLevel(_ f1: String, _ f2: String) -> Int {
        let v1 = Int(f1.trimmingCharacters(in: .whitespaces)) ?? 0
        if v1 >= 1 && v1 <= 30 { return v1 }
        let v2 = Int(f2.trimmingCharacters(in: .whitespaces)) ?? 0
        if v2 >= 1 && v2 <= 30 { return v2 }
        return 0
    }
    
    private static func clamp(_ v: Int, _ min: Int, _ max: Int) -> Int {
        return Swift.max(min, Swift.min(max, v))
    }
}
