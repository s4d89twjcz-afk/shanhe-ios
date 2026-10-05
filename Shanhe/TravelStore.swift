import Foundation
import Combine
import UIKit
import ImageIO

@MainActor
final class TravelStore: ObservableObject {
    @Published private(set) var places: [Place] = []
    @Published private(set) var isDemo = false
    @Published private(set) var deleted: Place?
    @Published var warning = ""
    let provinces: [MapProvince]
    let seaRings: [[[Double]]]
    let root: URL
    private var loadBlocked = false
    private let thumbnails = NSCache<NSString, UIImage>()
    var locationCount: Int { Set(places.map(\.locationKey)).count }
    func visits(for p: Place) -> [Place] { TravelRules.ordered(places.filter { $0.locationKey == p.locationKey }) }
    var provinceCodes: Set<String> { Set(provinces.map(\.code)) }
    var years: [String] { Array(Set(places.map { String($0.date.prefix(4)) })).sorted(by: >) }
    var allTags: [String] { Array(Set(places.flatMap(\.tags))).sorted() }

    init(root: URL? = nil, bundle: Bundle = .main) {
        self.root = root ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Shanhe", isDirectory: true)
        var catalog: [MapProvince] = [], sea: [[[Double]]] = [], catalogError = ""
        do {
            guard let url = bundle.url(forResource: "map", withExtension: "json") else { throw TravelError.message("缺少离线地图资源。") }
            catalog = try JSONDecoder().decode([MapProvince].self, from: Data(contentsOf: url))
            if let url = bundle.url(forResource: "sea", withExtension: "json") { sea = try JSONDecoder().decode([[[Double]]].self, from: Data(contentsOf: url)) }
            guard catalog.count == 34 else { throw TravelError.message("离线地图数据不完整。") }
        } catch { catalogError = error.localizedDescription }
        provinces = catalog; seaRings = sea
        thumbnails.totalCostLimit = 40 * 1024 * 1024
        do {
            try FileManager.default.createDirectory(at: self.root.appendingPathComponent("photos"), withIntermediateDirectories: true)
            guard catalogError.isEmpty else { throw TravelError.message(catalogError) }
            let file = self.root.appendingPathComponent("records.json")
            if FileManager.default.fileExists(atPath: file.path) {
                do { places = try decodeRecords(Data(contentsOf: file)) }
                catch {
                    let previous = self.root.appendingPathComponent("records.json.previous")
                    if let bytes = try? Data(contentsOf: previous), let restored = try? decodeRecords(bytes) {
                        places = restored; warning = "已载入上一次保存的记录。请核对并导出备份。"
                    } else { throw TravelError.message("记录无法读取，请保留本地文件并从有效备份恢复。原文件未被覆盖。") }
                }
            } else { isDemo = true; places = TravelRules.samplePlaces() }
        } catch { warning = error.localizedDescription; loadBlocked = true }
    }
    func location(_ p: Place) -> String { (provinces.first { $0.code == p.provinceCode }?.name ?? "") + " · " + p.cityName }
    func decodeRecords(_ data: Data) throws -> [Place] {
        try TravelRules.validate(JSONDecoder().decode(RecordDocument.self, from: data), provinceCodes: provinceCodes)
    }
    func photoURL(_ name: String) throws -> URL {
        guard TravelRules.safePhoto(name) else { throw TravelError.message("照片路径无效。") }; return root.appendingPathComponent(name)
    }
    private func commit(_ records: [Place], recovery: Bool = false) throws {
        guard !loadBlocked || recovery else { throw TravelError.message("当前记录无法安全读取，请先在设置中恢复备份。") }
        let checked = try TravelRules.validate(RecordDocument(places: records), provinceCodes: provinceCodes)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(RecordDocument(places: checked))
        let file = root.appendingPathComponent("records.json"), previous = root.appendingPathComponent("records.json.previous")
        if FileManager.default.fileExists(atPath: file.path) {
            let current = try Data(contentsOf: file)
            // Keep the last valid copy when recovery loaded records.json.previous.
            if (try? decodeRecords(current)) != nil { try current.write(to: previous, options: .atomic) }
        }
        try data.write(to: file, options: .atomic)
        places = checked; isDemo = false; loadBlocked = false; warning = ""
    }
    /// New images are written before the atomic record commit, then rolled back on failure.
    func save(_ draft: Place, newImages: [String: Data]) throws {
        var saved = draft, imported: [URL] = [], remap: [String: String] = [:]
        if saved.locationId.isEmpty { saved.locationId = saved.id }
        do {
            for name in draft.photos where newImages[name] != nil {
                guard let data = newImages[name], data.count <= TravelRules.maximumPhotoBytes, UIImage(data: data) != nil else { throw TravelError.message("照片无法读取或超过 80 MB。") }
                let relative = "photos/" + UUID().uuidString.lowercased() + ".jpg"
                let url = try photoURL(relative); try data.write(to: url, options: .atomic)
                imported.append(url); remap[name] = relative
            }
            saved.photos = draft.photos.map { remap[$0] ?? $0 }; saved.cover = remap[draft.cover] ?? draft.cover
            if saved.cover.isEmpty { saved.cover = saved.photos.first ?? "" }
            var all = isDemo ? [] : places
            if let index = all.firstIndex(where: { $0.id == saved.id }) {
                for i in all.indices where all[i].locationKey == saved.locationKey { all[i].title = saved.title; all[i].provinceCode = saved.provinceCode; all[i].cityCode = saved.cityCode; all[i].cityName = saved.cityName }
                all[index] = saved
            } else { all.append(saved) }
            try commit(all)
        } catch { for url in imported { try? FileManager.default.removeItem(at: url) }; throw error }
    }
    func toggleFavorite(_ id: String) throws {
        guard let index = places.firstIndex(where: { $0.id == id }) else { return }
        var all = places; all[index].favorite.toggle()
        if isDemo { places = all } else { try commit(all) }
    }
    func delete(_ id: String) throws {
        guard !isDemo, let p = places.first(where: { $0.id == id }) else { return }
        try commit(places.filter { $0.id != id }); deleted = p
    }
    func undoDelete() throws {
        guard var p = deleted else { return }; var all = places
        if let current = all.first(where: { $0.locationKey == p.locationKey }) { p.title = current.title; p.provinceCode = current.provinceCode; p.cityCode = current.cityCode; p.cityName = current.cityName }
        if !all.contains(where: { $0.id == p.id }) { all.append(p) }
        try commit(all); deleted = nil
    }
    func move(_ p: Place, to target: Place) throws {
        guard !isDemo, p.locationKey != target.locationKey else { return }
        guard p.provinceCode == target.provinceCode, p.cityCode == target.cityCode else { throw TravelError.message("只能归入同一省市的已有地点。") }
        guard let index = places.firstIndex(where: { $0.id == p.id }) else { return }
        var all = places; all[index].locationId = target.locationKey; all[index].title = target.title; all[index].cityName = target.cityName; try commit(all)
    }
    func randomMemory(excluding id: String?) -> Place? {
        let candidates = places.count > 1 ? places.filter { $0.id != id } : places; return candidates.randomElement()
    }
    func image(_ name: String, maxDimension: Int = 700) -> UIImage? {
        guard !name.isEmpty else { return nil }
        if name.hasPrefix("demo-") { return ScenicArtwork.image(kind: name) }
        let key = (name + "@" + String(maxDimension)) as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        guard let url = try? photoURL(name), let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: maxDimension] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        let image = UIImage(cgImage: cg); thumbnails.setObject(image, forKey: key, cost: cg.bytesPerRow * cg.height); return image
    }
    nonisolated static func normalizePhoto(_ data: Data) throws -> Data {
        guard data.count <= TravelRules.maximumPhotoBytes, let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw TravelError.message("照片无法读取或超过 80 MB。") }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 2400] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options), let result = UIImage(cgImage: cg).jpegData(compressionQuality: 0.9) else { throw TravelError.message("不能转换这张照片。") }
        return result
    }
    func backup() async throws -> URL {
        guard !loadBlocked else { throw TravelError.message("当前记录无法读取，请先恢复有效备份。") }
        guard !isDemo else { throw TravelError.message("请先创建自己的记录，再导出完整备份。") }
        let snapshot = places, root = self.root
        return try await Task.detached(priority: .userInitiated) {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            var entries = [("records.json", try encoder.encode(RecordDocument(places: snapshot)))], total = 0
            for name in Set(snapshot.flatMap(\.photos)).sorted() {
                guard TravelRules.safePhoto(name) else { throw TravelError.message("照片路径无效。") }
                let data = try Data(contentsOf: root.appendingPathComponent(name)); total += data.count
                guard total <= TravelRules.maximumArchiveBytes else { throw TravelError.message("iOS 备份目前最大 256 MB。") }
                entries.append((name, data))
            }
            let date = TravelRules.dateString(Date()), folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("山河足迹备份-\(date).zip")
            try ZipArchive.write(entries).write(to: url, options: .atomic); return url
        }.value
    }
    func prepareBackup(from url: URL) async throws -> PreparedBackup {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let codes = provinceCodes
        return try await Task.detached(priority: .userInitiated) {
            let properties = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (properties.fileSize ?? 0) <= TravelRules.maximumArchiveBytes else { throw TravelError.message("这个备份超过 iOS 当前 256 MB 限制。") }
            let entries = try ZipArchive.read(Data(contentsOf: url))
            guard let records = entries["records.json"], records.count <= 20 * 1024 * 1024 else { throw TravelError.message("记录文件缺失或过大。") }
            let places = try TravelRules.validate(JSONDecoder().decode(RecordDocument.self, from: records), provinceCodes: codes)
            var images: [String: Data] = [:]
            for name in Set(places.flatMap(\.photos)) {
                guard let data = entries[name], UIImage(data: data) != nil else { throw TravelError.message("备份照片缺失、损坏，或 iOS 无法读取该图片格式。") }
                images[name] = data
            }
            return PreparedBackup(places: places, images: images)
        }.value
    }
    func restore(_ backup: PreparedBackup) throws {
        var remap: [String: String] = [:], imported: [URL] = [], records = backup.places
        do {
            for (name, data) in backup.images {
                guard TravelRules.safePhoto(name), data.count <= TravelRules.maximumPhotoBytes else { throw TravelError.message("照片文件无效。") }
                let ext = (name as NSString).pathExtension.lowercased()
                let relative = "photos/" + UUID().uuidString.lowercased() + "." + ext
                let url = try photoURL(relative); try data.write(to: url, options: .atomic)
                imported.append(url); remap[name] = relative
            }
            for index in records.indices {
                records[index].photos = records[index].photos.map { remap[$0] ?? $0 }
                records[index].cover = remap[records[index].cover] ?? records[index].cover
            }
            try commit(records, recovery: true); deleted = nil; thumbnails.removeAllObjects()
        } catch { for url in imported { try? FileManager.default.removeItem(at: url) }; throw error }
    }
    func exportStory(_ p: Place, html: Bool) throws -> URL {
        let text: String
        if html {
            var images = ""
            let ordered = ([p.cover].filter { !$0.isEmpty } + p.photos.filter { $0 != p.cover })
            for name in ordered {
                guard let image = image(name, maxDimension: 1600), let data = image.jpegData(compressionQuality: 0.86) else { throw TravelError.message("手记中有照片缺失，未完成导出。") }
                images += "<img alt=\"旅行照片\" src=\"data:image/jpeg;base64,\(data.base64EncodedString())\">"
            }
            text = """
            <!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>\(p.title.htmlEscaped)</title><style>body{margin:0;background:#f4f6ef;color:#294639;font-family:system-ui}main{max-width:800px;padding:26px;margin:auto}p{line-height:1.9;white-space:pre-wrap}img{width:100%;border-radius:16px;margin:12px 0}.meta{color:#809175;font-size:13px}</style><main><p class="meta">山河足迹 · \(p.timestamp.htmlEscaped) · \(p.mood.htmlEscaped)</p><h1>\(p.title.htmlEscaped)</h1><p class="meta">\(location(p).htmlEscaped)</p><p class="meta">\(p.tags.map { "#" + $0 }.joined(separator: "  ").htmlEscaped)</p><h2>\(p.visitHeading.htmlEscaped)</h2><p>\(p.note.htmlEscaped)</p>\(images)</main></html>
            """
        } else { text = "\(p.title)\n\(location(p))\n记录：\(p.visitHeading)\n日期：\(p.timestamp)　心情：\(p.mood)\n标签：\(p.tags.joined(separator: "、"))\n收藏：\(p.favorite ? "是" : "否")\n\n\(p.note)\n\n照片：\(p.photos.count) 张\n导出自 山河足迹" }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let filename = p.title.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        let url = folder.appendingPathComponent(String(filename.prefix(60)) + (html ? ".html" : ".txt"))
        try Data(text.utf8).write(to: url, options: .atomic); return url
    }
}

private extension String {
    var htmlEscaped: String { replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;") }
}
