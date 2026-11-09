import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var subscription: SubscriptionManager

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image("BoboLogo")
                        .resizable().scaledToFit().frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.language.text("啵啵几何工坊", "Bobo Geometry Workshop")).font(.title3.bold())
                        Text(store.language.text("算清每一寸，再安心去吃猫条。", "Measure it right, then enjoy a cat treat.")).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                NavigationLink(value: MoreRoute.subscription) {
                    MoreRow(
                        title: store.language.text("啵啵会员", "Bobo Plus"),
                        symbol: "crown.fill",
                        detail: subscription.isSubscribed ? store.language.text("已开通", "Active") : store.language.text("场景工具", "Tools"),
                        color: .purple
                    )
                }
                NavigationLink { HistoryView() } label: {
                    MoreRow(title: store.language.text("历史计算", "History"), symbol: "clock.arrow.circlepath", detail: "\(store.history.count)", color: .blue)
                }
                NavigationLink { FontSettingsView() } label: {
                    MoreRow(title: store.language.text("字体大小", "Text Size"), symbol: "textformat.size", color: .indigo)
                }
                NavigationLink { SceneSettingsView() } label: {
                    MoreRow(title: store.language.text("场景设置", "Tool Settings"), symbol: "slider.horizontal.3", detail: "\(store.enabledSceneTools.count)", color: .orange)
                }
                NavigationLink { LanguageSettingsView() } label: {
                    MoreRow(title: store.language.text("语言", "Language"), symbol: "globe", detail: store.language.title, color: .teal)
                }
            }

            Section {
                NavigationLink { PrivacyPolicyView() } label: {
                    MoreRow(title: store.language.text("隐私政策", "Privacy Policy"), symbol: "hand.raised.fill", color: .green)
                }
                Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                    MoreRow(title: store.language.text("使用条款", "Terms of Use"), symbol: "doc.text.fill", color: .indigo)
                }
                NavigationLink { AboutBoboView() } label: {
                    MoreRow(title: store.language.text("关于啵啵", "About Bobo"), symbol: "pawprint.fill", color: .pink)
                }
            }
        }
        .navigationTitle(store.language.text("更多", "More"))
    }
}

private struct MoreRow: View {
    let title: String
    let symbol: String
    var detail: String?
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.white).frame(width: 30, height: 30).background(color, in: RoundedRectangle(cornerRadius: 8))
            Text(title)
            Spacer()
            if let detail { Text(detail).foregroundStyle(.secondary).monospacedDigit() }
        }
        .padding(.vertical, 3)
    }
}

private struct LanguageSettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List(AppLanguage.allCases) { language in
            Button {
                store.language = language
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(language.title).foregroundStyle(.primary)
                        Text(language == .simplifiedChinese ? "Chinese (Simplified)" : "英文")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.language == language {
                        Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.boboBlue)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(store.language.text("语言", "Language"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
