import SwiftUI
import PhotosUI
import UIKit

@MainActor
struct PlaceEditor: View {
    @EnvironmentObject var store: TravelStore
    @Environment(\.dismiss) private var dismiss
    let request: EditorRequest
    let onSaved: ((String) -> Void)?
    @State private var draft: Place
    @State private var chosenDate: Date
    @State private var tagsText: String
    @State private var selectedCity: String
    @State private var customCity: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var newImages: [String: Data] = [:]
    @State private var importing = false
    @State private var errorText: String?
    @State private var importTask: Task<Void, Never>?

    init(request: EditorRequest, onSaved: ((String) -> Void)? = nil) {
        self.request = request
        self.onSaved = onSaved
        var initial = request.place ?? Place()
        if request.append, let previous = request.place {
            initial = Place(); initial.title = previous.title; initial.provinceCode = previous.provinceCode; initial.cityCode = previous.cityCode; initial.cityName = previous.cityName; initial.locationId = previous.locationKey; initial.tags = previous.tags; initial.mood = previous.mood; initial.favorite = previous.favorite; initial.time = TravelRules.currentTime()
        } else if request.place == nil { initial.time = TravelRules.currentTime() }
        if request.place == nil && !request.province.isEmpty { initial.provinceCode = request.province; initial.cityCode = request.city }
        _draft = State(initialValue: initial); _chosenDate = State(initialValue: TravelRules.parseDate(initial.date) ?? Date())
        _tagsText = State(initialValue: initial.tags.joined(separator: "，"))
        _selectedCity = State(initialValue: initial.cityCode.hasPrefix("custom-") ? "custom" : initial.cityCode)
        _customCity = State(initialValue: initial.cityName)
    }
    private var province: MapProvince? { store.provinces.first { $0.code == draft.provinceCode } }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例如：西湖 · 四季收藏", text: $draft.title).textInputAutocapitalization(.never).disabled(request.append)
                    Picker("省份", selection: $draft.provinceCode) { ForEach(store.provinces) { Text($0.name).tag($0.code) } }.disabled(request.append)
                        .onChange(of: draft.provinceCode) { _, _ in selectedCity = province?.cities.first?.code ?? "custom"; customCity = "" }
                    Picker("城市 / 地区", selection: $selectedCity) { ForEach(province?.cities ?? []) { Text($0.name).tag($0.code) }; Text("自行输入地区").tag("custom") }.disabled(request.append)
                    if selectedCity == "custom" { TextField("填写城市、县或地区名称", text: $customCity).disabled(request.append) }
                    TextField("这次记录的标题，例如：再次遇见日落", text: $draft.visitTitle)
                    TextField("时间 HH:mm，可留空，例如 18:30", text: $draft.time).keyboardType(.numbersAndPunctuation)
                    DatePicker("打卡日期", selection: $chosenDate, displayedComponents: .date)
                    Picker("此刻的心情", selection: $draft.mood) { ForEach(TravelRules.moods, id: \.self) { Text($0).tag($0) } }
                } header: { Text("地点与时刻") }
                Section {
                    TextEditor(text: $draft.note).frame(minHeight: 130).overlay(alignment: .topLeading) { if draft.note.isEmpty { Text("写下沿途的风景，也记下此刻的心情…").foregroundStyle(.tertiary).padding(.top, 8).allowsHitTesting(false) } }
                } header: { Text("此刻的感受") }
                Section {
                    TextField("美食，徒步，日落", text: $tagsText)
                    Toggle(isOn: $draft.favorite) { Label("加入我的收藏", systemImage: "star") }
                } header: { Text("标签与收藏") } footer: { Text("标签用逗号或空格分隔，最多 10 个，每个最多 20 字。") }
                Section {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 20, selectionBehavior: .ordered, matching: .images) { Label(importing ? "正在导入照片…" : "从相册添加照片", systemImage: "photo.badge.plus") }.disabled(importing)
                    if importing { ProgressView().frame(maxWidth: .infinity) }
                    photoGrid
                } header: { Text("照片与封面 · \(draft.photos.count) 张") } footer: { Text("点图片设为封面。保存后照片复制到应用内，原图不改变。每次最多选择 20 张，可多次添加。") }
            }
            .scrollContentBackground(.hidden).background(Theme.paper)
            .navigationTitle(request.append ? "追加一段时光" : request.place == nil ? "收藏一个地点" : "编辑这次记录").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save).fontWeight(.semibold).disabled(importing) }
            }
            .onAppear { if selectedCity != "custom" && !(province?.cities.contains { $0.code == selectedCity } ?? false) { selectedCity = province?.cities.first?.code ?? "custom" } }
            .onChange(of: selectedPhotos) { _, items in
                guard !items.isEmpty else { return }; importTask?.cancel()
                importTask = Task { await loadPhotos(items) }
            }
            .onDisappear { importTask?.cancel() }
            .alert("操作未完成", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) { Button("知道了", role: .cancel) {} } message: { Text(errorText ?? "") }
        }
    }
    private var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 12)], spacing: 12) {
            ForEach(draft.photos, id: \.self) { name in
                VStack(spacing: 6) {
                    Button { draft.cover = name } label: {
                        Group {
                            if let data = newImages[name], let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
                            else if let image = store.image(name, maxDimension: 350) { Image(uiImage: image).resizable().scaledToFill() }
                            else { Image(systemName: "photo.badge.exclamationmark").resizable().scaledToFit().padding(20) }
                        }.frame(height: 90).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(draft.cover == name ? Theme.green : Theme.line, lineWidth: draft.cover == name ? 3 : 1))
                    }.buttonStyle(.plain).accessibilityLabel("设为封面")
                    HStack {
                        Text(draft.cover == name ? "✓ 当前封面" : "设为封面").font(.system(size: 10)).foregroundStyle(Theme.secondary)
                        Spacer(minLength: 1)
                        Button(role: .destructive) { draft.photos.removeAll { $0 == name }; newImages.removeValue(forKey: name); if draft.cover == name { draft.cover = draft.photos.first ?? "" } } label: { Image(systemName: "xmark.circle.fill").font(.caption) }.buttonStyle(.borderless).accessibilityLabel("移除此照片")
                    }
                }
            }
        }.padding(.vertical, 8)
    }
    @MainActor private func loadPhotos(_ items: [PhotosPickerItem]) async {
        importing = true; var failures = [String]()
        defer { importing = false; selectedPhotos = [] }
        for item in items {
            do {
                try Task.checkCancellation()
                guard let data = try await item.loadTransferable(type: Data.self) else { throw TravelError.message("一张照片无法下载或读取。") }
                let normalized = try await Task.detached(priority: .userInitiated) { try TravelStore.normalizePhoto(data) }.value
                try Task.checkCancellation()
                let name = "pending-" + UUID().uuidString
                newImages[name] = normalized; draft.photos.append(name)
                if draft.cover.isEmpty { draft.cover = name }
            } catch is CancellationError { return }
            catch { failures.append(error.localizedDescription) }
        }
        if !failures.isEmpty { errorText = failures.joined(separator: "\n") }
    }
    private func save() {
        do {
            draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !draft.title.isEmpty, draft.title.count <= 100 else { throw TravelError.message("请填写名称，最多 100 字。") }
            draft.time = draft.time.trimmingCharacters(in: .whitespacesAndNewlines); draft.visitTitle = draft.visitTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard TravelRules.validTime(draft.time) else { throw TravelError.message("时间请填写 HH:mm，例如 08:30 或 18:45；也可留空。") }
            guard draft.visitTitle.count <= 100 else { throw TravelError.message("记录标题最多 100 字。") }
            guard draft.note.count <= 50000 else { throw TravelError.message("感受最多 50,000 字。") }
            if selectedCity == "custom" {
                let name = customCity.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, name.count <= 80 else { throw TravelError.message("请填写城市 / 地区名称，最多 80 字。") }
                draft.cityName = name; draft.cityCode = "custom-" + name
            } else if let city = province?.cities.first(where: { $0.code == selectedCity }) { draft.cityName = city.name; draft.cityCode = city.code }
            else { throw TravelError.message("请选择城市 / 地区。") }
            draft.date = TravelRules.dateString(chosenDate); draft.tags = try TravelRules.tags(tagsText)
            try store.save(draft, newImages: newImages); onSaved?(draft.id); dismiss()
        } catch { errorText = error.localizedDescription }
    }
}
