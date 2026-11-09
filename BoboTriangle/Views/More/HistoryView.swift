import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        Group {
            if store.history.isEmpty {
                ContentUnavailableView(store.language.text("暂无计算记录", "No History"), systemImage: "clock", description: Text(store.language.text("计算完成后自动保存，最多保留 20 条。", "Completed calculations are saved automatically, up to 20 entries.")))
            } else {
                List {
                    ForEach(store.history) { record in
                        HistoryCard(record: record) {
                            store.restore(record)
                            dismiss()
                        }
                        .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                        .swipeActions {
                            Button(role: .destructive) { store.deleteHistory(id: record.id) } label: { Label(store.language.text("删除", "Delete"), systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(store.language.text("最近记录 · \(store.history.count)/20", "Recent · \(store.history.count)/20"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.history.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { Button(store.language.text("清空", "Clear"), role: .destructive) { confirmClear = true } }
            }
        }
        .confirmationDialog(store.language.text("清空后无法恢复，确定继续吗？", "Cleared history cannot be recovered. Continue?"), isPresented: $confirmClear, titleVisibility: .visible) {
            Button(store.language.text("清空历史记录", "Clear History"), role: .destructive) { store.clearHistory() }
        }
    }
}

private struct HistoryCard: View {
    @EnvironmentObject private var store: AppStore
    let record: TriangleHistoryRecord
    let restore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(record.kind.title(language: store.language)).font(.headline)
                if record.solutionCount > 1 { Text(store.language.text("· \(record.solutionCount) 个解", "· \(record.solutionCount) solutions")).font(.caption).foregroundStyle(.orange) }
                Spacer()
                Text(record.createdAt, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(store.language.text("已知条件 · \(record.angleUnit == .degrees ? "角度输入" : "弧度输入")", "Known values · \(record.angleUnit == .degrees ? "degrees" : "radians")")).font(.caption).foregroundStyle(.secondary)
                Text(record.given.summary(angleUnit: record.angleUnit)).font(.subheadline.monospacedDigit())
            }
            Grid(horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow { compactMetric(store.language.text("边 a", "Side a"), record.solution.a); compactMetric("∠A", record.solution.A, suffix: "°") }
                GridRow { compactMetric(store.language.text("边 b", "Side b"), record.solution.b); compactMetric("∠B", record.solution.B, suffix: "°") }
                GridRow { compactMetric(store.language.text("边 c", "Side c"), record.solution.c); compactMetric("∠C", record.solution.C, suffix: "°") }
                GridRow { compactMetric(store.language.text("面积", "Area"), record.solution.area); compactMetric(store.language.text("周长", "Perimeter"), record.solution.perimeter) }
            }
            Button(action: restore) { Label(store.language.text("继续计算", "Continue"), systemImage: "arrow.uturn.forward").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered)
        }
        .padding(14)
        .background(Color.boboCard, in: RoundedRectangle(cornerRadius: 15))
    }

    private func compactMetric(_ label: String, _ value: Double, suffix: String = "") -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value.formatted(maxDigits: 4) + suffix).monospacedDigit().fontWeight(.medium) }
            .font(.caption).padding(.vertical, 3)
    }
}
