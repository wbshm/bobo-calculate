import SwiftUI
import UIKit

struct TriangleCalculatorView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var model = TriangleCalculatorViewModel()
    @State private var drawingOptions = TriangleDrawingOptions()
    @State private var showSteps = true
    @State private var showDrawingOptions = false
    @State private var shareImage: ShareImage?
    @State private var copied = false
    @FocusState private var focusedField: TriangleField?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                inputCard
                drawingCard
                resultCard
                if !model.steps.isEmpty { stepsCard }
            }
            .padding(16)
        }
        .background(Color.boboBackground)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focusedField = nil }
        .navigationTitle(store.language.text("三角形计算", "Triangle Calculator"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(store.language.text("完成", "Done")) { focusedField = nil }
            }
        }
        .sheet(item: $shareImage) { item in ActivitySheet(items: [item.image]) }
        .overlay(alignment: .top) {
            if copied {
                Text(store.language.text("结果已复制", "Result copied"))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 8, y: 3)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .onAppear { consumePendingRestore() }
        .onChange(of: store.pendingRestore?.id) { _, _ in consumePendingRestore() }
        .onChange(of: store.language) { _, _ in model.refreshLanguage(store: store) }
    }

    private var inputCard: some View {
        BoboCard {
            VStack(spacing: 14) {
                HStack {
                    SectionTitle(title: store.language.text("输入", "Input"), subtitle: store.language.text("边 a 对应角 A，以此类推", "Side a is opposite angle A, and so on"))
                    Button(model.angleUnit.title(language: store.language)) { model.toggleInputUnit(store: store) }
                        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    Button(store.language.text("重置", "Reset")) { model.reset() }.buttonStyle(.bordered).buttonBorderShape(.capsule)
                }
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    ForEach([(TriangleField.a, TriangleField.A), (.b, .B), (.c, .C)], id: \.0) { pair in
                        GridRow {
                            inputField(pair.0)
                            inputField(pair.1)
                        }
                    }
                }
                statusView
                if onlyAngles {
                    Label(store.language.text("仅输入角度时按 c = 1 计算；再输入任意一条边可等比缩放。", "With angles only, c = 1. Enter any side to set the scale."), systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.blue).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func inputField(_ field: TriangleField) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(field.isAngle ? "\(field.rawValue) (\(model.angleUnit.symbol.trimmingCharacters(in: .whitespaces)))" : field.rawValue)
                .font(.caption).foregroundStyle(.secondary)
            TextField(field.isAngle ? store.language.text("角 \(field.rawValue)", "Angle \(field.rawValue)") : store.language.text("边 \(field.rawValue)", "Side \(field.rawValue)"), text: Binding(
                get: { model.fields[field] },
                set: { value in model.updateField(field, value: value, store: store) }
            ))
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: field)
            .textFieldStyle(.plain)
            .font(.body.monospacedDigit())
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(focusedField == field ? Color.boboBlue : .clear, lineWidth: 1.5) }
            .accessibilityLabel(field.isAngle ? store.language.text("角 \(field.rawValue)", "Angle \(field.rawValue)") : store.language.text("边 \(field.rawValue)", "Side \(field.rawValue)"))
        }
    }

    @ViewBuilder private var statusView: some View {
        switch model.state {
        case .idle:
            Label(store.language.text("请输入任意三项", "Enter any three values"), systemImage: "circle.dotted").foregroundStyle(.secondary)
        case let .waiting(message):
            Label(message, systemImage: "ellipsis.circle").foregroundStyle(.secondary)
        case .success:
            Label(store.language.text("已完成计算", "Calculation complete"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case let .failure(message):
            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }

    private var drawingCard: some View {
        BoboCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(title: store.language.text("三角形展示", "Triangle Diagram"), subtitle: store.language.text("图形按实际边长比例绘制", "Drawn to the calculated side proportions"))
                    Button { withAnimation { showDrawingOptions.toggle() } } label: {
                        Label(store.language.text("选项", "Options"), systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule)
                }
                TriangleDiagramView(solution: model.selectedSolution, options: drawingOptions, language: store.language)
                    .frame(height: 280)
                if showDrawingOptions {
                    drawingOptionControls.transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var drawingOptionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.language.text("辅助线", "Guide Lines")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                optionToggle(store.language.text("标签", "Labels"), isOn: $drawingOptions.labels)
                optionToggle(store.language.text("高线", "Altitudes"), isOn: $drawingOptions.heights)
                optionToggle(store.language.text("中线", "Medians"), isOn: $drawingOptions.medians)
                optionToggle(store.language.text("角平分线", "Bisectors"), isOn: $drawingOptions.bisectors)
            }
            Text(store.language.text("几何元素", "Geometry")) .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                optionToggle(store.language.text("外接圆", "Circumcircle"), isOn: $drawingOptions.circumcircle)
                optionToggle(store.language.text("内切圆", "Incircle"), isOn: $drawingOptions.incircle)
                optionToggle(store.language.text("重心", "Centroid"), isOn: $drawingOptions.centroid)
                optionToggle(store.language.text("外心", "Circumcenter"), isOn: $drawingOptions.circumcenter)
                optionToggle(store.language.text("内心", "Incenter"), isOn: $drawingOptions.incenter)
                optionToggle(store.language.text("垂心", "Orthocenter"), isOn: $drawingOptions.orthocenter)
            }
        }
    }

    private func optionToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Button { isOn.wrappedValue.toggle() } label: {
            Text(label).font(.caption.weight(.medium))
                .foregroundStyle(isOn.wrappedValue ? .white : .secondary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(isOn.wrappedValue ? Color.boboBlue : Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var resultCard: some View {
        BoboCard {
            VStack(spacing: 12) {
                HStack {
                    SectionTitle(title: store.language.text("计算结果", "Results"), subtitle: resultSubtitle)
                    Button(model.resultAngleUnit.title(language: store.language)) {
                        model.resultAngleUnit = model.resultAngleUnit == .degrees ? .radians : .degrees
                    }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule)
                }
                if model.solutions.count > 1 {
                    Picker(store.language.text("选择解", "Solution"), selection: Binding(
                        get: { model.selectedSolutionIndex },
                        set: { model.selectSolution($0, language: store.language) }
                    )) {
                        ForEach(model.solutions.indices, id: \.self) { Text(store.language.text("解 \($0 + 1)", "Solution \($0 + 1)")).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                resultsGrid
                HStack(spacing: 10) {
                    Button { exportResult() } label: { Label(store.language.text("导出图片", "Export Image"), systemImage: "square.and.arrow.up") }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.selectedSolution == nil)
                    Button { copyResult() } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.bordered).accessibilityLabel(store.language.text("复制全部结果", "Copy all results"))
                        .disabled(model.selectedSolution == nil)
                    ShareLink(item: model.resultText(language: store.language)) { Image(systemName: "paperplane") }
                        .buttonStyle(.bordered).accessibilityLabel(store.language.text("分享文字结果", "Share text results"))
                        .disabled(model.selectedSolution == nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var resultsGrid: some View {
        let solution = model.selectedSolution
        let angle: (Double?) -> String = { value in
            guard let value else { return "–" }
            let shown = model.resultAngleUnit == .degrees ? value : value * .pi / 180
            return shown.formatted(maxDigits: model.resultAngleUnit == .degrees ? 3 : 4) + model.resultAngleUnit.symbol
        }
        return Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow { MetricCell(label: store.language.text("边 a", "Side a"), value: solution?.a.formatted(maxDigits: 4) ?? "–"); MetricCell(label: "∠A", value: angle(solution?.A)) }
            GridRow { MetricCell(label: store.language.text("边 b", "Side b"), value: solution?.b.formatted(maxDigits: 4) ?? "–"); MetricCell(label: "∠B", value: angle(solution?.B)) }
            GridRow { MetricCell(label: store.language.text("边 c", "Side c"), value: solution?.c.formatted(maxDigits: 4) ?? "–"); MetricCell(label: "∠C", value: angle(solution?.C)) }
            GridRow { MetricCell(label: store.language.text("高 ha", "Altitude ha"), value: solution?.heightA.formatted(maxDigits: 4) ?? "–"); MetricCell(label: store.language.text("面积 S", "Area S"), value: solution?.area.formatted(maxDigits: 4) ?? "–") }
            GridRow { MetricCell(label: store.language.text("高 hb", "Altitude hb"), value: solution?.heightB.formatted(maxDigits: 4) ?? "–"); MetricCell(label: store.language.text("周长 L", "Perimeter L"), value: solution?.perimeter.formatted(maxDigits: 4) ?? "–") }
            GridRow { MetricCell(label: store.language.text("高 hc", "Altitude hc"), value: solution?.heightC.formatted(maxDigits: 4) ?? "–"); MetricCell(label: store.language.text("半周长 s", "Semiperimeter s"), value: solution?.semiPerimeter.formatted(maxDigits: 4) ?? "–") }
            GridRow { MetricCell(label: store.language.text("内切半径 r", "Inradius r"), value: solution?.inradius.formatted(maxDigits: 4) ?? "–"); MetricCell(label: store.language.text("外接半径 R", "Circumradius R"), value: solution?.circumradius.formatted(maxDigits: 4) ?? "–") }
        }
    }

    private var stepsCard: some View {
        BoboCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(title: store.language.text("计算步骤", "Calculation Steps"))
                    Button(showSteps ? store.language.text("隐藏", "Hide") : store.language.text("显示", "Show")) { withAnimation { showSteps.toggle() } }.buttonStyle(.bordered)
                }
                if showSteps {
                    ForEach(Array(model.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.white)
                                .frame(width: 24, height: 24).background(Color.boboBlue, in: Circle())
                            VStack(alignment: .leading, spacing: 5) {
                                Text(step.title).font(.subheadline.weight(.semibold))
                                if let formula = step.formula {
                                    Text(formula).font(.subheadline.monospaced()).foregroundStyle(.blue)
                                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                                }
                                Text(step.detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var onlyAngles: Bool {
        [model.fields.A, model.fields.B, model.fields.C].allSatisfy { !$0.isEmpty }
            && [model.fields.a, model.fields.b, model.fields.c].allSatisfy(\.isEmpty)
    }

    private var resultSubtitle: String? {
        guard let solution = model.selectedSolution else { return store.language.text("等待有效输入", "Waiting for valid input") }
        let kind = TriangleKind.detect(solution).title(language: store.language)
        return model.solutions.count > 1 ? store.language.text("\(kind) · 存在两个解", "\(kind) · Two solutions") : kind
    }

    private func consumePendingRestore() {
        guard let record = store.pendingRestore else { return }
        store.pendingRestore = nil
        model.restore(record, store: store)
    }

    private func copyResult() {
        UIPasteboard.general.string = model.resultText(language: store.language)
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { copied = false }
        }
    }

    @MainActor private func exportResult() {
        guard let solution = model.selectedSolution else { return }
        let renderer = ImageRenderer(content: TriangleExportView(solution: solution, text: model.resultText(language: store.language), language: store.language))
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: 720, height: 920)
        if let image = renderer.uiImage { shareImage = ShareImage(image: image) }
    }
}

private struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct TriangleExportView: View {
    let solution: TriangleSolution
    let text: String
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 14) {
                Image("BoboLogo").resizable().scaledToFit().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading) {
                    Text(language.text("啵啵几何工坊", "Bobo Geometry Workshop")).font(.title2.bold())
                    Text(TriangleKind.detect(solution).title(language: language)).foregroundStyle(.secondary)
                }
            }
            TriangleDiagramView(solution: solution, language: language).frame(height: 430)
            Text(text).font(.title3.monospaced()).lineSpacing(8)
            Spacer()
            Text(language.text("图形按实际边长比例绘制", "Drawn to calculated side proportions")).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(36)
        .frame(width: 720, height: 920)
        .background(Color.white)
        .foregroundStyle(Color.black)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}
