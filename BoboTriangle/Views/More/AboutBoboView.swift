import SwiftUI
import UIKit

struct AboutBoboView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPetting = false
    @State private var reaction: String?
    @State private var reactionIndex = 0
    @State private var animationSequence = 0
    @State private var photoRotation = 0.0
    @State private var photoScale = 1.0
    @State private var animationTask: Task<Void, Never>?

    private var reactions: [String] {
        store.language == .simplifiedChinese
            ? ["呼噜呼噜～", "嗯，这个手法可以。", "下巴也要，谢谢喵。", "再摸一下？就一下。", "好啦，你已经是我的人了。"]
            : ["Purr, purr…", "Yes, that's the spot.", "Under the chin too, please.", "One more pet? Just one.", "All right, you're mine now."]
    }

    var body: some View {
        GeometryReader { geometry in
            let photoHeight = min(280, max(170, geometry.size.height - 330))

            ScrollView {
                aboutCard(photoHeight: photoHeight)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.boboBackground)
        .navigationTitle(store.language.text("关于啵啵", "About Bobo"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.language) { _, _ in
            reaction = nil
            reactionIndex = 0
        }
        .onDisappear { stopPetting() }
    }

    private func aboutCard(photoHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Color(red: 234 / 255, green: 228 / 255, blue: 213 / 255)

                Image("BoboPhoto")
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(photoScale, anchor: .init(x: 0.5, y: 0.75))
                    .rotationEffect(.degrees(photoRotation), anchor: .init(x: 0.5, y: 0.75))
                    .accessibilityLabel(store.language.text("啵啵，一只戴着白手套的虎斑猫", "Bobo, a tabby cat with white paws"))

                if isPetting {
                    GeometryReader { proxy in
                        RisingHeart(size: 28, delay: .zero)
                            .position(x: proxy.size.width * 0.24, y: proxy.size.height * 0.58)
                        RisingHeart(size: 22, delay: .milliseconds(70))
                            .position(x: proxy.size.width * 0.68, y: proxy.size.height * 0.46)
                        RisingHeart(size: 18, delay: .milliseconds(30))
                            .position(x: proxy.size.width * 0.51, y: proxy.size.height * 0.28)
                    }
                    .id(animationSequence)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .frame(height: photoHeight)
            .clipped()

            VStack(alignment: .leading, spacing: 7) {
                Text(store.language.text("我是啵啵，喵。", "I'm Bobo. Meow."))
                    .font(.title3.bold())

                Text(store.language.text("一只穿虎斑外套、戴白手套的猫。", "A tabby cat wearing white gloves."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(store.language.text("三角形有几条边，我可以慢慢学。猫条还剩几根，我可是门儿清。", "I can take my time learning triangles. But I always know how many treats are left."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.language.text("猫条补给计划", "Treat Supply Plan"))
                        .font(.subheadline.weight(.semibold))
                    Text(store.language.text("这个应用的收入，会用来给我买猫条。每一根，都由本喵亲自验收。", "Revenue from this app helps buy my cat treats. Every one is personally inspected."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.boboBlue.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 5)

                Text(reaction ?? store.language.text("毛茸茸，等你来 rua。", "Fluffy and waiting for a pet."))
                    .font(.caption)
                    .foregroundStyle(isPetting ? Color.boboBlue : .secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: reaction)
                    .padding(.top, 3)

                Button(action: petBobo) {
                    Label(store.language.text("rua 一下", "Pet Bobo"), systemImage: isPetting ? "heart.fill" : "heart")
                        .frame(maxWidth: .infinity)
                        .symbolEffect(.bounce, value: animationSequence)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(14)
        }
        .background(Color.boboCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 10, y: 3)
    }

    private func petBobo() {
        guard !isPetting else { return }

        reaction = reactions[reactionIndex % reactions.count]
        reactionIndex += 1
        animationSequence += 1
        isPetting = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        animationTask?.cancel()
        animationTask = Task { @MainActor in
            do {
                if reduceMotion {
                    withAnimation(.easeOut(duration: 0.18)) { photoScale = 1.02 }
                    try await Task.sleep(for: .milliseconds(620))
                    withAnimation(.easeIn(duration: 0.18)) { photoScale = 1 }
                    try await Task.sleep(for: .milliseconds(200))
                } else {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        photoRotation = -2
                        photoScale = 1.035
                    }
                    try await Task.sleep(for: .milliseconds(160))
                    withAnimation(.easeInOut(duration: 0.25)) { photoRotation = 2 }
                    try await Task.sleep(for: .milliseconds(250))
                    withAnimation(.easeInOut(duration: 0.24)) {
                        photoRotation = 0
                        photoScale = 1
                    }
                    try await Task.sleep(for: .milliseconds(440))
                }
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.15)) { isPetting = false }
            } catch {
                return
            }
        }
    }

    private func stopPetting() {
        animationTask?.cancel()
        animationTask = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isPetting = false
            photoRotation = 0
            photoScale = 1
        }
    }
}

private struct RisingHeart: View {
    let size: CGFloat
    let delay: Duration

    @State private var opacity = 0.0
    @State private var verticalOffset = 12.0
    @State private var scale = 0.6

    var body: some View {
        Text("♥")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Color(red: 229 / 255, green: 139 / 255, blue: 158 / 255))
            .shadow(color: .white.opacity(0.7), radius: 4, y: 2)
            .opacity(opacity)
            .offset(y: verticalOffset)
            .scaleEffect(scale)
            .task {
                do {
                    try await Task.sleep(for: delay)
                    withAnimation(.easeOut(duration: 0.17)) {
                        opacity = 1
                        verticalOffset = 0
                        scale = 1
                    }
                    try await Task.sleep(for: .milliseconds(170))
                    withAnimation(.easeOut(duration: 0.55)) {
                        opacity = 0
                        verticalOffset = -60
                        scale = 1.2
                    }
                } catch {
                    return
                }
            }
    }
}
