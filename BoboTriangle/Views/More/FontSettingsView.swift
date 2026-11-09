import SwiftUI

struct FontSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("font_size_level_ios_v1") private var level = 2
    private var labels: [String] {
        store.language == .simplifiedChinese
            ? ["特小", "较小", "标准", "较大", "大", "特大", "超大"]
            : ["Extra Small", "Small", "Standard", "Large", "Extra Large", "XX Large", "XXX Large"]
    }

    var body: some View {
        List {
            Section(store.language.text("预览", "Preview")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(store.language.text("三角形计算结果", "Triangle Result")).font(.headline)
                    HStack { Text(store.language.text("边 a", "Side a")); Spacer(); Text("5").fontWeight(.semibold); Text("∠A"); Spacer(); Text("36.87°").fontWeight(.semibold) }
                }
                .padding(.vertical, 8)
            }
            Section {
                VStack(spacing: 14) {
                    HStack { Text(store.language.text("字体大小", "Text Size")); Spacer(); Text(labels[level]).foregroundStyle(.secondary) }
                    HStack {
                        Text("A").font(.caption)
                        Slider(value: Binding(get: { Double(level) }, set: { level = Int($0.rounded()) }), in: 0...6, step: 1).tint(.boboBlue)
                        Text("A").font(.title2)
                    }
                }
                .padding(.vertical, 5)
            } footer: {
                Text(store.language.text("应用仍会尊重 iOS 的辅助功能字体设置；这里用于微调应用内显示。", "The app still respects iOS accessibility text settings; use this control for an additional adjustment."))
            }
        }
        .navigationTitle(store.language.text("字体大小", "Text Size"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
