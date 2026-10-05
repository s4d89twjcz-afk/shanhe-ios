import SwiftUI

@main
@MainActor
struct ShanheApp: App {
    @StateObject private var store = TravelStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).tint(Theme.green).preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .environment(\.calendar, Calendar(identifier: .gregorian))
        }
    }
}

@MainActor
struct RootView: View {
    @EnvironmentObject var store: TravelStore
    @State private var errorText: String?
    var body: some View {
        VStack(spacing: 0) {
            if let deleted = store.deleted {
                HStack(spacing: 8) {
                    Text("已删除：" + deleted.title).font(.caption).lineLimit(1)
                    Spacer(minLength: 3)
                    Button("撤销") { do { try store.undoDelete() } catch { errorText = error.localizedDescription } }.font(.caption.weight(.semibold))
                }.padding(.horizontal, 18).padding(.vertical, 10).background(Theme.soft)
            }
            TabView {
                MapHomeView().tabItem { Label("山河", systemImage: "map") }
                JournalView().tabItem { Label("手记", systemImage: "book.closed") }
                JournalView(favoritesOnly: true).tabItem { Label("收藏", systemImage: "star") }
                AlbumView().tabItem { Label("相册", systemImage: "photo.on.rectangle.angled") }
                SettingsView().tabItem { Label("设置", systemImage: "slider.horizontal.3") }
            }
        }.foregroundStyle(Theme.ink)
            .alert("操作未完成", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) { Button("知道了", role: .cancel) {} } message: { Text(errorText ?? "") }
    }
}
