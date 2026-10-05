import SwiftUI
import UIKit

@MainActor
struct DetailView: View {
    @EnvironmentObject var store: TravelStore
    @Environment(\.dismiss) private var dismiss
    let placeID: String
    @State private var selectedID: String
    @State private var editor: EditorRequest?
    @State private var photo: PhotoPage?
    @State private var shared: SharedFile?
    @State private var moving: Place?
    @State private var confirmingDelete = false
    @State private var errorText: String?
    init(placeID: String) { self.placeID = placeID; _selectedID = State(initialValue: placeID) }
    private var place: Place? { store.places.first { $0.id == selectedID } ?? store.places.first { $0.id == placeID } }
    var body: some View {
        Group {
            if let p = place {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        PhotoCover(reference: p.cover, height: 235)
                            .onTapGesture { if !p.photos.isEmpty { photo = PhotoPage(placeID: p.id, index: p.photos.firstIndex(of: p.cover) ?? 0) } }
                        VStack(alignment: .leading, spacing: 18) {
                            Text(p.title).font(.system(size: 27, weight: .semibold)).foregroundStyle(Theme.ink)
                            Label(store.location(p), systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(Theme.secondary)
                            timeline(p)
                            entryContent(p)
                        }.padding(21)
                    }.background(.white)
                }.background(Theme.paper)
                    .navigationTitle("地点与时光").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu { recordActions(p) } label: { Image(systemName: "ellipsis.circle") } } }
                    .confirmationDialog("删除 \(p.timestamp) 的这次记录？其他到访会保留。", isPresented: $confirmingDelete, titleVisibility: .visible) {
                        Button("删除这次记录", role: .destructive) {
                            do {
                                let remaining = store.visits(for: p).filter { $0.id != p.id }
                                try store.delete(p.id)
                                if let next = remaining.first { selectedID = next.id } else { dismiss() }
                            } catch { errorText = error.localizedDescription }
                        }
                    }
            } else {
                ContentUnavailableView("这条记录已移出", systemImage: "book.closed", description: Text("可通过顶部撤销入口恢复最近一次删除。"))
            }
        }
        .sheet(item: $editor) { request in PlaceEditor(request: request, onSaved: { selectedID = $0 }) }
        .sheet(item: $photo) { PhotoViewer(page: $0) }
        .sheet(item: $shared) { ShareSheet(url: $0.url) }
        .sheet(item: $moving) { MoveVisitView(record: $0) }
        .alert("操作未完成", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) { Button("知道了", role: .cancel) {} } message: { Text(errorText ?? "") }
    }
    private func timeline(_ p: Place) -> some View {
        let visits = store.visits(for: p)
        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("地点时间线 · \(visits.count) 次记录").font(.headline)
                Spacer()
                if !store.isDemo { Button { editor = EditorRequest(place: p, append: true) } label: { Image(systemName: "plus.circle.fill").font(.title3) }.accessibilityLabel("为此地点追加记录") }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(visits) { entry in
                        Button { selectedID = entry.id } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(entry.timestamp).font(.system(size: 10)).foregroundStyle(Theme.secondary)
                                Text(entry.visitHeading).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink).lineLimit(2)
                                Text("\(entry.photos.count) 张照片" + (entry.favorite ? " · ★" : "")).font(.caption2).foregroundStyle(Theme.green)
                            }.frame(width: 158, height: 85, alignment: .leading).padding(12)
                                .background(entry.id == p.id ? Theme.soft : Theme.paper, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(entry.id == p.id ? Theme.green.opacity(0.35) : Theme.line))
                        }.buttonStyle(.plain).contextMenu { recordActions(entry) }
                    }
                }
            }
            if !store.isDemo {
                Button { editor = EditorRequest(place: p, append: true) } label: { Label("追加一段时光", systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(Theme.green)
            }
        }
    }
    private func entryContent(_ p: Place) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Text((store.isDemo ? "示例 / " : "") + p.timestamp).font(.caption).foregroundStyle(Theme.secondary); Spacer(); Text(p.mood).font(.caption).foregroundStyle(Theme.green) }
            Text(p.visitHeading).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
            if !p.tags.isEmpty { ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(p.tags, id: \.self) { TagChips(tags: [$0]) } } } }
            Text(p.note.isEmpty ? "暂时没有随笔，让照片先替你说话。" : p.note).font(.system(size: 15)).foregroundStyle(Theme.ink.opacity(0.8)).lineSpacing(7).textSelection(.enabled)
            HStack {
                Button { toggle(p) } label: { Label(p.favorite ? "已收藏" : "收藏这次", systemImage: p.favorite ? "star.fill" : "star") }
                Menu { Button("带照片的离线网页") { export(p, html: true) }; Button("纯文字手记") { export(p, html: false) } } label: { Label("导出", systemImage: "square.and.arrow.up") }
            }.font(.subheadline).buttonStyle(.bordered).tint(Theme.green)
            Text("这次的照片 · \(p.photos.count) 张").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 10) {
                ForEach(Array(p.photos.enumerated()), id: \.offset) { index, reference in
                    Button { photo = PhotoPage(placeID: p.id, index: index) } label: { PhotoCover(reference: reference, height: 102).clipShape(RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain)
                }
            }
            if store.isDemo { Button("新建我的地点") { editor = EditorRequest() }.buttonStyle(.borderedProminent).tint(Theme.green) }
            else { Button("编辑这次记录") { editor = EditorRequest(place: p) }.buttonStyle(.bordered).tint(Theme.green) }
            Text("长按时间卡片，或点右上角菜单打开操作。 ").font(.caption2).foregroundStyle(Theme.secondary)
        }.padding(15).background(Theme.paper, in: RoundedRectangle(cornerRadius: 16))
    }
    @ViewBuilder private func recordActions(_ p: Place) -> some View {
        Button("查看这次记录") { selectedID = p.id }
        if !store.isDemo {
            Button("为此地点追加记录") { editor = EditorRequest(place: p, append: true) }
            Button("编辑这次记录") { editor = EditorRequest(place: p) }
            Button("归入另一已有地点") { moving = p }
        }
        Button(p.favorite ? "取消这次收藏" : "收藏这次记录") { toggle(p) }
        Button("导出带照片的手记") { export(p, html: true) }
        Button("导出纯文字手记") { export(p, html: false) }
        if !store.isDemo { Button("删除这次记录", role: .destructive) { selectedID = p.id; confirmingDelete = true } }
    }
    private func toggle(_ p: Place) { do { try store.toggleFavorite(p.id) } catch { errorText = error.localizedDescription } }
    private func export(_ p: Place, html: Bool) { do { shared = SharedFile(url: try store.exportStory(p, html: html)) } catch { errorText = error.localizedDescription } }
}

@MainActor
struct MoveVisitView: View {
    @EnvironmentObject var store: TravelStore
    @Environment(\.dismiss) private var dismiss
    let record: Place
    @State private var target: Place?
    @State private var errorText: String?
    private var choices: [Place] { TravelRules.locations(store.places).filter { $0.locationKey != record.locationKey && $0.provinceCode == record.provinceCode && $0.cityCode == record.cityCode } }
    var body: some View {
        NavigationStack {
            List {
                Section { Text("只移动 \(record.timestamp) 的这次记录，保留照片与随笔。地点名称改为目标地点名称。建议先导出备份。").font(.caption).foregroundStyle(Theme.secondary) }
                if choices.isEmpty { Text("同一省市还没有其他地点。可以直接为当前地点追加记录。").font(.subheadline) }
                ForEach(choices) { p in Button { target = p } label: { PlaceRow(place: p) } }
            }.navigationTitle("归入已有地点").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
                .confirmationDialog("归入「\(target?.title ?? "")」？", isPresented: Binding(get: { target != nil }, set: { if !$0 { target = nil } }), titleVisibility: .visible) {
                    Button("确认归入") { guard let selected = target else { return }; do { try store.move(record, to: selected); dismiss() } catch { errorText = error.localizedDescription }; target = nil }
                    Button("取消", role: .cancel) { target = nil }
                }
                .alert("操作未完成", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) { Button("知道了", role: .cancel) {} } message: { Text(errorText ?? "") }
        }
    }
}

@MainActor
struct PhotoViewer: View {
    @EnvironmentObject var store: TravelStore
    @Environment(\.dismiss) private var dismiss
    let page: PhotoPage
    @State private var index: Int
    init(page: PhotoPage) { self.page = page; _index = State(initialValue: page.index) }
    private var photos: [String] { store.places.first { $0.id == page.placeID }?.photos ?? [] }
    var body: some View {
        NavigationStack {
            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.offset) { offset, reference in
                    ZoomPhoto(image: store.image(reference, maxDimension: 2400)).tag(offset)
                }
            }.tabViewStyle(.page(indexDisplayMode: .never)).background(Color(hex: 0x17241D))
                .navigationTitle(photos.isEmpty ? "照片" : "\(index + 1) / \(photos.count)").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}

@MainActor
struct ZoomPhoto: UIViewRepresentable {
    var image: UIImage?
    @MainActor final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = AdaptivePhotoScroll(); scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 4; scroll.delegate = context.coordinator
        scroll.backgroundColor = UIColor(red: 0.09, green: 0.14, blue: 0.11, alpha: 1)
        let imageView = context.coordinator.imageView; imageView.contentMode = .scaleAspectFit; scroll.photo = imageView; scroll.addSubview(imageView)
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.imageView.image = image
        if scroll.zoomScale == 1 { context.coordinator.imageView.frame = scroll.bounds; scroll.contentSize = scroll.bounds.size }
    }
}

final class AdaptivePhotoScroll: UIScrollView {
    var photo: UIImageView?
    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale == 1 { photo?.frame = bounds; contentSize = bounds.size }
    }
}
