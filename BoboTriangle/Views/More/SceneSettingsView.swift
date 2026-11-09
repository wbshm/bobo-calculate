import SwiftUI

struct SceneSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var pendingLastDisable: Int?

    var body: some View {
        List {
            Section {
                Toggle(store.language.text("显示场景页", "Show Tools Tab"), isOn: $store.sceneEnabled)
                    .tint(.boboBlue)
            } footer: {
                Text(store.language.text("关闭后底部导航会隐藏“场景”。工具配置会保留。", "Turning this off hides the Tools tab while preserving tool settings."))
            }
            Section {
                ForEach(Array(store.sceneTools.enumerated()), id: \.element.id) { index, preference in
                    HStack(spacing: 12) {
                        Image(systemName: preference.id.symbol).foregroundStyle(Color.boboBlue).frame(width: 28)
                        Text(preference.id.title(language: store.language))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.sceneTools.indices.contains(index) && store.sceneTools[index].isEnabled },
                            set: { enabled in requestToggle(index: index, enabled: enabled) }
                        )).labelsHidden().tint(.boboBlue)
                    }
                }
                .onMove { source, destination in store.sceneTools.move(fromOffsets: source, toOffset: destination) }
            } header: {
                HStack { Text(store.language.text("工具与顺序", "Tools and Order")); Spacer(); Text(store.language.text("已开启 \(store.sceneTools.filter(\.isEnabled).count) 个", "\(store.sceneTools.filter(\.isEnabled).count) enabled")) }
            } footer: {
                Text(store.language.text("拖动右侧排序手柄即可调整顺序。", "Drag the reorder handles to change the order."))
            }
            Section {
                Button(store.language.text("恢复默认工具和顺序", "Restore Default Tools and Order")) { store.restoreDefaultScenes() }
            }
        }
        .navigationTitle(store.language.text("场景设置", "Tool Settings"))
        .environment(\.editMode, .constant(.active))
        .alert(store.language.text("隐藏场景页？", "Hide the Tools tab?"), isPresented: Binding(
            get: { pendingLastDisable != nil },
            set: { if !$0 { pendingLastDisable = nil } }
        )) {
            Button(store.language.text("保留", "Keep"), role: .cancel) { pendingLastDisable = nil }
            Button(store.language.text("关闭", "Hide"), role: .destructive) {
                if let index = pendingLastDisable, store.sceneTools.indices.contains(index) {
                    store.sceneTools[index].isEnabled = false
                    store.sceneEnabled = false
                }
                pendingLastDisable = nil
            }
        } message: {
            Text(store.language.text("关闭最后一个工具后，底部导航中的“场景”将隐藏。", "Disabling the last tool also hides the Tools tab."))
        }
    }

    private func requestToggle(index: Int, enabled: Bool) {
        guard store.sceneTools.indices.contains(index) else { return }
        if !enabled, store.sceneTools[index].isEnabled, store.sceneTools.filter(\.isEnabled).count == 1 {
            pendingLastDisable = index
            return
        }
        store.sceneTools[index].isEnabled = enabled
        if enabled { store.sceneEnabled = true }
    }
}
