import Combine
import Foundation

struct TriangleInputFields: Equatable, Sendable {
    var a = ""
    var b = ""
    var c = ""
    var A = ""
    var B = ""
    var C = ""

    subscript(_ key: TriangleField) -> String {
        get {
            switch key { case .a: a; case .b: b; case .c: c; case .A: A; case .B: B; case .C: C }
        }
        set {
            switch key { case .a: a = newValue; case .b: b = newValue; case .c: c = newValue; case .A: A = newValue; case .B: B = newValue; case .C: C = newValue }
        }
    }

    var nonemptyCount: Int {
        [a, b, c, A, B, C].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    mutating func autoFillThirdAngle(angleUnit: AngleUnit) -> ThirdAngleFillResult {
        let angles: [(TriangleField, String)] = [(.A, A), (.B, B), (.C, C)]
        let provided = angles.compactMap { field, raw -> (TriangleField, Double)? in
            NumericInput.double(raw).map { (field, $0) }
        }
        let empty = angles.filter { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasSideInput = [a, b, c].contains { NumericInput.double($0) != nil }

        guard provided.count == 2, empty.count == 1, !hasSideInput else { return .none }

        let upperBound = angleUnit == .degrees ? 180.0 : Double.pi
        let missing = upperBound - provided.reduce(0) { $0 + $1.1 }
        guard missing > 1e-6, missing < upperBound - 1e-6 else {
            return .invalid(angleUnit == .degrees ? "两角之和需小于 180" : "两角之和需小于 π 弧度")
        }

        let missingField = empty[0].0
        self[missingField] = missing.formatted(maxDigits: angleUnit == .degrees ? 8 : 10)
        return .filled(missingField)
    }

    mutating func reset() { self = TriangleInputFields() }
}

enum ThirdAngleFillResult: Equatable, Sendable {
    case none
    case filled(TriangleField)
    case invalid(String)
}

enum TriangleField: String, CaseIterable, Identifiable, Sendable {
    case a, b, c, A, B, C
    var id: String { rawValue }
    var isAngle: Bool { rawValue.uppercased() == rawValue }
}

enum CalculationState: Equatable {
    case idle
    case waiting(String)
    case success
    case failure(String)
}

struct CalculationStep: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
    let formula: String?
}

@MainActor
final class TriangleCalculatorViewModel: ObservableObject {
    @Published var fields = TriangleInputFields()
    @Published var angleUnit: AngleUnit = .degrees
    @Published var resultAngleUnit: AngleUnit = .degrees
    @Published var solutions: [TriangleSolution] = []
    @Published var selectedSolutionIndex = 0
    @Published var state: CalculationState = .idle
    @Published var steps: [CalculationStep] = []

    private var computeTask: Task<Void, Never>?
    private var autoFillTask: Task<Void, Never>?
    private var lastSavedFingerprint = ""

    var selectedSolution: TriangleSolution? {
        guard solutions.indices.contains(selectedSolutionIndex) else { return nil }
        return solutions[selectedSolutionIndex]
    }

    func fieldBinding(_ field: TriangleField) -> Published<TriangleInputFields>.Publisher { $fields }

    func updateField(_ field: TriangleField, value: String, store: AppStore) {
        guard fields[field] != value else { return }
        fields[field] = value
        autoFillTask?.cancel()

        guard field.isAngle else {
            scheduleCompute(store: store)
            return
        }

        computeTask?.cancel()
        let count = fields.nonemptyCount
        if count == 0 {
            clearResult(state: .idle)
        } else if count < 2 {
            clearResult(state: .waiting(store.language.text("再输入 \(3 - count) 项即可计算", "Enter \(3 - count) more value(s)")))
        } else {
            clearResult(state: .waiting(store.language.text("正在检查角度…", "Checking angles…")))
        }

        autoFillTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            switch self.fields.autoFillThirdAngle(angleUnit: self.angleUnit) {
            case .none:
                self.scheduleCompute(store: store)
            case .filled:
                self.scheduleCompute(store: store, waitingMessage: store.language.text("已补全第三个角，正在计算…", "Third angle completed. Calculating…"))
            case .invalid:
                let message = self.angleUnit == .degrees
                    ? store.language.text("两角之和需小于 180°", "The two angles must add up to less than 180°")
                    : store.language.text("两角之和需小于 π 弧度", "The two angles must add up to less than π radians")
                self.clearResult(state: .failure(message))
            }
        }
    }

    func scheduleCompute(store: AppStore, waitingMessage: String? = nil) {
        computeTask?.cancel()
        let count = fields.nonemptyCount
        if count == 0 {
            clearResult(state: .idle)
            return
        }
        if count < 3 {
            clearResult(state: .waiting(store.language.text("再输入 \(3 - count) 项即可计算", "Enter \(3 - count) more value(s)")))
            return
        }
        state = .waiting(waitingMessage ?? store.language.text("正在检查输入…", "Checking input…"))
        computeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled, let self else { return }
            self.compute(store: store, save: true)
        }
    }

    func compute(store: AppStore, save: Bool) {
        do {
            let parsed = try parseFields()
            let normalized: TriangleGiven
            if let locked = try TriangleSolver.normalizedLockedAngles(parsed, angleUnit: angleUnit) {
                normalized = locked
            } else {
                normalized = parsed
            }
            solutions = try TriangleSolver.solve(normalized, angleUnit: angleUnit)
            selectedSolutionIndex = min(selectedSolutionIndex, solutions.count - 1)
            state = .success
            steps = Self.buildSteps(given: normalizedInDegrees(normalized), solution: solutions[selectedSolutionIndex], language: store.language)
            if save, let first = solutions.first {
                let fingerprint = normalized.summary(angleUnit: angleUnit) + "|" + first.a.formatted(maxDigits: 8)
                if fingerprint != lastSavedFingerprint {
                    store.saveHistory(given: normalizedInDegrees(normalized), angleUnit: angleUnit, solution: first, solutionCount: solutions.count)
                    lastSavedFingerprint = fingerprint
                }
            }
        } catch {
            let message = (error as? TriangleSolveError)?.message(language: store.language) ?? error.localizedDescription
            clearResult(state: .failure(message))
        }
    }

    func selectSolution(_ index: Int, language: AppLanguage) {
        guard solutions.indices.contains(index) else { return }
        selectedSolutionIndex = index
        guard let given = try? parseFields() else { return }
        let normalized = (try? TriangleSolver.normalizedLockedAngles(given, angleUnit: angleUnit)) ?? given
        steps = Self.buildSteps(given: normalizedInDegrees(normalized), solution: solutions[index], language: language)
    }

    func refreshLanguage(store: AppStore) {
        if let solution = selectedSolution, let parsed = try? parseFields() {
            let normalized = (try? TriangleSolver.normalizedLockedAngles(parsed, angleUnit: angleUnit)) ?? parsed
            steps = Self.buildSteps(given: normalizedInDegrees(normalized), solution: solution, language: store.language)
            return
        }

        switch state {
        case .idle:
            break
        case .waiting:
            let remaining = max(0, 3 - fields.nonemptyCount)
            state = .waiting(remaining > 0
                ? store.language.text("再输入 \(remaining) 项即可计算", "Enter \(remaining) more value(s)")
                : store.language.text("正在检查输入…", "Checking input…"))
        case .failure:
            if fields.nonemptyCount < 3 {
                state = .failure(angleUnit == .degrees
                    ? store.language.text("两角之和需小于 180°", "The two angles must add up to less than 180°")
                    : store.language.text("两角之和需小于 π 弧度", "The two angles must add up to less than π radians"))
            } else {
                compute(store: store, save: false)
            }
        case .success:
            break
        }
    }

    func reset() {
        computeTask?.cancel()
        autoFillTask?.cancel()
        fields.reset()
        clearResult(state: .idle)
    }

    func toggleInputUnit(store: AppStore) {
        computeTask?.cancel()
        autoFillTask?.cancel()
        let old = angleUnit
        let next: AngleUnit = old == .degrees ? .radians : .degrees
        for field in [TriangleField.A, .B, .C] {
            guard let value = NumericInput.double(fields[field]) else { continue }
            let converted = old == .degrees ? value * .pi / 180 : value * 180 / .pi
            fields[field] = converted.formatted(maxDigits: next == .degrees ? 6 : 8)
        }
        angleUnit = next
        scheduleCompute(store: store)
    }

    func restore(_ record: TriangleHistoryRecord, store: AppStore) {
        computeTask?.cancel()
        autoFillTask?.cancel()
        angleUnit = record.angleUnit
        fields.reset()
        fields.a = record.given.a.map { $0.formatted(maxDigits: 8) } ?? ""
        fields.b = record.given.b.map { $0.formatted(maxDigits: 8) } ?? ""
        fields.c = record.given.c.map { $0.formatted(maxDigits: 8) } ?? ""
        let convert: (Double?) -> String = { value in
            guard let value else { return "" }
            let shown = record.angleUnit == .degrees ? value : value * .pi / 180
            return shown.formatted(maxDigits: record.angleUnit == .degrees ? 6 : 8)
        }
        fields.A = convert(record.given.A)
        fields.B = convert(record.given.B)
        fields.C = convert(record.given.C)
        compute(store: store, save: false)
    }

    func resultText(language: AppLanguage = .simplifiedChinese) -> String {
        guard let solution = selectedSolution else { return "" }
        let angle: (Double) -> String = { value in
            let shown = self.resultAngleUnit == .degrees ? value : value * .pi / 180
            return shown.formatted(maxDigits: self.resultAngleUnit == .degrees ? 3 : 4) + self.resultAngleUnit.symbol
        }
        return """
        \(language.text("啵啵几何工坊", "Bobo Geometry Workshop"))
        a = \(solution.a.formatted(maxDigits: 4))    A = \(angle(solution.A))
        b = \(solution.b.formatted(maxDigits: 4))    B = \(angle(solution.B))
        c = \(solution.c.formatted(maxDigits: 4))    C = \(angle(solution.C))
        \(language.text("面积", "Area")) = \(solution.area.formatted(maxDigits: 4))
        \(language.text("周长", "Perimeter")) = \(solution.perimeter.formatted(maxDigits: 4))
        """
    }

    private func parseFields() throws -> TriangleGiven {
        func number(_ raw: String, name: String, isAngle: Bool = false) throws -> Double? {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            guard let value = NumericInput.double(trimmed) else {
                throw isAngle ? TriangleSolveError.invalidAngle(name) : TriangleSolveError.invalidSide(name)
            }
            return value
        }
        return try TriangleGiven(
            a: number(fields.a, name: "a"), b: number(fields.b, name: "b"), c: number(fields.c, name: "c"),
            A: number(fields.A, name: "A", isAngle: true), B: number(fields.B, name: "B", isAngle: true), C: number(fields.C, name: "C", isAngle: true)
        )
    }

    private func normalizedInDegrees(_ given: TriangleGiven) -> TriangleGiven {
        guard angleUnit == .radians else { return given }
        return TriangleGiven(
            a: given.a, b: given.b, c: given.c,
            A: given.A.map { $0 * 180 / .pi }, B: given.B.map { $0 * 180 / .pi }, C: given.C.map { $0 * 180 / .pi }
        )
    }

    private func clearResult(state: CalculationState) {
        solutions = []
        selectedSolutionIndex = 0
        steps = []
        self.state = state
    }

    static func buildSteps(given: TriangleGiven, solution: TriangleSolution, language: AppLanguage = .simplifiedChinese) -> [CalculationStep] {
        if given.sideCount == 3 { return buildSSSSteps(given: given, solution: solution, language: language) }
        if given.angleCount == 3 { return buildAAASteps(given: given, solution: solution, language: language) }
        if given.sideCount == 1, given.angleCount == 2 { return buildAASSteps(given: given, solution: solution, language: language) }
        if isSAS(given) { return buildSASSteps(given: given, solution: solution, language: language) }
        return buildSSASteps(given: given, solution: solution, language: language)
    }

    private static func buildSSSSteps(given: TriangleGiven, solution: TriangleSolution, language: AppLanguage) -> [CalculationStep] {
        let f = { (value: Double) in value.formatted(maxDigits: 4) }
        return [
            CalculationStep(title: language.text("已知条件 · SSS", "Known values · SSS"), detail: given.summary(angleUnit: .degrees), formula: nil),
            CalculationStep(title: language.text("计算角 A", "Calculate angle A"), detail: "A = arccos((\(f(given.b!))² + \(f(given.c!))² − \(f(given.a!))²) / (2 × \(f(given.b!)) × \(f(given.c!)))) = \(f(solution.A))°", formula: "cos A = (b² + c² − a²) / (2bc)"),
            CalculationStep(title: language.text("计算角 B", "Calculate angle B"), detail: "B = arccos((\(f(given.a!))² + \(f(given.c!))² − \(f(given.b!))²) / (2 × \(f(given.a!)) × \(f(given.c!)))) = \(f(solution.B))°", formula: "cos B = (a² + c² − b²) / (2ac)"),
            CalculationStep(title: language.text("计算角 C", "Calculate angle C"), detail: "C = 180° − \(f(solution.A))° − \(f(solution.B))° = \(f(solution.C))°", formula: "C = 180° − A − B")
        ]
    }

    private static func buildSASSteps(given: TriangleGiven, solution: TriangleSolution, language: AppLanguage) -> [CalculationStep] {
        let angle = ["A", "B", "C"].first { angleValue(given, $0) != nil }!
        let targetSide = angle.lowercased()
        let knownSides = ["a", "b", "c"].filter { sideValue(given, $0) != nil }
        let first = knownSides[0], second = knownSides[1]
        let angleNumber = angleValue(given, angle)!
        let targetValue = sideValue(solution, targetSide)
        let remainingAngles = ["A", "B", "C"].filter { $0 != angle }
        let formulas = remainingAngles.map { cosineFormula(for: $0) }.joined(separator: "\n")
        let results = remainingAngles.map { "\($0) = \(angleValue(solution, $0).formatted(maxDigits: 4))°" }.joined(separator: " · ")
        return [
            CalculationStep(title: language.text("已知条件 · SAS", "Known values · SAS"), detail: given.summary(angleUnit: .degrees), formula: nil),
            CalculationStep(title: language.text("计算第三边 \(targetSide)", "Calculate side \(targetSide)"), detail: "\(targetSide) = √(\(sideValue(given, first)!.formatted(maxDigits: 4))² + \(sideValue(given, second)!.formatted(maxDigits: 4))² − 2 × \(sideValue(given, first)!.formatted(maxDigits: 4)) × \(sideValue(given, second)!.formatted(maxDigits: 4)) × cos \(angleNumber.formatted(maxDigits: 4))°) = \(targetValue.formatted(maxDigits: 4))", formula: "\(targetSide)² = \(first)² + \(second)² − 2\(first)\(second)·cos \(angle)"),
            CalculationStep(title: language.text("计算其余角", "Calculate remaining angles"), detail: results, formula: formulas)
        ]
    }

    private static func buildSSASteps(given: TriangleGiven, solution: TriangleSolution, language: AppLanguage) -> [CalculationStep] {
        let knownAngle = ["A", "B", "C"].first { name in
            angleValue(given, name) != nil && sideValue(given, name.lowercased()) != nil
        }!
        let knownSide = knownAngle.lowercased()
        let otherSide = ["a", "b", "c"].first { $0 != knownSide && sideValue(given, $0) != nil }!
        let otherAngle = otherSide.uppercased()
        let thirdSide = ["a", "b", "c"].first { $0 != knownSide && $0 != otherSide }!
        let thirdAngle = thirdSide.uppercased()
        let knownAngleValue = angleValue(given, knownAngle)!
        var steps = [CalculationStep(title: language.text("已知条件 · SSA", "Known values · SSA"), detail: given.summary(angleUnit: .degrees), formula: nil)]
        if solution.isAmbiguous {
            steps.append(CalculationStep(
                title: language.text("二义性分析 · 解 \(solution.variant)", "Ambiguous case · Solution \(solution.variant)"),
                detail: language.text("反正弦可能对应两个互为补角的角；当前步骤使用第 \(solution.variant) 个有效解。", "Inverse sine can produce supplementary angles; these steps use valid solution \(solution.variant)."),
                formula: "\(otherAngle)₁ = arcsin(x),  \(otherAngle)₂ = 180° − \(otherAngle)₁"
            ))
        }
        steps.append(CalculationStep(
            title: language.text("计算角 \(otherAngle)", "Calculate angle \(otherAngle)"),
            detail: "sin \(otherAngle) = \(sideValue(given, otherSide)!.formatted(maxDigits: 4)) × sin \(knownAngleValue.formatted(maxDigits: 4))° / \(sideValue(given, knownSide)!.formatted(maxDigits: 4));  \(otherAngle) = \(angleValue(solution, otherAngle).formatted(maxDigits: 4))°",
            formula: "sin \(otherAngle) / \(otherSide) = sin \(knownAngle) / \(knownSide)"
        ))
        steps.append(CalculationStep(
            title: language.text("计算角 \(thirdAngle)", "Calculate angle \(thirdAngle)"),
            detail: "\(thirdAngle) = 180° − \(angleValue(solution, knownAngle).formatted(maxDigits: 4))° − \(angleValue(solution, otherAngle).formatted(maxDigits: 4))° = \(angleValue(solution, thirdAngle).formatted(maxDigits: 4))°",
            formula: "\(thirdAngle) = 180° − \(knownAngle) − \(otherAngle)"
        ))
        steps.append(CalculationStep(
            title: language.text("计算边 \(thirdSide)", "Calculate side \(thirdSide)"),
            detail: "\(thirdSide) = \(sideValue(given, knownSide)!.formatted(maxDigits: 4)) × sin \(angleValue(solution, thirdAngle).formatted(maxDigits: 4))° / sin \(knownAngleValue.formatted(maxDigits: 4))° = \(sideValue(solution, thirdSide).formatted(maxDigits: 4))",
            formula: "\(thirdSide) = \(knownSide) × sin \(thirdAngle) / sin \(knownAngle)"
        ))
        return steps
    }

    private static func buildAASSteps(given: TriangleGiven, solution: TriangleSolution, language: AppLanguage) -> [CalculationStep] {
        let knownAngles = ["A", "B", "C"].filter { angleValue(given, $0) != nil }
        let unknownAngle = ["A", "B", "C"].first { !knownAngles.contains($0) }!
        let knownSide = ["a", "b", "c"].first { sideValue(given, $0) != nil }!
        let unknownSides = ["a", "b", "c"].filter { $0 != knownSide }
        var steps = [
            CalculationStep(title: language.text("已知条件 · AAS / ASA", "Known values · AAS / ASA"), detail: given.summary(angleUnit: .degrees), formula: nil),
            CalculationStep(title: language.text("计算第三角 \(unknownAngle)", "Calculate angle \(unknownAngle)"), detail: "\(unknownAngle) = 180° − \(angleValue(given, knownAngles[0])!.formatted(maxDigits: 4))° − \(angleValue(given, knownAngles[1])!.formatted(maxDigits: 4))° = \(angleValue(solution, unknownAngle).formatted(maxDigits: 4))°", formula: "\(unknownAngle) = 180° − \(knownAngles[0]) − \(knownAngles[1])")
        ]
        for side in unknownSides {
            steps.append(CalculationStep(
                title: language.text("计算边 \(side)", "Calculate side \(side)"),
                detail: "\(side) = \(sideValue(given, knownSide)!.formatted(maxDigits: 4)) × sin \(angleValue(solution, side.uppercased()).formatted(maxDigits: 4))° / sin \(angleValue(solution, knownSide.uppercased()).formatted(maxDigits: 4))° = \(sideValue(solution, side).formatted(maxDigits: 4))",
                formula: "\(side) = \(knownSide) × sin \(side.uppercased()) / sin \(knownSide.uppercased())"
            ))
        }
        return steps
    }

    private static func buildAAASteps(given: TriangleGiven, solution: TriangleSolution, language: AppLanguage) -> [CalculationStep] {
        [
            CalculationStep(title: language.text("已知条件 · AAA", "Known values · AAA"), detail: given.summary(angleUnit: .degrees), formula: nil),
            CalculationStep(title: language.text("设定基准边", "Set a reference side"), detail: language.text("三个角只能确定形状，不能确定尺寸，因此设 c = 1。", "Three angles determine shape but not scale, so set c = 1."), formula: "c = 1"),
            CalculationStep(title: language.text("计算边 a", "Calculate side a"), detail: "a = 1 × sin \(solution.A.formatted(maxDigits: 4))° / sin \(solution.C.formatted(maxDigits: 4))° = \(solution.a.formatted(maxDigits: 4))", formula: "a = c × sin A / sin C"),
            CalculationStep(title: language.text("计算边 b", "Calculate side b"), detail: "b = 1 × sin \(solution.B.formatted(maxDigits: 4))° / sin \(solution.C.formatted(maxDigits: 4))° = \(solution.b.formatted(maxDigits: 4))", formula: "b = c × sin B / sin C")
        ]
    }

    private static func isSAS(_ given: TriangleGiven) -> Bool {
        (given.A != nil && given.b != nil && given.c != nil)
            || (given.B != nil && given.a != nil && given.c != nil)
            || (given.C != nil && given.a != nil && given.b != nil)
    }

    private static func cosineFormula(for angle: String) -> String {
        let opposite = angle.lowercased()
        let adjacent = ["a", "b", "c"].filter { $0 != opposite }
        return "cos \(angle) = (\(adjacent[0])² + \(adjacent[1])² − \(opposite)²) / (2\(adjacent[0])\(adjacent[1]))"
    }

    private static func sideValue(_ given: TriangleGiven, _ name: String) -> Double? {
        switch name { case "a": given.a; case "b": given.b; case "c": given.c; default: nil }
    }

    private static func sideValue(_ solution: TriangleSolution, _ name: String) -> Double {
        switch name { case "a": solution.a; case "b": solution.b; default: solution.c }
    }

    private static func angleValue(_ given: TriangleGiven, _ name: String) -> Double? {
        switch name { case "A": given.A; case "B": given.B; case "C": given.C; default: nil }
    }

    private static func angleValue(_ solution: TriangleSolution, _ name: String) -> Double {
        switch name { case "A": solution.A; case "B": solution.B; default: solution.C }
    }
}
