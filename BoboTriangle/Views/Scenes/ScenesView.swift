import SwiftUI
import UIKit

struct SceneConfig {
    let title: String
    let description: String
    let firstLabel: String
    let secondLabel: String
    let secondUnit: String
    let secondIsLength: Bool
    let example: (first: String, second: String, risers: String?)
    let formula: String
    let notes: [String]

    func exampleInputs(unit: LengthUnit) -> (first: String, second: String, risers: String) {
        let convert: (String) -> String = { raw in
            guard let value = NumericInput.double(raw) else { return raw }
            return LengthUnit.mm.convert(value, to: unit).formatted(maxDigits: 8)
        }
        return (convert(example.first), secondIsLength ? convert(example.second) : example.second, example.risers ?? "")
    }
}

private struct SceneMetric: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let value: String
    let unit: String
}

struct ScenesView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var selectedScene: SceneID = .stairs
    @State private var slopeMode: SceneMode = .drop
    @State private var unit: LengthUnit = .mm
    @State private var first = ""
    @State private var second = ""
    @State private var risers = ""
    @State private var metrics: [SceneMetric] = []
    @State private var resultHint = ""
    @State private var error = ""
    @State private var copied = false
    @State private var resultLayout: ResultLayout = .oneColumn
    @FocusState private var focused: InputField?

    private enum InputField: Hashable { case first, second, risers }
    private enum ResultLayout: String, CaseIterable, Identifiable {
        case twoColumns, oneColumn
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            switch subscription.entitlementStatus {
            case .checking:
                ProgressView(store.language.text("正在确认订阅状态…", "Checking subscription…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .notSubscribed, .subscribed:
                calculatorContent
            }
        }
        .navigationTitle(store.language.text("常用场景", "Practical Tools"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var calculatorContent: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if enabledScenes.isEmpty {
                    emptyView
                } else {
                    if isLocked { lockedNotice }
                    sceneTabs
                    calculatorCard
                    if !metrics.isEmpty { resultCard }
                    explanationCard
                }
            }
            .padding(16)
        }
        .background(Color.boboBackground)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focused = nil }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer(); Button(store.language.text("完成", "Done")) { focused = nil }
            }
        }
        .overlay(alignment: .top) {
            if copied {
                Text(store.language.text("结果已复制", "Result copied")).font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule()).shadow(radius: 8, y: 3).padding(.top, 8)
            }
        }
        .onAppear { ensureValidScene() }
        .onChange(of: store.sceneTools) { _, _ in ensureValidScene() }
        .onChange(of: slopeMode) { _, _ in resetInputs() }
        .onChange(of: unit) { old, new in convertInputs(from: old, to: new) }
        .onChange(of: store.language) { _, _ in calculate() }
    }

    private var isLocked: Bool {
        subscription.entitlementStatus == .notSubscribed
    }

    private var enabledScenes: [SceneID] { store.enabledSceneTools.map(\.id) }
    private var mode: SceneMode {
        switch selectedScene {
        case .brace: .brace
        case .slope: slopeMode
        case .pipe: .pipe
        case .stairs: .stairs
        case .wood: .wood
        }
    }
    private var config: SceneConfig { Self.config(for: mode, language: store.language) }

    private var emptyView: some View {
        BoboCard {
            ContentUnavailableView {
                Label(store.language.text("还没有开启工具", "No Tools Enabled"), systemImage: "wrench.and.screwdriver")
            } description: {
                Text(store.language.text("到场景设置中开启至少一个工具。", "Enable at least one tool in Tool Settings."))
            } actions: {
                NavigationLink(store.language.text("去设置", "Open Settings")) { SceneSettingsView() }.buttonStyle(.borderedProminent)
            }
        }
    }

    private var lockedNotice: some View {
        BoboCard {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.headline)
                    .foregroundStyle(Color.boboBlue)
                    .frame(width: 38, height: 38)
                    .background(Color.boboBlue.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.language.text("当前为示例模式", "Example Mode"))
                        .font(.subheadline.weight(.semibold))
                    Text(store.language.text("可切换工具并查看示例；解锁后可以输入自己的数据。", "Switch tools and view examples. Unlock to enter your own measurements."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Button(store.language.text("解锁", "Unlock")) {
                    store.openSubscription()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private var sceneTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(enabledScenes) { scene in
                    Button {
                        guard selectedScene != scene else { return }
                        selectedScene = scene
                        if scene == .slope { slopeMode = .drop }
                        resetInputs()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: scene.symbol).font(.title3)
                            Text(scene.title(language: store.language)).font(.caption.weight(.medium)).lineLimit(1)
                        }
                        .foregroundStyle(selectedScene == scene ? .white : .primary)
                        .padding(.horizontal, 14).frame(height: 66)
                        .background(selectedScene == scene ? Color.boboBlue : Color.boboCard, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedScene == scene ? .isSelected : [])
                }
            }
        }
    }

    private var calculatorCard: some View {
        BoboCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    SectionTitle(title: config.title, subtitle: config.description)
                    Picker(store.language.text("长度单位", "Length Unit"), selection: $unit) {
                        ForEach(LengthUnit.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .buttonStyle(.bordered)
                    .disabled(isLocked)
                }
                if selectedScene == .slope {
                    Picker(store.language.text("计算模式", "Mode"), selection: $slopeMode) {
                        Text(store.language.text("求高差", "Find Rise")).tag(SceneMode.drop)
                        Text(store.language.text("求坡度", "Find Slope")).tag(SceneMode.slope)
                        Text(store.language.text("角度换算", "From Angle")).tag(SceneMode.angle)
                    }
                    .pickerStyle(.segmented)
                    .disabled(isLocked)
                }
                SceneDiagram(mode: mode, first: NumericInput.double(first), second: NumericInput.double(second), risers: NumericInput.integer(risers), unit: unit, language: store.language)
                    .aspectRatio(4 / 3, contentMode: .fit)
                HStack(alignment: .top, spacing: 12) {
                    sceneInput(title: config.firstLabel, text: inputBinding(.first), suffix: unit.rawValue, field: .first)
                    sceneInput(title: config.secondLabel, text: inputBinding(.second), suffix: config.secondIsLength ? unit.rawValue : config.secondUnit, field: .second)
                }
                if selectedScene == .stairs {
                    sceneInput(title: store.language.text("上升级数（立板数）", "Riser Count"), text: inputBinding(.risers), suffix: store.language.text("级", ""), field: .risers)
                    Text(store.language.text("顶层楼面作为最后落脚面，踏面数 = 上升级数 − 1。", "The top floor is the final landing, so tread count = riser count − 1."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if selectedScene == .wood {
                    Text(store.language.text("水平端 / 竖直端指接触面方向；锯角按直角横切为 0°。", "Horizontal/vertical ends refer to contact surfaces; a square crosscut is 0°."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !error.isEmpty {
                    Label(error, systemImage: "exclamationmark.triangle.fill").font(.subheadline).foregroundStyle(.red)
                }
                HStack {
                    if !first.isEmpty || !second.isEmpty {
                        Label(metrics.isEmpty ? store.language.text("等待完整输入", "Waiting for complete input") : store.language.text("已完成计算", "Calculation complete"), systemImage: metrics.isEmpty ? "ellipsis.circle" : "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(metrics.isEmpty ? Color.secondary : Color.green)
                    }
                    Spacer()
                    Button(store.language.text("示例", "Example")) { focused = nil; fillExample() }.buttonStyle(.bordered)
                    Button(store.language.text("重置", "Reset")) { focused = nil; resetInputs() }
                        .buttonStyle(.bordered)
                        .disabled(isLocked)
                }
            }
        }
    }

    private func inputBinding(_ field: InputField) -> Binding<String> {
        Binding {
            switch field {
            case .first: first
            case .second: second
            case .risers: risers
            }
        } set: { value in
            var nextFirst = first
            var nextSecond = second
            var nextRisers = risers
            switch field {
            case .first: nextFirst = value; first = value
            case .second: nextSecond = value; second = value
            case .risers: nextRisers = value; risers = value
            }
            calculate(first: nextFirst, second: nextSecond, risers: nextRisers)
        }
    }

    private func sceneInput(title: String, text: Binding<String>, suffix: String, field: InputField) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 5) {
                TextField(
                    field == .risers
                        ? store.language.text("整数 ≥ 2", "Integer ≥ 2")
                        : store.language.text("请输入", "Enter value"),
                    text: text
                )
                    .keyboardType(field == .risers ? .numberPad : .decimalPad)
                    .focused($focused, equals: field)
                    .font(.body.monospacedDigit())
                    .disabled(isLocked)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                Text(suffix).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).frame(minHeight: 46)
            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(focused == field ? Color.boboBlue : .clear, lineWidth: 1.5) }
        }
    }

    private var resultCard: some View {
        BoboCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(title: store.language.text("计算结果", "Results"))
                    Menu {
                        Picker(store.language.text("结果布局", "Result Layout"), selection: $resultLayout) {
                            Label(store.language.text("双列", "Two Columns"), systemImage: "square.grid.2x2").tag(ResultLayout.twoColumns)
                            Label(store.language.text("单列", "One Column"), systemImage: "list.bullet").tag(ResultLayout.oneColumn)
                        }
                    } label: {
                        Image(systemName: usesOneColumn ? "list.bullet" : "square.grid.2x2")
                    }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule)
                    .disabled(isLocked)
                }
                if usesOneColumn { oneColumnMetrics } else { twoColumnMetrics }
                Text(resultHint).font(.caption).foregroundStyle(.secondary)
                Button { copyResult() } label: { Label(store.language.text("复制结果", "Copy Results"), systemImage: "doc.on.doc") }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLocked)
            }
        }
    }

    private var usesOneColumn: Bool {
        resultLayout == .oneColumn
    }

    private var oneColumnMetrics: some View {
        VStack(spacing: 8) {
            ForEach(metrics) { metricCell($0) }
        }
    }

    private var twoColumnMetrics: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(stride(from: 0, to: metrics.count, by: 2)), id: \.self) { index in
                GridRow {
                    metricCell(metrics[index])
                    if metrics.indices.contains(index + 1) { metricCell(metrics[index + 1]) } else { Color.clear }
                }
            }
        }
    }

    private func metricCell(_ metric: SceneMetric) -> some View {
        MetricCell(label: metric.label, value: "\(metric.value) \(metric.unit)")
    }

    private var explanationCard: some View {
        BoboCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: store.language.text("计算说明", "How It Works"))
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.language.text("计算公式", "Formula")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(config.formula).font(.subheadline.monospaced()).foregroundStyle(.blue)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                }
                Text(store.language.text("使用说明", "Notes")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(config.notes, id: \.self) { note in
                    Label { Text(note).font(.subheadline) } icon: { Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(Color.boboBlue) }
                }
            }
        }
    }

    private func calculate(first firstInput: String? = nil, second secondInput: String? = nil, risers risersInput: String? = nil) {
        error = ""; metrics = []; resultHint = ""
        let firstRaw = firstInput ?? first
        let secondRaw = secondInput ?? second
        let risersRaw = risersInput ?? risers
        let firstHasValue = !firstRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let secondHasValue = !secondRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard firstHasValue, secondHasValue else { return }
        guard let firstValue = NumericInput.double(firstRaw), let secondValue = NumericInput.double(secondRaw) else {
            error = SceneCalculationError.invalidNumber.message(language: store.language)
            return
        }
        if selectedScene == .stairs, risersRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        do {
            let base = try SceneCalculator.calculate(mode: mode, first: firstValue, second: secondValue)
            let metric: (String, Double, String) -> SceneMetric = { SceneMetric(label: $0, value: $1.formatted(maxDigits: 4), unit: $2) }
            switch selectedScene {
            case .brace:
                metrics = [metric(store.language.text("斜撑几何长度", "Brace length"), base.length, unit.rawValue), metric(store.language.text("与水平夹角", "Horizontal angle"), base.angle, "°"), metric(store.language.text("与竖直夹角", "Vertical angle"), 90 - base.angle, "°"), metric(store.language.text("坡度", "Slope"), base.slope, "%")]
                resultHint = store.language.text("连接点间长度，未扣接头和切口余量。", "Measured between connection points; joint and cut allowances are not deducted.")
            case .slope:
                metrics = [metric(store.language.text("两端高差", "Rise"), base.rise, unit.rawValue), metric(store.language.text("坡度", "Slope"), base.slope, "%"), metric(store.language.text("与水平夹角", "Horizontal angle"), base.angle, "°"), metric(store.language.text("斜面长度", "Sloped length"), base.length, unit.rawValue)]
                resultHint = store.language.text("每水平 1 米，高差 \((base.slope * 10).formatted(maxDigits: 4)) 毫米。", "Rise per horizontal meter: \((base.slope * 10).formatted(maxDigits: 4)) mm.")
            case .pipe:
                metrics = [metric(store.language.text("中心线斜距", "Centerline travel"), base.length, unit.rawValue), metric(store.language.text("水平推进距离", "Horizontal advance"), base.run, unit.rawValue), metric(store.language.text("偏移高度", "Offset height"), base.rise, unit.rawValue), metric(store.language.text("弯头角度", "Elbow angle"), base.angle, "°")]
                resultHint = store.language.text("中心线尺寸，不可直接用于切管。", "Centerline dimensions cannot be used directly as cut length.")
            case .stairs:
                guard let count = NumericInput.integer(risersRaw) else { throw SceneCalculationError.invalidRisers }
                let result = try SceneCalculator.stairs(run: firstValue, rise: secondValue, risers: count)
                metrics = [metric(store.language.text("单级高度", "Riser height"), result.riserHeight, unit.rawValue), metric(store.language.text("踏面进深", "Tread depth"), result.treadDepth, unit.rawValue), metric(store.language.text("踏面数量", "Tread count"), Double(result.treads), store.language.text("个", "")), metric(store.language.text("踏步坡线角", "Stair pitch"), result.pitchAngle, "°"), metric(store.language.text("上下端点连线长", "Endpoint distance"), result.base.length, unit.rawValue), metric(store.language.text("上下端点连线角", "Endpoint angle"), result.base.angle, "°")]
                resultHint = store.language.text("\(count) 级，\(result.treads) 个踏面（不含顶层楼面）。连线长不能用于下料。", "\(count) risers and \(result.treads) treads (top floor excluded). Do not use endpoint distance as a cut length.")
            case .wood:
                let result = try SceneCalculator.wood(run: firstValue, rise: secondValue)
                metrics = [metric(store.language.text("斜料参考长度", "Stock length"), result.base.length, unit.rawValue), metric(store.language.text("安装倾角", "Installation angle"), result.base.angle, "°"), metric(store.language.text("水平端切线角", "Horizontal-end cut angle"), result.horizontalCut, "°"), metric(store.language.text("竖直端切线角", "Vertical-end cut angle"), result.verticalCut, "°"), metric(store.language.text("水平端参考锯角", "Horizontal-end saw setting"), result.horizontalSaw, "°"), metric(store.language.text("竖直端参考锯角", "Vertical-end saw setting"), result.verticalSaw, "°")]
                resultHint = store.language.text("锯角以直角横切为 0°，不是切线角。使用前核对设备行程和摆料方向。", "The saw setting uses a square crosscut as 0° and is not the cut-line angle. Verify tool travel and stock orientation before cutting.")
            }
        } catch {
            self.error = (error as? SceneCalculationError)?.message(language: store.language) ?? error.localizedDescription
        }
    }

    private func fillExample() {
        let (nextFirst, nextSecond, nextRisers) = config.exampleInputs(unit: unit)
        first = nextFirst
        second = nextSecond
        risers = nextRisers
        calculate(first: nextFirst, second: nextSecond, risers: nextRisers)
    }

    private func resetInputs() {
        first = ""; second = ""; risers = ""; metrics = []; error = ""; resultHint = ""
    }

    private func convertInputs(from old: LengthUnit, to new: LengthUnit) {
        var nextFirst = first
        var nextSecond = second
        if let value = NumericInput.double(first) { nextFirst = old.convert(value, to: new).formatted(maxDigits: 10) }
        if config.secondIsLength, let value = NumericInput.double(second) { nextSecond = old.convert(value, to: new).formatted(maxDigits: 10) }
        first = nextFirst
        second = nextSecond
        calculate(first: nextFirst, second: nextSecond)
    }

    private func ensureValidScene() {
        if !enabledScenes.contains(selectedScene), let first = enabledScenes.first {
            selectedScene = first
            resetInputs()
        }
    }

    private func copyResult() {
        guard !metrics.isEmpty else { return }
        let known = "\(config.firstLabel): \(first) \(unit.rawValue)\n\(config.secondLabel): \(second) \(config.secondIsLength ? unit.rawValue : config.secondUnit)"
            + (selectedScene == .stairs ? "\n\(store.language.text("上升级数（立板数）", "Riser count")): \(risers)" : "")
        let rows = metrics.map { "\($0.label): \($0.value) \($0.unit)" }.joined(separator: "\n")
        UIPasteboard.general.string = "\(config.title)\n\(known)\n\(rows)\n\(store.language.text("说明", "Notes")): \(config.notes.joined(separator: " "))"
        withAnimation { copied = true }
        Task { try? await Task.sleep(for: .seconds(1.4)); withAnimation { copied = false } }
    }

    static func config(for mode: SceneMode, language: AppLanguage) -> SceneConfig {
        let t = language.text
        switch mode {
        case .brace:
            return SceneConfig(title: t("斜撑长度", "Brace Length"), description: t("按水平距离和高度计算", "From horizontal distance and height"), firstLabel: t("水平距离", "Horizontal distance"), secondLabel: t("垂直高度", "Vertical height"), secondUnit: "", secondIsLength: true, example: ("1200", "800", nil), formula: t("斜长 = √(水平距离² + 垂直高度²)", "Length = √(distance² + height²)"), notes: [t("长度按两端连接点计算，未扣接头、切口和焊缝间隙。", "Length is measured between connection points; joint, cut, and weld allowances are not deducted."), t("安装角不是锯机设定角。", "The installation angle is not the saw setting.")])
        case .drop:
            return SceneConfig(title: t("坡度 / 高差", "Slope / Rise"), description: t("水平距离 + 坡度 → 高差", "Distance + slope → rise"), firstLabel: t("水平距离", "Horizontal distance"), secondLabel: t("坡度", "Slope"), secondUnit: "%", secondIsLength: false, example: ("8000", "2", nil), formula: t("高差 = 水平距离 × 坡度 ÷ 100", "Rise = distance × slope ÷ 100"), notes: [t("长度填水平距离，不是斜面长度。", "Enter horizontal distance, not sloped length."), t("2% 表示每水平 1 米高差 20 毫米。施工坡度请按设计要求填写。", "A 2% slope rises 20 mm per horizontal meter. Follow the project specification.")])
        case .slope:
            return SceneConfig(title: t("坡度 / 高差", "Slope / Rise"), description: t("水平距离 + 高差 → 坡度", "Distance + rise → slope"), firstLabel: t("水平距离", "Horizontal distance"), secondLabel: t("两端高差", "Rise"), secondUnit: "", secondIsLength: true, example: ("10000", "150", nil), formula: t("坡度(%) = 高差 ÷ 水平距离 × 100", "Slope (%) = rise ÷ distance × 100"), notes: [t("高差可填 0，不填负数，不区分上坡、下坡。", "Rise may be zero but not negative; direction is not represented."), t("长度填水平距离，不是管道或斜面的实际长度。", "Enter horizontal distance, not actual pipe or slope length.")])
        case .angle:
            return SceneConfig(title: t("坡度 / 高差", "Slope / Rise"), description: t("水平距离 + 夹角 → 坡度、高差", "Distance + angle → slope and rise"), firstLabel: t("水平距离", "Horizontal distance"), secondLabel: t("与水平夹角", "Horizontal angle"), secondUnit: "°", secondIsLength: false, example: ("1000", "15", nil), formula: t("坡度(%) = tan(夹角) × 100", "Slope (%) = tan(angle) × 100"), notes: [t("夹角填度数，不是坡度百分比。45° 对应 100% 坡度。", "Enter the angle in degrees, not percent. 45° equals a 100% slope.")])
        case .pipe:
            return SceneConfig(title: t("管道偏移", "Pipe Offset"), description: t("同平面、同角度双弯头偏移", "Coplanar equal-angle two-elbow offset"), firstLabel: t("偏移高度", "Offset height"), secondLabel: t("弯头角度", "Elbow angle"), secondUnit: "°", secondIsLength: false, example: ("300", "45", nil), formula: t("中心线斜距 = 偏移高度 ÷ sin(弯头角度)", "Centerline travel = offset ÷ sin(elbow angle)"), notes: [t("中心线斜距不是切管长度。", "Centerline travel is not the cut length."), t("下料时须按管件尺寸扣除两端弯头中心至端面距离，并计入承插、螺纹或焊缝余量。", "Deduct both elbow center-to-end dimensions and include socket, thread, or weld allowances before cutting."), t("不适用于滚动偏移。", "Not suitable for rolling offsets.")])
        case .stairs:
            return SceneConfig(title: t("楼梯计算", "Stair Calculator"), description: t("单跑直梯，等高、等深踏步", "Straight flight with equal risers and treads"), firstLabel: t("总水平距离", "Total run"), secondLabel: t("总层高", "Total rise"), secondUnit: "", secondIsLength: true, example: ("840", "700", "4"), formula: t("单级高 = 总层高 ÷ N；踏面进深 = 总水平距离 ÷ (N − 1)", "Riser height = total rise ÷ N; tread depth = total run ÷ (N − 1)"), notes: [t("顶层楼面作为最后落脚面：N 级对应 N−1 个踏面。", "The top floor is the last landing: N risers correspond to N−1 treads."), t("总水平距离从首级立板量到顶层边缘；进深不含踏鼻挑出量。", "Measure total run from the first riser to the top-floor edge; tread depth excludes nosing projection."), t("踏步坡线角按单级高和进深计算，与端点连线角不同。连线长不能作为梯梁下料长。", "Stair pitch uses riser height and tread depth and differs from the endpoint angle. Endpoint distance is not a stringer cut length."), t("未计平台、转角和饰面厚度，不做结构设计或规范校验。", "Landings, turns, and finish thickness are excluded; no structural or code compliance check is provided.")])
        case .wood:
            return SceneConfig(title: t("木工斜切", "Wood Miter"), description: t("两端分别贴水平面、竖直面的斜料", "Sloped stock between horizontal and vertical faces"), firstLabel: t("水平宽度", "Horizontal width"), secondLabel: t("垂直高度", "Vertical height"), secondUnit: "", secondIsLength: true, example: ("1200", "800", nil), formula: t("倾角 θ = arctan(高 ÷ 宽)；参考锯角 = 90° − 切线与料长夹角", "Tilt θ = arctan(height ÷ width); saw setting = 90° − cut-line angle"), notes: [t("尺寸量两个接触参考点，未计料宽、长短尖、锯缝和榫接余量。", "Measure between the two contact reference points; stock width, long/short points, kerf, and joinery allowances are excluded."), t("水平端、竖直端按接触面命名；切线角是切线与料长方向的锐角。", "Horizontal and vertical ends are named for their contact surfaces; the cut-line angle is the acute angle between the cut and stock directions."), t("锯角以直角横切为 0°，不含左、右转向。使用前核对设备刻度、摆料方向和可调范围，超出行程不可直接使用。", "Saw settings use a square crosscut as 0° and exclude left/right direction. Verify the scale, stock orientation, and travel range before use."), t("只适用于平面斜切，不适用于复合斜切或两料拼角。", "For planar cuts only; not for compound miters or two-piece joints.")])
        }
    }
}

enum SceneDiagramGeometry {
    static func result(mode: SceneMode, first: Double?, second: Double?) -> SceneResult? {
        guard let first, let second else { return nil }
        return try? SceneCalculator.calculate(mode: mode, first: first, second: second)
    }

    static func endpoints(size: CGSize, run: Double?, rise: Double?) -> (left: CGPoint, right: CGPoint, top: CGPoint) {
        let horizontal = run.flatMap { $0 > 0 ? $0 : nil } ?? 1_200
        let vertical = rise.flatMap { $0 >= 0 ? $0 : nil } ?? 800
        // Keep the same 320 x 240 logical drawing area and margins as the mini program.
        let availableWidth = size.width * 0.60
        let availableHeight = size.height * 0.475
        let horizontalScale = availableWidth / CGFloat(horizontal)
        let verticalScale = vertical > 0 ? availableHeight / CGFloat(vertical) : .greatestFiniteMagnitude
        let scale = min(horizontalScale, verticalScale)
        let drawnWidth = CGFloat(horizontal) * scale
        let drawnHeight = CGFloat(vertical) * scale
        let leftX = (size.width - drawnWidth) / 2
        let bottomY = (size.height + drawnHeight) / 2
        let left = CGPoint(x: leftX, y: bottomY)
        let right = CGPoint(x: leftX + drawnWidth, y: bottomY)
        let top = CGPoint(x: right.x, y: bottomY - drawnHeight)
        return (left, right, top)
    }

    static func points(risers: Int?, left: CGPoint, right: CGPoint, top: CGPoint) -> [CGPoint] {
        let count = max(2, risers ?? 4)
        let stepWidth = (right.x - left.x) / CGFloat(count - 1)
        let stepHeight = (left.y - top.y) / CGFloat(count)
        guard count <= 100, stepWidth >= 1, stepHeight >= 1 else { return [] }
        var points = [left]
        for index in 1...count {
            let currentX = left.x + (right.x - left.x) * CGFloat(index - 1) / CGFloat(count - 1)
            let y = left.y - (left.y - top.y) * CGFloat(index) / CGFloat(count)
            points.append(CGPoint(x: currentX, y: y))
            if index < count {
                let nextX = left.x + (right.x - left.x) * CGFloat(index) / CGFloat(count - 1)
                points.append(CGPoint(x: nextX, y: y))
            }
        }
        return points
    }

    static func placeholderResult(mode: SceneMode) -> SceneResult {
        let second: Double
        switch mode {
        case .pipe: second = 45
        case .drop: second = 25
        case .angle: second = 20
        default: second = 800
        }
        return (try? SceneCalculator.calculate(mode: mode, first: 1_200, second: second))
            ?? SceneResult(run: 1_200, rise: 800, length: hypot(1_200, 800), angle: atan2(800, 1_200) * 180 / .pi, slope: 800 / 1_200 * 100)
    }
}

private struct SceneDiagram: View {
    let mode: SceneMode
    let first: Double?
    let second: Double?
    let risers: Int?
    let unit: LengthUnit
    let language: AppLanguage

    var body: some View {
        GeometryReader { proxy in
            let calculated = SceneDiagramGeometry.result(mode: mode, first: first, second: second)
            let displayed = calculated ?? SceneDiagramGeometry.placeholderResult(mode: mode)
            let endpoints = SceneDiagramGeometry.endpoints(size: proxy.size, run: displayed.run, rise: displayed.rise)
            let (left, right, top) = endpoints
            let angle = displayed.angle * .pi / 180
            let lineLabelPosition = CGPoint(
                x: (left.x + right.x) / 2 - CGFloat(sin(angle)) * 20,
                y: (top.y + right.y) / 2 - CGFloat(cos(angle)) * 20
            )
            let displayRisers = calculated == nil ? 4 : risers
            let stairPoints = mode == .stairs
                ? SceneDiagramGeometry.points(risers: displayRisers, left: left, right: right, top: top)
                : []

            ZStack {
                ZStack {
                    Canvas { context, _ in
                        var guides = Path()
                        guides.move(to: left)
                        guides.addLine(to: right)
                        guides.addLine(to: top)
                        context.stroke(
                            guides,
                            with: .color(.secondary.opacity(0.32)),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                        )

                        var diagonal = Path()
                        diagonal.move(to: left)
                        diagonal.addLine(to: top)
                        context.stroke(
                            diagonal,
                            with: .color(mode == .stairs ? .secondary.opacity(0.35) : .boboBlue),
                            style: StrokeStyle(lineWidth: mode == .stairs ? 1 : 2.25, lineCap: .round)
                        )

                        if !stairPoints.isEmpty {
                            var stairs = Path()
                            stairs.move(to: stairPoints[0])
                            stairPoints.dropFirst().forEach { stairs.addLine(to: $0) }
                            context.stroke(
                                stairs,
                                with: .color(.boboBlue),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }

                    SceneDiagramLabel(
                        title: language.text("水平", "Run"),
                        value: labelValue(calculated?.run, unit: unit.rawValue),
                        isAngle: false
                    )
                    .position(x: (left.x + right.x) / 2, y: left.y + 20)

                    SceneDiagramLabel(
                        title: verticalTitle,
                        value: labelValue(calculated?.rise, unit: unit.rawValue),
                        isAngle: false
                    )
                    .rotationEffect(.degrees(-90))
                    .position(x: right.x + 22, y: (top.y + right.y) / 2)

                    SceneDiagramLabel(
                        title: lengthTitle,
                        value: labelValue(calculated?.length, unit: unit.rawValue),
                        isAngle: false
                    )
                    .rotationEffect(.degrees(-displayed.angle))
                    .position(lineLabelPosition)

                    SceneDiagramLabel(
                        title: angleTitle,
                        value: calculated.map { "\($0.angle.formatted(maxDigits: 4))°" },
                        isAngle: true
                    )
                    .position(x: max(28, left.x - 28), y: left.y)
                }
                .opacity(calculated == nil ? 0.6 : 1)

                Text(caption(hasCalculation: calculated != nil, stairPoints: stairPoints))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 6)
            }
        }
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    private var verticalTitle: String {
        switch mode {
        case .pipe: language.text("偏移", "Offset")
        case .stairs: language.text("层高", "Rise")
        default: language.text("高差", "Rise")
        }
    }

    private var lengthTitle: String {
        switch mode {
        case .stairs: language.text("连线", "Line")
        case .pipe: language.text("斜距", "Travel")
        default: language.text("斜长", "Length")
        }
    }

    private var angleTitle: String {
        mode == .stairs ? language.text("连线角", "Line angle") : language.text("倾角", "Angle")
    }

    private func labelValue(_ value: Double?, unit: String) -> String? {
        value.map { "\($0.formatted(maxDigits: 4)) \(unit)" }
    }

    private func caption(hasCalculation: Bool, stairPoints: [CGPoint]) -> String {
        guard hasCalculation else {
            return language.text("示意图 · 输入后按比例绘制", "Diagram · drawn to scale after input")
        }
        var text = language.text("按比例绘制", "Drawn to scale")
        if mode == .stairs, stairPoints.isEmpty {
            text += language.text(" · 踏步过密，仅显示端点连线", " · steps too dense; endpoints only")
        }
        if mode == .pipe {
            text += language.text(" · 弯头中心点间连线", " · between elbow center points")
        }
        if mode == .wood {
            text += language.text(" · 两端接触点间连线", " · between endpoint contacts")
        }
        return text
    }
}

private struct SceneDiagramLabel: View {
    let title: String
    let value: String?
    let isAngle: Bool

    var body: some View {
        Group {
            if isAngle {
                VStack(alignment: .trailing, spacing: 0) { labelContent }
            } else {
                HStack(spacing: 4) { labelContent }
            }
        }
        .font(.caption2)
        .padding(.horizontal, 3)
        .padding(.vertical, 1)
        .background(Color(uiColor: .systemBackground).opacity(0.94), in: RoundedRectangle(cornerRadius: 3))
        .fixedSize()
    }

    @ViewBuilder private var labelContent: some View {
        Text(title).foregroundStyle(.secondary)
        if let value { Text(value).foregroundStyle(.primary.opacity(0.75)) }
    }
}
