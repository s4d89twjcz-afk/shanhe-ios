import SwiftUI

@MainActor
struct MapHomeView: View {
    @EnvironmentObject var store: TravelStore
    @State private var provinceCode = ""
    @State private var cityCode = ""
    @State private var search = ""
    @State private var path: [String] = []
    @State private var editor: EditorRequest?
    @State private var lastMemory: String?
    private var province: MapProvince? { store.provinces.first { $0.code == provinceCode } }
    private var city: MapCity? { province?.cities.first { $0.code == cityCode } }
    private var visiblePlaces: [Place] {
        TravelRules.locations(TravelRules.filtered(store.places, provinces: store.provinces, search: search).filter { (provinceCode.isEmpty || $0.provinceCode == provinceCode) && (cityCode.isEmpty || $0.cityCode == cityCode) })
    }
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    introduction
                    statistics
                    mapCard
                    HStack {
                        Text(provinceCode.isEmpty ? "最近的足迹" : "这里的足迹").font(.headline)
                        Spacer()
                        Button { if let memory = store.randomMemory(excluding: lastMemory) { lastMemory = memory.id; provinceCode = memory.provinceCode; cityCode = ""; path.append(memory.id) } } label: { Label("随机回顾", systemImage: "arrow.clockwise").font(.caption) }
                    }
                    TextField("搜索名称、地点、标签或感受", text: $search).font(.subheadline).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12))
                    if visiblePlaces.isEmpty { ContentUnavailableView("这里还没有足迹", systemImage: "mappin.and.ellipse", description: Text("记录一个地方，让这一段故事开始。")) }
                    ForEach(visiblePlaces) { p in NavigationLink(value: p.id) { PlaceRow(place: p) }.buttonStyle(.plain) }
                    Text("山川湖海，都有回响。\n本地离线保存 · 私人旅行日记").font(.caption2).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.top, 10)
                }.padding(20)
            }.background(Theme.paper)
                .navigationTitle("山河足迹").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { editor = EditorRequest(province: provinceCode, city: cityCode) } label: { Image(systemName: "plus.circle.fill").font(.title3) }.accessibilityLabel("新建打卡点") } }
                .sheet(item: $editor) { PlaceEditor(request: $0) }
                .navigationDestination(for: String.self) { DetailView(placeID: $0) }
                .onChange(of: provinceCode) { _, _ in cityCode = "" }
        }
    }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 9) {
            GeometryReader { proxy in Image("LandscapeCover").resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped() }.frame(height: 142).clipShape(RoundedRectangle(cornerRadius: 20))
            Text("\(store.locationCount) 个地点 · \(store.places.count) 次到访" + (store.isDemo ? " · 示例" : "")).font(.caption).foregroundStyle(Theme.secondary)
            if !store.warning.isEmpty { Label(store.warning, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange) }
        }
    }
    private var statistics: some View {
        HStack(spacing: 8) {
            stat("收藏的地点", count: String(store.locationCount))
            stat("去过的城市", count: String(Set(store.places.map { $0.provinceCode + "/" + $0.cityCode }).count))
            stat("探索的省份", count: "\(Set(store.places.map(\.provinceCode)).count)/34")
            stat("收藏的照片", count: String(store.places.reduce(0) { $0 + $1.photos.count }))
        }
    }
    private func stat(_ title: String, count: String) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 9)).foregroundStyle(Theme.secondary).lineLimit(1).minimumScaleFactor(0.7); Text(count).font(.system(size: 23, weight: .semibold)).minimumScaleFactor(0.7).lineLimit(1) }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 13).travelCard()
    }
    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 5) { Text(province?.name ?? "我的山河地图").font(.headline); Text(city?.name ?? (province == nil ? "点击省份，探索城市与足迹" : "点击城市，或从列表选择地区")).font(.caption2).foregroundStyle(Theme.secondary) }
                Spacer()
                if province != nil { Button("全国") { provinceCode = ""; cityCode = "" }.font(.caption).buttonStyle(.bordered) }
            }
            HStack {
                Menu { Picker("省份", selection: $provinceCode) { Text("全国").tag(""); ForEach(store.provinces) { Text($0.name).tag($0.code) } } } label: { Label("选择省份", systemImage: "line.3.horizontal.decrease").font(.caption) }
                Spacer()
                if let p = province { Menu { Picker("城市 / 地区", selection: $cityCode) { Text("全部地区").tag(""); ForEach(p.cities) { Text($0.name).tag($0.code) } } } label: { Label("选择城市", systemImage: "mappin").font(.caption) } }
            }
            ChinaMapView(provinceCode: $provinceCode, cityCode: $cityCode) { path.append($0) }
            HStack { Text("● 已有足迹  ○ 尚待探索"); Spacer(); Text("双指缩放 · 拖动平移") }.font(.system(size: 8)).foregroundStyle(Theme.secondary)
            Button { editor = EditorRequest(province: provinceCode, city: cityCode) } label: { Label(city == nil ? "记录新的足迹" : "在\(city!.name)留下足迹", systemImage: "plus").font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 5) }.buttonStyle(.borderedProminent).tint(Theme.green)
        }.padding(15).travelCard()
    }
}
