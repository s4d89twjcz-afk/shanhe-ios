import XCTest
import UIKit
@testable import Shanhe

final class RecordTests: XCTestCase {
    func testVisitGroupingTimeAndVersionOneRoundTrip() throws {
        var morning = Place(); morning.title = "西湖"; morning.locationId = morning.id; morning.visitTitle = "清晨"; morning.date = "2026-10-05"; morning.time = "08:30"; morning.note = "早晨的随笔"
        var evening = morning; evening.id = "evening"; evening.time = "18:45"; evening.visitTitle = "黄昏"; evening.note = "独立的晚间随笔"
        let decoded = try JSONDecoder().decode(RecordDocument.self, from: JSONEncoder().encode(RecordDocument(places: [morning, evening])))
        let checked = try TravelRules.validate(decoded, provinceCodes: ["330000"])
        XCTAssertEqual(TravelRules.locations(checked).count, 1); XCTAssertEqual(TravelRules.ordered(checked).first?.id, "evening")
        XCTAssertEqual(TravelRules.filtered(checked, provinces: [], search: "黄昏").first?.time, "18:45")
        XCTAssertEqual(checked[0].note, "早晨的随笔"); XCTAssertEqual(checked[1].locationId, morning.id)
        for time in ["", "00:00", "23:59", "08:30"] { XCTAssertTrue(TravelRules.validTime(time)) }
        for time in ["8:30", "24:00", "12:60", "abcde", "０８:３０"] { XCTAssertFalse(TravelRules.validTime(time)) }
        var invalid = evening; invalid.title = "另一个地点"
        XCTAssertThrowsError(try TravelRules.validate(RecordDocument(places: [morning, invalid]), provinceCodes: ["330000"]))
    }
    func testLegacyWindowsRecordAndTags() throws {
        let legacy = """
        {"Version":1,"Places":[{"Id":"legacy","Title":"西湖","ProvinceCode":"330000","CityCode":"330100","CityName":"杭州市","Date":"2026-10-03","Note":null,"Mood":"自在","Cover":null,"Photos":[]}]}
        """
        let document = try JSONDecoder().decode(RecordDocument.self, from: Data(legacy.utf8))
        let places = try TravelRules.validate(document, provinceCodes: ["330000"])
        XCTAssertFalse(places[0].favorite); XCTAssertEqual(places[0].tags, []); XCTAssertEqual(places[0].cover, "")
        XCTAssertEqual(try TravelRules.tags("日落，徒步 日落;湖泊"), ["日落", "徒步", "湖泊"])
        XCTAssertThrowsError(try TravelRules.tags((0...10).map { "标签\($0)" }.joined(separator: ",")))
    }
    func testCombinedFiltersAndSort() {
        let records = TravelRules.samplePlaces()
        XCTAssertEqual(TravelRules.filtered(records, provinces: [], year: "2026", tag: "湖泊", favorites: true).map(\.id), ["demo1"])
        XCTAssertEqual(TravelRules.filtered(records, provinces: [], search: "慢旅行").map(\.id), ["demo2"])
        XCTAssertEqual(TravelRules.filtered(records, provinces: [], sort: .oldest).first?.id, "demo3")
        XCTAssertEqual(TravelRules.filtered(records, provinces: [], sort: .photos).first?.id, "demo1")
        XCTAssertNil(TravelRules.parseDate("2026-02-30")); XCTAssertNotNil(TravelRules.parseDate("2026-10-03"))
    }
    func testZIPRoundTripCRCAndTraversal() throws {
        let records = Data("{\"Version\":1,\"Places\":[]}".utf8), picture = Data([1, 2, 3, 4])
        let archive = try ZipArchive.write([("records.json", records), ("photos/a.jpg", picture)])
        let read = try ZipArchive.read(archive)
        XCTAssertEqual(read["records.json"], records); XCTAssertEqual(read["photos/a.jpg"], picture)
        var damaged = archive; damaged[30 + "records.json".utf8.count] ^= 1
        XCTAssertThrowsError(try ZipArchive.read(damaged))
        XCTAssertThrowsError(try ZipArchive.read(Data(archive.prefix(18))))
        XCTAssertThrowsError(try ZipArchive.write([("photos/../../escape.jpg", picture)]))
        XCTAssertFalse(TravelRules.safePhoto("photos/..\\escape.jpg")); XCTAssertFalse(TravelRules.safePhoto("photos/a/b.jpg"))
    }
}

final class StoreTests: XCTestCase {
    @MainActor func testAppendRenameDeleteUndoAndMove() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TravelStore(root: root)
        var first = Place(); first.title = "西湖"; first.date = "2026-10-05"; first.time = "08:30"; first.note = "清晨"; try store.save(first, newImages: [:])
        first = try XCTUnwrap(store.places.first)
        var second = Place(); second.title = first.title; second.locationId = first.locationKey; second.date = first.date; second.time = "18:45"; second.note = "黄昏"; try store.save(second, newImages: [:])
        XCTAssertEqual(store.locationCount, 1); XCTAssertEqual(store.visits(for: first).count, 2); XCTAssertEqual(store.places[0].note, "清晨")
        try store.delete(second.id)
        var renamed = try XCTUnwrap(store.places.first); renamed.title = "西湖 · 四季"; try store.save(renamed, newImages: [:]); try store.undoDelete()
        XCTAssertEqual(store.places.count, 2); XCTAssertTrue(store.places.allSatisfy { $0.title == "西湖 · 四季" })
        var standalone = Place(); standalone.title = "湖边的长椅"; try store.save(standalone, newImages: [:]); try store.move(standalone, to: store.places[0])
        XCTAssertEqual(store.locationCount, 1); XCTAssertEqual(store.places.count, 3)
        let reopened = TravelStore(root: root); XCTAssertEqual(reopened.locationCount, 1); XCTAssertEqual(reopened.places.first { $0.id == second.id }?.time, "18:45")
    }
    @MainActor func testWindowsTimelineZIPPreservesFieldsAndPhotos() async throws {
        let fixture = try XCTUnwrap(Bundle(for: StoreTests.self).url(forResource: "WindowsTimelineBackup", withExtension: "zip"))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TravelStore(root: root), prepared = try await store.prepareBackup(from: fixture)
        XCTAssertEqual(prepared.places.count, 3); try store.restore(prepared)
        XCTAssertEqual(store.locationCount, 1); XCTAssertEqual(store.visits(for: store.places[0]).first?.time, "18:45")
        XCTAssertTrue(store.places.allSatisfy { !$0.visitTitle.isEmpty && $0.photos.allSatisfy { name in FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path) } })
        let archive = try await store.backup(), entries = try ZipArchive.read(Data(contentsOf: archive))
        defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
        let document = try JSONDecoder().decode(RecordDocument.self, from: try XCTUnwrap(entries["records.json"]))
        XCTAssertEqual(Set(document.places.map(\.locationKey)).count, 1); XCTAssertEqual(document.places.filter { $0.time == "18:45" }.count, 1)
    }
    @MainActor func testCorruptCurrentRecordFallsBackAndPreservesValidPrevious() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TravelStore(root: root)
        var p = Place(); p.title = "第一次保存"; try store.save(p, newImages: [:])
        p.title = "第二次保存"; try store.save(p, newImages: [:])
        let current = root.appendingPathComponent("records.json"), previous = root.appendingPathComponent("records.json.previous")
        let originalPrevious = try Data(contentsOf: previous)
        try Data("broken".utf8).write(to: current)
        let recovered = TravelStore(root: root)
        XCTAssertEqual(recovered.places.first?.title, "第一次保存"); XCTAssertFalse(recovered.warning.isEmpty)
        try recovered.toggleFavorite(p.id)
        XCTAssertEqual(try Data(contentsOf: previous), originalPrevious)
        let reopened = TravelStore(root: root)
        XCTAssertTrue(reopened.places[0].favorite); XCTAssertEqual(reopened.warning, "")
    }
    @MainActor func testPhotoSaveEditFavoriteAndUndoPersistence() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TravelStore(root: root)
        XCTAssertEqual(store.provinces.count, 34); XCTAssertTrue(store.isDemo)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in UIColor.green.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20)) }
        var p = Place(); p.title = "西湖日落"; p.tags = ["湖泊", "日落"]; p.favorite = true; p.photos = ["pending-test"]; p.cover = "pending-test"
        try store.save(p, newImages: ["pending-test": try XCTUnwrap(image.jpegData(compressionQuality: 0.9))])
        XCTAssertFalse(store.isDemo); XCTAssertEqual(store.places.count, 1)
        let saved = try XCTUnwrap(store.places.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try store.photoURL(saved.cover).path))
        try store.toggleFavorite(saved.id); XCTAssertFalse(store.places[0].favorite)
        var updated = store.places[0]; updated.title = "更新手记"; try store.save(updated, newImages: [:])
        XCTAssertEqual(store.places.count, 1)
        try store.delete(updated.id); XCTAssertEqual(store.places.count, 0); try store.undoDelete()
        let reopened = TravelStore(root: root)
        XCTAssertEqual(reopened.places[0].title, "更新手记"); XCTAssertEqual(reopened.places[0].tags, ["湖泊", "日落"])
        XCTAssertNotNil(reopened.image(reopened.places[0].cover))
    }
    @MainActor func testRealWindowsZIPImportAndNativeExport() async throws {
        let bundle = Bundle(for: StoreTests.self)
        let fixture = try XCTUnwrap(bundle.url(forResource: "WindowsBackup", withExtension: "zip"))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TravelStore(root: root)
        let backup = try await store.prepareBackup(from: fixture)
        XCTAssertEqual(backup.places.count, 1)
        try store.restore(backup)
        XCTAssertEqual(store.places[0].photos.count, 2); XCTAssertTrue(store.places[0].favorite)
        let url = try await store.backup(), archive = try ZipArchive.read(Data(contentsOf: url))
        XCTAssertEqual(archive.count, 3)
        let records = try JSONDecoder().decode(RecordDocument.self, from: try XCTUnwrap(archive["records.json"]))
        XCTAssertEqual(records.version, 1); XCTAssertEqual(records.places[0].tags.count, 2)
        var malicious = store.places[0]; malicious.title = "<script>title</script>"; malicious.note = "<script>alert(1)</script>\n第二段"
        let story = try store.exportStory(malicious, html: true), html = try String(contentsOf: story, encoding: .utf8)
        XCTAssertTrue(html.contains("&lt;script&gt;")); XCTAssertFalse(html.contains("<script>")); XCTAssertTrue(html.contains("data:image/jpeg;base64,"))
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent()); try? FileManager.default.removeItem(at: story.deletingLastPathComponent())
    }
}
