import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct SettingsView: View {
    @EnvironmentObject var store: TravelStore
    @State private var importer = false
    @State private var busy = false
    @State private var confirmRestore = false
    @State private var prepared: PreparedBackup?
    @State private var shared: SharedFile?
    @State private var errorText: String?
    @State private var restored = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) { Image("AppLandscape").resizable().scaledToFill().frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 14)); VStack(alignment: .leading, spacing: 5) { Text("山河足迹").font(.title3.weight(.semibold)); Text("iOS 1.3 · 地点与时光").font(.caption).foregroundStyle(Theme.secondary) } }
                }
                if !store.warning.isEmpty { Section("读取提示") { Text(store.warning).font(.subheadline).foregroundStyle(.orange) } }
                Section {
                    Button { exportBackup() } label: { Label("导出完整备份", systemImage: "square.and.arrow.up") }.disabled(busy || store.isDemo)
                    Button { importer = true } label: { Label("从备份恢复", systemImage: "square.and.arrow.down") }.disabled(busy)
                    if busy { HStack { ProgressView(); Text("正在处理，请稍候…").font(.caption) } }
                    if store.deleted != nil { Button { do { try store.undoDelete() } catch { errorText = error.localizedDescription } } label: { Label("撤销最近一次删除", systemImage: "arrow.uturn.backward") } }
                } header: { Text("记录与备份") } footer: { Text("完整 ZIP 包含记录及引用的照片，可在 Windows v1.2 / v1.3 和此 iOS 版之间迁移。当前 iOS 归档及解压总量限制为 256 MB；不支持 ZIP64 或加密 ZIP。") }
                Section("本地存储") {
                    LabeledContent("收藏地点", value: "\(store.locationCount) 个")
                    LabeledContent("到访记录", value: "\(store.places.count) 次")
                    LabeledContent("照片", value: "\(store.places.reduce(0) { $0 + $1.photos.count }) 张")
                    LabeledContent("存储方式", value: "本机离线")
                    Text("记录保存在此 App 的 Documents/Shanhe 中。卸载 App 会删除本地数据，请先导出备份；此版本不自动云同步。照片副本和示例插画都不会修改系统相册原图。")
                        .font(.caption).foregroundStyle(Theme.secondary)
                }
                Section("使用提示") {
                    tip("追加到访", "在地点详情点“追加一段时光”。不同日期和时间分别保存照片、随笔、心情、标签与收藏；长按时间卡片可打开操作菜单。")
                    tip("新增与编辑", "在山河或手记页点击＋。编辑时通过系统相册选择照片，点照片设为封面，保存后才写入本机。")
                    tip("地图定位", "点省份下钻，或使用省市菜单。标记按城市中心显示；自定义地区使用所属省份中心。")
                    tip("收藏与标签", "在详情点亮星标。用逗号或空格分隔标签，最多 10 个。手记、相册与收藏可按年份和标签筛选。")
                    tip("分享单篇手记", "详情中的“导出手记”可生成含照片的离线 HTML 或 TXT。导出后可在系统分享面板选择存储到“文件”。")
                    tip("备份恢复", "恢复会替换当前记录，不会自动合并。建议先导出当前数据；校验通过后仍会要求确认。")
                    tip("删除撤销", "顶部撤销入口仅恢复本次运行中最近一次删除，关闭 App 或恢复备份后清空。")
                }
            }.scrollContentBackground(.hidden).background(Theme.paper).navigationTitle("设置与备份").navigationBarTitleDisplayMode(.inline)
                .sheet(item: $shared) { ShareSheet(url: $0.url) }
                .fileImporter(isPresented: $importer, allowedContentTypes: [.zip]) { result in
                    switch result {
                    case .success(let url):
                        Task { @MainActor in
                            busy = true; defer { busy = false }
                            do { prepared = try await store.prepareBackup(from: url); confirmRestore = true } catch { errorText = error.localizedDescription }
                        }
                    case .failure(let error): errorText = error.localizedDescription
                    }
                }
                .confirmationDialog("恢复备份会替换当前全部记录。建议先导出当前数据。", isPresented: $confirmRestore, titleVisibility: .visible) {
                    Button("确认恢复 \(prepared?.places.count ?? 0) 条记录", role: .destructive) {
                        guard let backup = prepared else { return }
                        do { try store.restore(backup); prepared = nil; restored = true } catch { errorText = error.localizedDescription }
                    }
                    Button("取消", role: .cancel) { prepared = nil }
                }
                .alert("恢复完成", isPresented: $restored) { Button("知道了", role: .cancel) {} } message: { Text("记录、照片、标签和收藏已恢复。") }
                .alert("操作未完成", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) { Button("知道了", role: .cancel) {} } message: { Text(errorText ?? "") }
        }
    }
    private func tip(_ title: String, _ text: String) -> some View { VStack(alignment: .leading, spacing: 6) { Text(title).font(.subheadline.weight(.medium)); Text(text).font(.caption).foregroundStyle(Theme.secondary) }.padding(.vertical, 4) }
    private func exportBackup() {
        Task { @MainActor in
            busy = true; defer { busy = false }
            do { shared = SharedFile(url: try await store.backup()) } catch { errorText = error.localizedDescription }
        }
    }
}
