import SwiftUI

@MainActor
struct JournalView: View {
    @EnvironmentObject var store: TravelStore
    var favoritesOnly = false
    @State private var search = ""
    @State private var year = ""
    @State private var tag = ""
    @State private var sort: SortOrder = .newest
    @State private var editor: EditorRequest?
    private var matching: [Place] { TravelRules.filtered(store.places, provinces: store.provinces, search: search, year: year, tag: tag, favorites: favoritesOnly, sort: sort) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(favoritesOnly ? "想再去一次的地方。" : "每一站，都有自己的故事。").font(.title2.weight(.semibold))
                    FilterBar(year: $year, tag: $tag, sort: $sort) { clear() }
                    Text("\(matching.count) 篇手记" + (store.isDemo ? " · 示例" : "")).font(.caption).foregroundStyle(Theme.secondary)
                    if matching.isEmpty { ContentUnavailableView(favoritesOnly ? "还没有匹配的收藏" : "还没有匹配的手记", systemImage: favoritesOnly ? "star" : "book.closed", description: Text(favoritesOnly ? "在详情中点亮星标，或清除筛选。" : "试试清除筛选，或记录一段新旅程。")) }
                    LazyVStack(spacing: 16) {
                        ForEach(matching) { p in NavigationLink(value: p.id) { StoryCard(place: p) }.buttonStyle(.plain) }
                    }
                }.padding(20)
            }.background(Theme.paper)
                .navigationTitle(favoritesOnly ? "我的收藏" : "旅行手记").navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, prompt: "搜索地点、标签或感受")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { editor = EditorRequest() } label: { Image(systemName: "plus") }.accessibilityLabel("新建打卡点") } }
                .sheet(item: $editor) { PlaceEditor(request: $0) }
                .navigationDestination(for: String.self) { DetailView(placeID: $0) }
                .onChange(of: store.allTags) { _, tags in if !tags.contains(tag) { tag = "" } }
                .onChange(of: store.years) { _, years in if !years.contains(year) { year = "" } }
        }
    }
    private func clear() { search = ""; year = ""; tag = ""; sort = .newest }
}

@MainActor
struct StoryCard: View {
    @EnvironmentObject var store: TravelStore
    let place: Place
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhotoCover(reference: place.cover, height: 185)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 7) { if place.favorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.green) }; Text(place.title).font(.system(size: 18, weight: .semibold)).lineLimit(2) }
                Text(store.location(place) + " · " + place.timestamp).font(.caption2).foregroundStyle(Theme.secondary)
                Text(place.visitHeading).font(.subheadline).foregroundStyle(Theme.green)
                if !place.tags.isEmpty { TagChips(tags: place.tags) }
                if !place.note.isEmpty { Text(place.note).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.7)).lineLimit(2).lineSpacing(3) }
            }.padding(17)
        }.foregroundStyle(Theme.ink).travelCard().clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

@MainActor
struct AlbumView: View {
    @EnvironmentObject var store: TravelStore
    @State private var search = ""
    @State private var year = ""
    @State private var tag = ""
    @State private var sort: SortOrder = .newest
    @State private var page: PhotoPage?
    private var matching: [Place] { TravelRules.filtered(store.places, provinces: store.provinces, search: search, year: year, tag: tag, sort: sort) }
    private var photoCount: Int { matching.reduce(0) { $0 + $1.photos.count } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("把路上的光，收藏起来。").font(.title2.weight(.semibold))
                    FilterBar(year: $year, tag: $tag, sort: $sort) { search = ""; year = ""; tag = ""; sort = .newest }
                    Text("\(photoCount) 张照片" + (store.isDemo ? " · 示例插画" : "")).font(.caption).foregroundStyle(Theme.secondary)
                    if photoCount == 0 { ContentUnavailableView("还没有匹配的照片", systemImage: "photo", description: Text("编辑手记添加照片，或清除当前筛选。")) }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 15) {
                        ForEach(matching) { p in
                            ForEach(Array(p.photos.enumerated()), id: \.offset) { index, reference in
                                Button { page = PhotoPage(placeID: p.id, index: index) } label: {
                                    VStack(alignment: .leading, spacing: 0) { PhotoCover(reference: reference, height: 145); VStack(alignment: .leading, spacing: 4) { Text(p.title).font(.caption).lineLimit(1); Text(p.timestamp).font(.caption2).foregroundStyle(Theme.secondary).lineLimit(1) }.padding(10) }.foregroundStyle(Theme.ink).travelCard().clipShape(RoundedRectangle(cornerRadius: 14))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.padding(20)
            }.background(Theme.paper).navigationTitle("瞬间收藏").navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, prompt: "搜索所属手记的地点或标签")
                .sheet(item: $page) { PhotoViewer(page: $0) }
                .onChange(of: store.allTags) { _, tags in if !tags.contains(tag) { tag = "" } }
                .onChange(of: store.years) { _, years in if !years.contains(year) { year = "" } }
        }
    }
}
