import SwiftUI

struct MapFeature: Identifiable {
    var id: String; var name: String; var center: [Double]; var rings: [[[Double]]]
}
struct MapPinGroup: Identifiable { var places: [Place]; var id: String { places[0].provinceCode + "/" + places[0].cityCode } }

struct MapProjection {
    var minX: Double = 73, maxY: Double = 65, scale: CGFloat = 1, origin: CGPoint = .zero
    init(rings: [[[Double]]], size: CGSize, includeSouth: Bool) {
        let points = rings.flatMap { $0 }.filter { $0.count >= 2 && (includeSouth || $0[1] >= 17.5) }
        guard !points.isEmpty else { return }
        minX = points.map { $0[0] }.min() ?? 73
        let maxX = points.map { $0[0] }.max() ?? 135, minY = points.map { Self.mercator($0[1]) }.min() ?? 18
        maxY = points.map { Self.mercator($0[1]) }.max() ?? 65
        scale = min((size.width - 34) / CGFloat(max(0.08, maxX - minX)), (size.height - 28) / CGFloat(max(0.08, maxY - minY)))
        origin = CGPoint(x: (size.width - CGFloat(maxX - minX) * scale) / 2, y: (size.height - CGFloat(maxY - minY) * scale) / 2)
    }
    static func mercator(_ latitude: Double) -> Double { log(tan(.pi / 4 + latitude * .pi / 360)) * 180 / .pi }
    func point(_ coordinate: [Double]) -> CGPoint { CGPoint(x: origin.x + CGFloat(coordinate[0] - minX) * scale, y: origin.y + CGFloat(maxY - Self.mercator(coordinate[1])) * scale) }
    func path(_ rings: [[[Double]]], includeSouth: Bool) -> Path {
        var path = Path()
        for ring in rings {
            let points = ring.filter { $0.count >= 2 && (includeSouth || $0[1] >= 17.5) }.map(point)
            guard let first = points.first, points.count >= 3 else { continue }
            path.move(to: first); path.addLines(Array(points.dropFirst())); path.closeSubpath()
        }; return path
    }
}

@MainActor
struct ChinaMapView: View {
    @EnvironmentObject var store: TravelStore
    @Binding var provinceCode: String
    @Binding var cityCode: String
    var openPlace: (String) -> Void
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    private var province: MapProvince? { store.provinces.first { $0.code == provinceCode } }
    private var features: [MapFeature] {
        if let p = province {
            let cities = p.cities.filter { !$0.rings.isEmpty }
            if cities.isEmpty { return [MapFeature(id: p.code, name: p.name, center: p.center, rings: p.rings)] }
            return cities.map { MapFeature(id: $0.code, name: $0.name, center: $0.center, rings: $0.rings) }
        }
        return store.provinces.map { MapFeature(id: $0.code, name: $0.name, center: $0.center, rings: $0.rings) }
    }
    private var grouped: [MapPinGroup] {
        let visible = store.places.filter { provinceCode.isEmpty || $0.provinceCode == provinceCode }
        return Dictionary(grouping: visible, by: { $0.provinceCode + "/" + $0.cityCode }).values.map { MapPinGroup(places: TravelRules.ordered($0)) }.sorted { $0.id < $1.id }
    }
    var body: some View {
        GeometryReader { proxy in
            let rings = province?.rings ?? store.provinces.flatMap(\.rings)
            let projection = MapProjection(rings: rings, size: proxy.size, includeSouth: province != nil)
            ZStack {
                Theme.soft
                ZStack {
                    Canvas { context, size in
                        for feature in features {
                            let visited = store.places.contains { province == nil ? $0.provinceCode == feature.id : $0.provinceCode == provinceCode && $0.cityCode == feature.id }
                            let path = projection.path(feature.rings, includeSouth: province != nil)
                            context.fill(path, with: .color(cityCode == feature.id ? Color(hex: 0xA7C5A0) : visited ? Color(hex: 0xBFD5B8) : Color(hex: 0xDCE6D5)), style: FillStyle(eoFill: true))
                            context.stroke(path, with: .color(.white), lineWidth: 0.65)
                            let label = Text(short(feature.name)).font(.system(size: province == nil ? 7 : 8)).foregroundColor(Color(hex: 0x68805F))
                            context.draw(label, at: projection.point(feature.center))
                        }
                        if province == nil { drawInset(context: &context, size: size) }
                    }
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { event in
                        if let feature = features.reversed().first(where: { projection.path($0.rings, includeSouth: province != nil).contains(event.location, eoFill: true) }) {
                            if province == nil { provinceCode = feature.id; cityCode = "" }
                            else if feature.id != provinceCode { cityCode = feature.id }
                        }
                    })
                    ForEach(grouped) { cluster in
                        let group = cluster.places
                        if let first = group.first, let p = store.provinces.first(where: { $0.code == first.provinceCode }) {
                            let center = p.cities.first(where: { $0.code == first.cityCode })?.center ?? p.center
                            let position = province == nil && center[1] < 17.5 ? insetPoint(center, size: proxy.size) : projection.point(center)
                            Button { openPlace(first.id) } label: {
                                Text(TravelRules.locations(group).count > 1 ? String(TravelRules.locations(group).count) : "•").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).frame(width: 23, height: 23).background(Theme.green, in: Circle()).overlay(Circle().stroke(.white, lineWidth: 2))
                            }.position(position).accessibilityLabel(first.cityName + "，\(TravelRules.locations(group).count) 个地点，\(group.count) 次到访")
                        }
                    }
                }.frame(width: proxy.size.width, height: proxy.size.height).scaleEffect(zoom).offset(offset)
                    .simultaneousGesture(MagnificationGesture().onChanged { zoom = min(4, max(1, baseZoom * $0)) }.onEnded { _ in baseZoom = zoom })
                    .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { offset = CGSize(width: baseOffset.width + $0.translation.width, height: baseOffset.height + $0.translation.height) }.onEnded { _ in baseOffset = offset })
                VStack { HStack { Spacer(); Text("N\n↑").font(.system(size: 9)).foregroundStyle(Theme.secondary) }; Spacer(); HStack { Spacer(); Button { reset() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption).padding(9).background(.white, in: Circle()) }.accessibilityLabel("恢复地图视图") } }.padding(12)
            }.clipped().clipShape(RoundedRectangle(cornerRadius: 16))
        }.frame(height: 275).onChange(of: provinceCode) { _, _ in reset() }
    }
    private func reset() { zoom = 1; baseZoom = 1; offset = .zero; baseOffset = .zero }
    private func short(_ name: String) -> String { ["特别行政区", "维吾尔自治区", "壮族自治区", "回族自治区", "自治区", "自治州", "省", "市"].reduce(name) { $0.replacingOccurrences(of: $1, with: "") } }
    private func insetPoint(_ coordinate: [Double], size: CGSize) -> CGPoint { CGPoint(x: size.width - 67 + CGFloat(coordinate[0] - 105) * 2.4, y: size.height - 92 + CGFloat(24 - coordinate[1]) * 3.1) }
    private func drawInset(context: inout GraphicsContext, size: CGSize) {
        let frame = CGRect(x: size.width - 72, y: size.height - 95, width: 56, height: 80)
        context.stroke(Path(roundedRect: frame, cornerRadius: 4), with: .color(Theme.line), lineWidth: 0.7)
        for ring in store.seaRings + store.provinces.flatMap(\.rings) {
            let points = ring.filter { $0[0] >= 105 && $0[0] <= 125 && $0[1] >= 3 && $0[1] <= 23.5 }.map { insetPoint($0, size: size) }
            if points.count >= 3 { var path = Path(); path.addLines(points); path.closeSubpath(); context.fill(path, with: .color(Color(hex: 0xB8CDAE))) }
        }
        context.draw(Text("南海诸岛").font(.system(size: 6)).foregroundColor(Color(hex: 0x809176)), at: CGPoint(x: frame.midX, y: frame.maxY - 6))
    }
}
