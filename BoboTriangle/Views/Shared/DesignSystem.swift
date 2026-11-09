import SwiftUI
import UIKit

extension Color {
    static let boboBlue = Color(red: 76 / 255, green: 111 / 255, blue: 1)
    static let boboBackground = Color(uiColor: .systemGroupedBackground)
    static let boboCard = Color(uiColor: .secondarySystemGroupedBackground)
}

struct BoboCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(Color.boboCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetricCell: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value)
                .font(.body.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
