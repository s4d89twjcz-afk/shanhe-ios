import SwiftUI
import UIKit

enum Theme {
    static let green = Color(hex: 0x237D74), ink = Color(hex: 0x243E35), secondary = Color(hex: 0x809176)
    static let paper = Color(hex: 0xF5F7FB), soft = Color(hex: 0xE8F3EF), line = Color(hex: 0xE2E9DC)
}
extension Color { init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) } }
extension View {
    func travelCard() -> some View { self.background(.white, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 1)) }
}

@MainActor
enum ScenicArtwork {
    static let cache = NSCache<NSString, UIImage>()
    static func image(kind: String) -> UIImage {
        if let image = cache.object(forKey: kind as NSString) { return image }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 500))
        let sunset = kind == "demo-lake", green = kind == "demo-green"
        let image = renderer.image { context in
            let cg = context.cgContext
            func color(_ hex: UInt32) -> UIColor { UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1) }
            color(sunset ? 0xF1D8B6 : green ? 0xD8E5D2 : 0xDCDCD0).setFill(); cg.fill(CGRect(x: 0, y: 0, width: 800, height: 500))
            color(sunset ? 0xE4B379 : 0xF1E8C4).setFill(); cg.fillEllipse(in: CGRect(x: 542, y: 72, width: 96, height: 96))
            let mountain = UIBezierPath(); mountain.move(to: CGPoint(x: 0, y: 270))
            mountain.addCurve(to: CGPoint(x: 250, y: 235), controlPoint1: CGPoint(x: 100, y: 260), controlPoint2: CGPoint(x: 150, y: 125))
            mountain.addCurve(to: CGPoint(x: 535, y: 245), controlPoint1: CGPoint(x: 350, y: 150), controlPoint2: CGPoint(x: 440, y: 120))
            mountain.addCurve(to: CGPoint(x: 800, y: 210), controlPoint1: CGPoint(x: 670, y: 175), controlPoint2: CGPoint(x: 750, y: 190))
            mountain.addLine(to: CGPoint(x: 800, y: 500)); mountain.addLine(to: CGPoint(x: 0, y: 500)); mountain.close()
            color(green ? 0xACBFA7 : 0xA6B5AB).setFill(); mountain.fill()
            let front = UIBezierPath(); front.move(to: CGPoint(x: 0, y: 315))
            front.addCurve(to: CGPoint(x: 335, y: 270), controlPoint1: CGPoint(x: 150, y: 200), controlPoint2: CGPoint(x: 235, y: 320))
            front.addCurve(to: CGPoint(x: 650, y: 260), controlPoint1: CGPoint(x: 480, y: 200), controlPoint2: CGPoint(x: 550, y: 290))
            front.addLine(to: CGPoint(x: 800, y: 280)); front.addLine(to: CGPoint(x: 800, y: 500)); front.addLine(to: CGPoint(x: 0, y: 500)); front.close()
            color(green ? 0x7E9E86 : 0x748D86).setFill(); front.fill()
            color(sunset ? 0xD7CBB5 : 0xCCD9C8).setFill(); cg.fill(CGRect(x: 0, y: 340, width: 800, height: 160))
            cg.setStrokeColor(color(0xEEF0DF).cgColor); cg.setLineWidth(2)
            for i in 0..<7 { cg.move(to: CGPoint(x: CGFloat(445 - i * 14), y: CGFloat(368 + i * 13))); cg.addLine(to: CGPoint(x: CGFloat(640 + i * 8), y: CGFloat(368 + i * 13))); cg.strokePath() }
            let shore = UIBezierPath(); shore.move(to: CGPoint(x: 0, y: 420)); shore.addCurve(to: CGPoint(x: 180, y: 500), controlPoint1: CGPoint(x: 90, y: 360), controlPoint2: CGPoint(x: 145, y: 415)); shore.addLine(to: CGPoint(x: 0, y: 500)); shore.close()
            color(0x415F53).setFill(); shore.fill()
        }
        cache.setObject(image, forKey: kind as NSString); return image
    }
}

@MainActor
struct PhotoCover: View {
    @EnvironmentObject var store: TravelStore
    var reference: String
    var height: CGFloat = 190
    var body: some View {
        GeometryReader { proxy in
            if let image = store.image(reference) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped()
            } else {
                Image(uiImage: ScenicArtwork.image(kind: "demo-green")).resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped()
                    .overlay { if !reference.isEmpty { Label("照片缺失", systemImage: "photo.badge.exclamationmark").font(.caption).padding(8).background(.regularMaterial, in: Capsule()) } }
            }
        }.frame(height: height).accessibilityLabel(reference.isEmpty ? "默认风景插画" : "旅行照片")
    }
}

@MainActor
struct TagChips: View {
    var tags: [String]
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { ForEach(tags.prefix(4), id: \.self) { chip($0) } }
            HStack(spacing: 6) { ForEach(tags.prefix(2), id: \.self) { chip($0) }; if tags.count > 2 { Text("+\(tags.count - 2)").font(.caption).foregroundStyle(Theme.secondary) } }
        }
    }
    private func chip(_ tag: String) -> some View { Text("# " + tag).font(.system(size: 11)).foregroundStyle(Theme.green).lineLimit(1).padding(.horizontal, 9).padding(.vertical, 5).background(Theme.soft, in: Capsule()) }
}

@MainActor
struct PlaceRow: View {
    @EnvironmentObject var store: TravelStore
    let place: Place
    var body: some View {
        HStack(spacing: 12) {
            PhotoCover(reference: place.cover, height: 62).frame(width: 78).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) { if place.favorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.green) }; Text(place.title).font(.subheadline.weight(.semibold)).lineLimit(1) }
                Text(place.cityName + " · " + String(store.visits(for: place).count) + " 次记录").font(.caption).foregroundStyle(Theme.secondary).lineLimit(1)
            }
            Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.secondary)
        }.foregroundStyle(Theme.ink).padding(12).travelCard()
    }
}

@MainActor
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

@MainActor
struct FilterBar: View {
    @EnvironmentObject var store: TravelStore
    @Binding var year: String
    @Binding var tag: String
    @Binding var sort: SortOrder
    var clear: () -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu { Picker("年份", selection: $year) { Text("全部年份").tag(""); ForEach(store.years, id: \.self) { Text($0 + " 年").tag($0) } } } label: { filterLabel(year.isEmpty ? "全部年份" : year + " 年") }
                Menu { Picker("标签", selection: $tag) { Text("全部标签").tag(""); ForEach(store.allTags, id: \.self) { Text($0).tag($0) } } } label: { filterLabel(tag.isEmpty ? "全部标签" : tag) }
                Menu { Picker("排序", selection: $sort) { ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) } } } label: { filterLabel(sort.rawValue) }
                Button(action: clear) { Image(systemName: "arrow.counterclockwise").padding(10).background(.white, in: Circle()) }.accessibilityLabel("清除筛选")
            }
        }.foregroundStyle(Theme.green)
    }
    private func filterLabel(_ title: String) -> some View { HStack(spacing: 5) { Text(title).font(.caption); Image(systemName: "chevron.down").font(.system(size: 8)) }.padding(.horizontal, 12).padding(.vertical, 9).background(.white, in: Capsule()) }
}
