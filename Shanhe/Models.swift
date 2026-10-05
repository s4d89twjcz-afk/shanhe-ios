import Foundation

struct MapCity: Decodable, Identifiable {
    let code: String
    let name: String
    let center: [Double]
    let rings: [[[Double]]]
    var id: String { code }
    enum CodingKeys: String, CodingKey { case code = "Code", name = "Name", center = "Center", rings = "Rings" }
}

struct MapProvince: Decodable, Identifiable {
    let code: String
    let name: String
    let center: [Double]
    let rings: [[[Double]]]
    let cities: [MapCity]
    var id: String { code }
    enum CodingKeys: String, CodingKey { case code = "Code", name = "Name", center = "Center", rings = "Rings", cities = "Cities" }
}

struct Place: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString.lowercased()
    var title: String = ""
    var provinceCode: String = "330000"
    var cityCode: String = "330100"
    var cityName: String = "杭州市"
    var date: String = TravelRules.dateString(Date())
    var note: String = ""
    var mood: String = "自在"
    var cover: String = ""
    var photos: [String] = []
    var favorite: Bool = false
    var tags: [String] = []
    var locationId: String = ""
    var visitTitle: String = ""
    var time: String = ""
    var locationKey: String { locationId.isEmpty ? id : locationId }
    var timestamp: String { date + (time.isEmpty ? "" : "  " + time) }
    var visitHeading: String { visitTitle.isEmpty ? "这一天的故事" : visitTitle }

    enum CodingKeys: String, CodingKey {
        case id = "Id", title = "Title", provinceCode = "ProvinceCode", cityCode = "CityCode", cityName = "CityName"
        case date = "Date", note = "Note", mood = "Mood", cover = "Cover", photos = "Photos", favorite = "Favorite", tags = "Tags"
        case locationId = "LocationId", visitTitle = "VisitTitle", time = "Time"
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        provinceCode = try c.decode(String.self, forKey: .provinceCode)
        cityCode = try c.decode(String.self, forKey: .cityCode)
        cityName = try c.decode(String.self, forKey: .cityName)
        date = try c.decode(String.self, forKey: .date)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        mood = try c.decodeIfPresent(String.self, forKey: .mood) ?? "自在"
        cover = try c.decodeIfPresent(String.self, forKey: .cover) ?? ""
        photos = try c.decode([String].self, forKey: .photos)
        favorite = try c.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        locationId = try c.decodeIfPresent(String.self, forKey: .locationId) ?? id
        visitTitle = try c.decodeIfPresent(String.self, forKey: .visitTitle) ?? ""
        time = try c.decodeIfPresent(String.self, forKey: .time) ?? ""
    }
}

struct RecordDocument: Codable {
    var version: Int = 1
    var places: [Place]
    enum CodingKeys: String, CodingKey { case version = "Version", places = "Places" }
}

enum TravelError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case newest = "最近打卡", oldest = "最早打卡", photos = "照片最多"
    var id: String { rawValue }
}

enum TravelRules {
    static let moods = ["自在", "开心", "治愈", "惊喜", "感动", "平静", "想念"]
    static let maximumPhotoBytes = 80 * 1024 * 1024
    static let maximumArchiveBytes = 256 * 1024 * 1024
    static func formatter() -> DateFormatter {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"; f.isLenient = false; return f
    }
    static func dateString(_ date: Date) -> String {
        let f = formatter(); f.timeZone = .current; return f.string(from: date)
    }
    static func parseDate(_ text: String) -> Date? {
        let f = formatter(); f.timeZone = .current
        guard text.count == 10, let result = f.date(from: text), f.string(from: result) == text else { return nil }
        return Calendar(identifier: .gregorian).date(bySettingHour: 12, minute: 0, second: 0, of: result)
    }
    static func validTime(_ text: String) -> Bool {
        if text.isEmpty { return true }
        let bytes = Array(text.utf8)
        guard bytes.count == 5, bytes[2] == 58, [0, 1, 3, 4].allSatisfy({ (48...57).contains(bytes[$0]) }) else { return false }
        return Int(bytes[0] - 48) * 10 + Int(bytes[1] - 48) < 24 && Int(bytes[3] - 48) * 10 + Int(bytes[4] - 48) < 60
    }
    static func currentTime() -> String { let f = formatter(); f.timeZone = .current; f.dateFormat = "HH:mm"; return f.string(from: Date()) }
    static func ordered(_ entries: [Place]) -> [Place] { filtered(entries, provinces: []) }
    static func locations(_ entries: [Place]) -> [Place] {
        var seen = Set<String>(); return ordered(entries).filter { seen.insert($0.locationKey).inserted }
    }
    static func tags(_ text: String) throws -> [String] {
        let separators = CharacterSet(charactersIn: ",，;；#").union(.whitespacesAndNewlines)
        var result: [String] = [], seen = Set<String>()
        for tag in text.components(separatedBy: separators).filter({ !$0.isEmpty }) {
            guard tag.count <= 20 else { throw TravelError.message("单个标签最多 20 字。") }
            if seen.insert(tag.lowercased()).inserted { result.append(tag) }
        }
        guard result.count <= 10 else { throw TravelError.message("每条手记最多添加 10 个标签。") }
        return result
    }
    static func safePhoto(_ name: String) -> Bool {
        guard name.hasPrefix("photos/"), name.utf8.count < 220 else { return false }
        let leaf = String(name.dropFirst(7))
        return !leaf.isEmpty && !leaf.contains("/") && !leaf.contains("\\") && !leaf.contains("..") && !leaf.contains(":") && !leaf.contains("\0")
    }
    static func validate(_ document: RecordDocument, provinceCodes: Set<String>) throws -> [Place] {
        guard document.version == 1 else { throw TravelError.message("不支持这个备份版本。") }
        var ids = Set<String>(), output: [Place] = []
        for var p in document.places {
            guard !p.id.isEmpty, ids.insert(p.id).inserted, !p.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  provinceCodes.contains(p.provinceCode), !p.cityCode.isEmpty, !p.cityName.isEmpty, parseDate(p.date) != nil,
                  p.locationKey.count <= 200, p.visitTitle.count <= 100, validTime(p.time), p.photos.allSatisfy(safePhoto), p.cover.isEmpty || p.photos.contains(p.cover) else {
                throw TravelError.message("记录格式无效，现有数据未被覆盖。")
            }
            if p.locationId.isEmpty { p.locationId = p.id }
            p.tags = try tags(p.tags.joined(separator: ",")); output.append(p)
        }
        for group in Dictionary(grouping: output, by: \.locationKey).values {
            guard let first = group.first else { continue }
            guard group.allSatisfy({ $0.title == first.title && $0.provinceCode == first.provinceCode && $0.cityCode == first.cityCode && $0.cityName == first.cityName }) else { throw TravelError.message("同一地点的名称和省市信息不一致。现有记录未被覆盖。") }
        }
        return output
    }
    static func filtered(_ places: [Place], provinces: [MapProvince], search: String = "", year: String = "", tag: String = "", favorites: Bool = false, sort: SortOrder = .newest) -> [Place] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let names = Dictionary(uniqueKeysWithValues: provinces.map { ($0.code, $0.name) })
        return places.filter { p in
            (!favorites || p.favorite) && (year.isEmpty || p.date.hasPrefix(year + "-")) && (tag.isEmpty || p.tags.contains(tag)) &&
            (term.isEmpty || ([p.title, p.visitTitle, names[p.provinceCode] ?? "", p.cityName, p.note, p.mood] + p.tags).joined(separator: " ").localizedCaseInsensitiveContains(term))
        }.sorted { a, b in
            if sort == .photos && a.photos.count != b.photos.count { return a.photos.count > b.photos.count }
            if a.date != b.date { return sort == .oldest ? a.date < b.date : a.date > b.date }
            if a.time != b.time { return sort == .oldest ? a.time < b.time : a.time > b.time }
            return a.id < b.id
        }
    }
    static func samplePlaces() -> [Place] {
        var lake = Place(); lake.id = "demo1"; lake.title = "在洱海，等一场日落"; lake.provinceCode = "530000"; lake.cityCode = "532900"; lake.cityName = "大理白族自治州"
        lake.date = "2026-09-20"; lake.mood = "治愈"; lake.favorite = true; lake.tags = ["湖泊", "日落"]
        lake.note = "沿着湖边慢慢走，风里有水草的气息。\n\n太阳一点点落进山的轮廓，湖面变成了温柔的金色。原来旅行最好的部分，是终于有时间让自己慢下来。"
        lake.photos = ["demo-lake", "demo-mountain"]; lake.cover = lake.photos[0]
        var west = Place(); west.id = "demo2"; west.title = "西湖边的一段慢时光"; west.date = "2026-08-16"; west.tags = ["湖泊", "慢旅行"]
        west.note = "雨后的西湖很安静，远山像一笔淡淡的墨。找一张长椅坐下，什么也不做，也是一种很好的旅行。"; west.photos = ["demo-green"]; west.cover = west.photos[0]
        var city = Place(); city.id = "demo3"; city.title = "成都，街角的烟火气"; city.provinceCode = "510000"; city.cityCode = "510100"; city.cityName = "成都市"; city.date = "2026-07-08"; city.mood = "开心"; city.tags = ["美食", "城市漫步"]
        city.note = "一碗热腾腾的面，一壶慢慢喝的茶。喜欢这座城市把日子过得很认真，又很松弛。"; city.photos = ["demo-mountain"]; city.cover = city.photos[0]
        return [lake, west, city]
    }
}

struct EditorRequest: Identifiable { let id = UUID(); var place: Place? = nil; var province: String = ""; var city: String = ""; var append: Bool = false }
struct SharedFile: Identifiable { let id = UUID(); let url: URL }
struct PhotoPage: Identifiable { let id = UUID(); let placeID: String; let index: Int }
struct PreparedBackup { var places: [Place]; var images: [String: Data] }
