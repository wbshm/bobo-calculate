import StoreKit
import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var subscription: SubscriptionManager

    @State private var message: String?
    @State private var isRestoring = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                benefits
                planCard
                purchaseSection
                footerSection
            }
            .padding(16)
        }
        .background(Color.boboBackground)
        .navigationTitle(store.language.text("啵啵会员", "Bobo Plus"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await subscription.loadProduct() }
        .alert(store.language.text("订阅提示", "Subscription"), isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button(store.language.text("好", "OK"), role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [Color.boboBlue, Color(red: 111 / 255, green: 91 / 255, blue: 224 / 255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "ruler.fill")
                .font(.system(size: 110, weight: .bold))
                .rotationEffect(.degrees(-18))
                .offset(x: 32, y: -18)
                .opacity(0.1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image("BoboLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(.white.opacity(0.7), lineWidth: 1)
                        }

                    Label(
                        subscription.isSubscribed
                            ? store.language.text("会员有效", "Membership Active")
                            : store.language.text("啵啵会员", "Bobo Plus"),
                        systemImage: subscription.isSubscribed ? "checkmark.seal.fill" : "sparkles"
                    )
                    .font(.subheadline.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(subscription.isSubscribed
                         ? store.language.text("会员工具箱已打开", "Your Toolbox Is Open")
                         : store.language.text("把实用计算装进口袋", "A Practical Toolbox in Your Pocket"))
                        .font(.title2.bold())
                    Text(subscription.isSubscribed
                         ? store.language.text("楼梯、木工、管道、坡高和斜撑计算，在订阅期间都可使用。", "Use the stairs, wood, pipe, slope, and brace calculators during your subscription.")
                         : store.language.text("订阅期间解锁楼梯、木工、管道、坡高和斜撑计算。", "Unlock the stairs, wood, pipe, slope, and brace calculators while subscribed."))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(store.language.text("楼梯 · 木工 · 管道 · 坡高 · 斜撑", "Stairs · Wood · Pipe · Slope · Brace"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.boboBlue.opacity(0.2), radius: 14, y: 7)
    }

    private var benefits: some View {
        BoboCard {
            VStack(alignment: .leading, spacing: 13) {
                Text(store.language.text("会员包含", "What's Included"))
                    .font(.headline)
                benefit("wrench.and.screwdriver.fill", store.language.text("全部现有工具", "Every Current Tool"), store.language.text("五类场景计算完整开放", "Full access to all five practical calculators"))
                benefit("function", store.language.text("完整计算过程", "Complete Calculations"), store.language.text("按输入绘图，并展示结果、公式和说明", "Diagrams, results, formulas, and notes from your inputs"))
                benefit("person.2.fill", store.language.text("家人共享", "Family Sharing"), store.language.text("已加入家庭共享的成员也可使用", "Available to eligible Family Sharing members"))
            }
        }
    }

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.boboBlue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.boboBlue)

                Text(subscription.monthlyProduct?.displayName ?? store.language.text("啵啵会员月度订阅", "Bobo Plus Monthly"))
                    .font(.headline)

                Spacer()

                if subscription.isLoadingProduct {
                    ProgressView()
                }
            }

            LabeledContent(store.language.text("订阅期限", "Subscription Length")) {
                Text(store.language.text("1 个月", "1 month"))
                    .fontWeight(.semibold)
            }
            .font(.subheadline)

            LabeledContent(store.language.text("订阅价格", "Subscription Price")) {
                Text(monthlyPriceDescription)
                    .font(.headline.monospacedDigit())
            }

            Text(store.language.text("自动续订 · 可随时取消", "Auto-renewable · Cancel anytime"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if subscription.monthlyProduct == nil, subscription.productLoadError != nil {
                HStack {
                    Text(store.language.text("暂时无法获取 App Store 价格。", "Unable to load the App Store price."))
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button(store.language.text("重试", "Retry")) {
                        Task { await subscription.loadProduct() }
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(16)
        .background(Color.boboBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.boboBlue.opacity(0.28), lineWidth: 1)
        }
    }

    private var monthlyPriceDescription: String {
        guard let product = subscription.monthlyProduct else { return "—" }
        return store.language.text("\(product.displayPrice) / 月", "\(product.displayPrice) / month")
    }

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if subscription.isSubscribed {
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    Label(store.language.text("管理订阅", "Manage Subscription"), systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    Task { await purchase() }
                } label: {
                    HStack {
                        if subscription.isPurchasing { ProgressView().tint(.white) }
                        Text(purchaseButtonTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(subscription.monthlyProduct == nil || subscription.isPurchasing)
            }

            Text(store.language.text(
                "确认购买后，款项将从你的 Apple 账户扣除。订阅按月自动续订；可随时在 Apple 账户的订阅设置中管理或取消。",
                "Payment is charged to your Apple Account after confirmation. The subscription renews monthly until canceled and can be managed in your Apple Account subscription settings."
            ))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
    }

    private var purchaseButtonTitle: String {
        guard let product = subscription.monthlyProduct else {
            return store.language.text("订阅并解锁", "Subscribe and Unlock")
        }
        return store.language.text("以 \(product.displayPrice)/月订阅", "Subscribe for \(product.displayPrice)/month")
    }

    private var footerSection: some View {
        VStack(spacing: 14) {
            Button {
                Task { await restore() }
            } label: {
                HStack(spacing: 7) {
                    if isRestoring { ProgressView().controlSize(.small) }
                    Image(systemName: "arrow.clockwise")
                    Text(store.language.text("恢复购买", "Restore Purchases"))
                }
                .frame(minWidth: 132)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .tint(Color.boboBlue)
            .font(.footnote.weight(.medium))
            .disabled(isRestoring || subscription.isPurchasing)

            HStack(spacing: 18) {
                Link(store.language.text("使用条款", "Terms of Use"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                NavigationLink(store.language.text("隐私政策", "Privacy Policy")) {
                    PrivacyPolicyView()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    private func purchase() async {
        switch await subscription.purchaseMonthlySubscription() {
        case .purchased:
            message = store.language.text("订阅成功，场景工具已解锁。", "Subscription successful. Practical tools are now unlocked.")
        case .cancelled:
            break
        case .pending:
            message = store.language.text("购买正在等待确认，完成后会自动解锁。", "The purchase is pending approval and will unlock automatically when completed.")
        case let .failed(detail):
            message = store.language.text("购买失败，请稍后重试。\n\(detail)", "Purchase failed. Please try again.\n\(detail)")
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        switch await subscription.restorePurchases() {
        case .restored:
            message = store.language.text("订阅已恢复，场景工具已解锁。", "Subscription restored. Practical tools are now unlocked.")
        case .nothingToRestore:
            message = store.language.text("当前 Apple 账户没有可恢复的有效订阅。", "No active subscription was found for this Apple Account.")
        case let .failed(detail):
            message = store.language.text("恢复失败，请稍后重试。\n\(detail)", "Restore failed. Please try again.\n\(detail)")
        }
    }
}

struct PrivacyPolicyView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section {
                Text(store.language.text(
                    "本隐私政策适用于“啵啵几何工坊”iOS 应用（以下简称“本应用”）。本应用运营者为 App Store 产品页面所示的开发者或销售商（以下简称“我们”）。请在使用本应用前阅读本政策，了解相关数据处理方式。",
                    "This Privacy Policy applies to the Bobo Geometry Workshop iOS app (the “App”). The operator is the developer or seller identified on the App Store product page (“we,” “us,” or “our”). Please read this Policy before using the App to understand its data practices."
                ))
                Text(store.language.text("生效日期：2026 年 9 月 6 日", "Effective date: September 6, 2026"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(store.language.text("适用范围与运营者", "Scope and Operator"))
            }

            policySection(
                store.language.text("我们处理的信息", "Information We Process"),
                paragraphs: [
                    store.language.text(
                        "计算输入、计算结果和计算历史：你输入的边长、角度及场景尺寸会在设备上用于完成计算和绘图。保存到历史记录的内容最多保留 20 条，存储于本应用的本地沙盒中。我们不会将这些内容上传到开发者服务器。",
                        "Calculation inputs, results, and history: Measurements and angles you enter are processed on your device to calculate and draw results. Up to 20 saved history records are stored in the App's local sandbox. We do not upload this content to a developer server."
                    ),
                    store.language.text(
                        "应用偏好：语言、字体大小、场景开关和工具顺序等设置保存在设备上，用于维持你的使用偏好。",
                        "App preferences: Language, text size, tool visibility, and tool order are stored on your device to preserve your preferences."
                    ),
                    store.language.text(
                        "订阅权益：本应用使用 Apple StoreKit 获取产品信息并核验当前 Apple 账户是否具有有效订阅权益。我们不接触你的付款卡号、Apple 账户密码或完整付款资料，也不在开发者服务器保存交易记录。",
                        "Subscription entitlement: The App uses Apple StoreKit to load product information and verify whether the current Apple Account has an active entitlement. We do not receive payment card numbers, Apple Account passwords, or complete payment details, and we do not store transaction records on a developer server."
                    )
                ]
            )

            policySection(
                store.language.text("我们不收集的信息", "Information We Do Not Collect"),
                paragraphs: [
                    store.language.text(
                        "当前版本不要求注册账户，不包含开发者运营的后台服务、广告、用户追踪、行为埋点或第三方分析 SDK，也不请求相机、照片、麦克风、通讯录或位置权限。我们不会出售个人信息，也不会将本应用内的数据用于定向广告。",
                        "The current version requires no account and includes no developer-operated backend, advertising, user tracking, behavioral analytics, or third-party analytics SDKs. It does not request access to the camera, photos, microphone, contacts, or location. We do not sell personal information or use App data for targeted advertising."
                    )
                ]
            )

            policySection(
                store.language.text("复制、分享与第三方服务", "Copying, Sharing, and Third Parties"),
                paragraphs: [
                    store.language.text(
                        "只有在你主动点击“复制结果”时，相关计算内容才会写入系统剪贴板。只有在你主动使用分享功能并选择接收应用后，相关计算内容才会交给该应用；接收方如何处理信息受其自身隐私政策约束。",
                        "Calculation content is written to the system clipboard only when you tap Copy Results. It is provided to another app only after you use the share feature and select a destination. The destination's own privacy policy governs its handling of that information."
                    ),
                    store.language.text(
                        "购买、续订、退款、家庭共享、订阅恢复以及 Apple 提供的可选诊断或 App 分析由 Apple 独立处理，并受 Apple 的条款和隐私政策约束。我们不对 Apple 独立收集的数据作控制。",
                        "Purchases, renewals, refunds, Family Sharing, restoration, and any optional diagnostics or App Analytics provided by Apple are processed independently by Apple under Apple's terms and privacy policy. We do not control data Apple collects independently."
                    )
                ],
                link: (store.language.text("查看 Apple 隐私政策", "View Apple's Privacy Policy"), URL(string: "https://www.apple.com/legal/privacy/")!)
            )

            policySection(
                store.language.text("保存与删除", "Retention and Deletion"),
                paragraphs: [
                    store.language.text(
                        "计算历史会保留在设备上，直至你逐条删除、使用“清空历史”或卸载本应用；偏好设置会保留至你修改、恢复默认设置或卸载本应用。未保存的输入通常随页面或应用状态重置而清除。",
                        "Calculation history remains on your device until you delete records, choose Clear History, or uninstall the App. Preferences remain until changed, reset, or the App is uninstalled. Unsaved inputs are generally removed when the relevant view or App state resets."
                    ),
                    store.language.text(
                        "Apple 保存的购买和订阅记录由 Apple 依据其政策管理。你可以在系统“设置”或 App Store 的 Apple 账户订阅页面管理或取消订阅。",
                        "Purchase and subscription records retained by Apple are managed under Apple's policies. You can manage or cancel a subscription in Settings or the Apple Account subscription page in the App Store."
                    )
                ]
            )

            policySection(
                store.language.text("你的选择与权利", "Your Choices and Rights"),
                paragraphs: [
                    store.language.text(
                        "你可以随时不保存计算历史、删除或清空本地历史、更改偏好设置、停止使用或卸载本应用。由于当前版本不在开发者服务器保存账户或计算数据，我们通常没有可供访问、更正或删除的服务器端个人数据。",
                        "You may choose not to save history, delete or clear local history, change preferences, stop using the App, or uninstall it at any time. Because the current version stores no account or calculation data on a developer server, we generally hold no server-side personal data for you to access, correct, or delete."
                    )
                ]
            )

            policySection(
                store.language.text("数据安全与儿童隐私", "Security and Children's Privacy"),
                paragraphs: [
                    store.language.text(
                        "本地信息受 iOS 应用沙盒及设备安全机制保护。任何存储方式都无法保证绝对安全，请妥善保护设备和 Apple 账户。",
                        "Local information is protected by the iOS app sandbox and device security features. No storage method can guarantee absolute security, so please protect your device and Apple Account."
                    ),
                    store.language.text(
                        "本应用是通用计算工具，不以儿童为主要对象，也不会主动收集儿童个人信息。如果未来的数据处理方式发生变化，我们将先更新本政策并遵守适用的儿童隐私要求。",
                        "The App is a general-purpose calculation tool and is not directed primarily to children. We do not knowingly collect children's personal information. If our data practices change, we will update this Policy and comply with applicable children's privacy requirements."
                    )
                ]
            )

            policySection(
                store.language.text("跨境处理与政策更新", "International Processing and Changes"),
                paragraphs: [
                    store.language.text(
                        "我们不运营用于接收本应用数据的服务器，因此不会主动将你的计算数据传输至境外。Apple 或你选择的分享接收方可能在不同国家或地区处理信息，具体以其隐私政策为准。",
                        "We operate no server that receives App data and therefore do not actively transfer your calculation data across borders. Apple or a share destination you choose may process information in other countries or regions under its own privacy policy."
                    ),
                    store.language.text(
                        "如本应用的功能或数据处理方式发生实质变化，我们会更新本政策及生效日期，并通过应用内页面或 App Store 隐私政策网址提供新版内容。",
                        "If the App's features or data practices materially change, we will update this Policy and its effective date and provide the revised version in the App or at the privacy policy URL listed on the App Store."
                    )
                ]
            )

            policySection(
                store.language.text("联系我们", "Contact Us"),
                paragraphs: [
                    store.language.text(
                        "如对本政策或本应用的数据处理方式有疑问，请通过 App Store 产品页面所列的“App 支持”链接联系开发者。",
                        "For questions about this Policy or the App's data practices, contact the developer using the App Support link on the App Store product page."
                    )
                ]
            )
        }
        .navigationTitle(store.language.text("隐私政策", "Privacy Policy"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(_ title: String, paragraphs: [String], link: (String, URL)? = nil) -> some View {
        Section {
            ForEach(paragraphs, id: \.self) { paragraph in
                Text(paragraph)
            }
            if let link {
                Link(link.0, destination: link.1)
            }
        } header: {
            Text(title)
        }
    }
}
