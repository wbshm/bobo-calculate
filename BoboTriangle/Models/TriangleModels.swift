import Foundation

struct TriangleGiven: Codable, Equatable, Sendable {
    var a: Double?
    var b: Double?
    var c: Double?
    var A: Double?
    var B: Double?
    var C: Double?

    var definedCount: Int {
        [a, b, c, A, B, C].compactMap { $0 }.count
    }

    var sideCount: Int { [a, b, c].compactMap { $0 }.count }
    var angleCount: Int { [A, B, C].compactMap { $0 }.count }

    var pattern: String {
        [("a", a), ("b", b), ("c", c), ("A", A), ("B", B), ("C", C)]
            .compactMap { $0.1 == nil ? nil : $0.0 }
            .joined()
    }

    func summary(angleUnit: AngleUnit) -> String {
        var values: [String] = []
        if let a { values.append("a=\(a.formatted(maxDigits: 4))") }
        if let b { values.append("b=\(b.formatted(maxDigits: 4))") }
        if let c { values.append("c=\(c.formatted(maxDigits: 4))") }
        let angle: (String, Double?) -> Void = { name, value in
            guard let value else { return }
            let converted = angleUnit == .degrees ? value : value * .pi / 180
            values.append("\(name)=\(converted.formatted(maxDigits: angleUnit == .degrees ? 3 : 4))\(angleUnit.symbol)")
        }
        angle("A", A); angle("B", B); angle("C", C)
        return values.joined(separator: " · ")
    }
}

struct TriangleSolution: Codable, Equatable, Sendable {
    let a: Double
    let b: Double
    let c: Double
    let A: Double
    let B: Double
    let C: Double
    var isAmbiguous = false
    var variant = 1
    var scale: Double?

    var perimeter: Double { a + b + c }

    var semiPerimeter: Double { perimeter / 2 }

    var area: Double {
        let s = semiPerimeter
        return sqrt(max(0, s * (s - a) * (s - b) * (s - c)))
    }

    var heightA: Double { 2 * area / a }
    var heightB: Double { 2 * area / b }
    var heightC: Double { 2 * area / c }
    var inradius: Double { area / semiPerimeter }
    var circumradius: Double { a * b * c / (4 * area) }
}

enum AngleUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case degrees
    case radians

    var id: String { rawValue }
    var title: String { self == .degrees ? "角度" : "弧度" }
    func title(language: AppLanguage) -> String {
        language.text(self == .degrees ? "角度" : "弧度", self == .degrees ? "Degrees" : "Radians")
    }
    var symbol: String { self == .degrees ? "°" : " rad" }
}

enum TriangleSolveError: LocalizedError, Equatable {
    case count
    case invalidAngle(String)
    case invalidSide(String)
    case angleSum
    case invalidSSS
    case noSolution
    case unsupported

    var errorDescription: String? {
        switch self {
        case .count: "必须且仅提供 3 个已知量（a、b、c、A、B、C）"
        case let .invalidAngle(name): "\(name) 必须在 0 到 180 之间"
        case let .invalidSide(name): "\(name) 必须大于 0"
        case .angleSum: "三个角的和必须为 180°"
        case .invalidSSS: "三角形不等式不成立"
        case .noSolution: "这些条件不能组成三角形"
        case .unsupported: "当前三项组合无法求解"
        }
    }

    func message(language: AppLanguage) -> String {
        switch self {
        case .count: language.text("必须且仅提供 3 个已知量（a、b、c、A、B、C）", "Enter exactly 3 known values (a, b, c, A, B, C)")
        case let .invalidAngle(name): language.text("\(name) 必须在 0 到 180 之间", "\(name) must be between 0 and 180")
        case let .invalidSide(name): language.text("\(name) 必须大于 0", "\(name) must be greater than 0")
        case .angleSum: language.text("三个角的和必须为 180°", "The three angles must add up to 180°")
        case .invalidSSS: language.text("三角形不等式不成立", "The triangle inequality is not satisfied")
        case .noSolution: language.text("这些条件不能组成三角形", "These values cannot form a triangle")
        case .unsupported: language.text("当前三项组合无法求解", "This combination of values cannot be solved")
        }
    }
}

enum TriangleSolver {
    private static let tolerance = 1e-9

    static func solve(_ input: TriangleGiven, angleUnit: AngleUnit = .degrees, defaultBase: Double = 1) throws -> [TriangleSolution] {
        var given = input
        if angleUnit == .radians {
            given.A = given.A.map(toDegrees)
            given.B = given.B.map(toDegrees)
            given.C = given.C.map(toDegrees)
        }
        guard given.definedCount == 3 else { throw TriangleSolveError.count }
        try validate(given)

        let solutions: [TriangleSolution]
        switch (given.sideCount, given.angleCount) {
        case (0, 3):
            solutions = [try solveAAA(given, defaultBase: defaultBase)]
        case (3, 0):
            solutions = [try solveSSS(a: given.a!, b: given.b!, c: given.c!)]
        case (1, 2):
            solutions = [try solveAAS(given)]
        case (2, 1):
            solutions = isSAS(given) ? [try solveSAS(given)] : try solveSSA(given)
        default:
            throw TriangleSolveError.unsupported
        }

        return solutions.enumerated().map { index, value in
            var solution = value
            if solutions.count > 1 {
                solution.isAmbiguous = true
                solution.variant = index + 1
            }
            return solution
        }
    }

    static func normalizedLockedAngles(_ input: TriangleGiven, angleUnit: AngleUnit) throws -> TriangleGiven? {
        guard input.angleCount == 3, input.sideCount == 1 else { return nil }
        var degrees = input
        if angleUnit == .radians {
            degrees.A = degrees.A.map(toDegrees)
            degrees.B = degrees.B.map(toDegrees)
            degrees.C = degrees.C.map(toDegrees)
        }
        guard let A = degrees.A, let B = degrees.B, let C = degrees.C,
              abs(A + B + C - 180) <= 0.001 else { throw TriangleSolveError.angleSum }
        // Two angles plus the chosen scale side uniquely define the same triangle.
        if input.a != nil { return TriangleGiven(a: input.a, A: input.A, B: input.B) }
        if input.b != nil { return TriangleGiven(b: input.b, A: input.A, B: input.B) }
        return TriangleGiven(c: input.c, A: input.A, B: input.B)
    }

    private static func validate(_ given: TriangleGiven) throws {
        for (name, value) in [("a", given.a), ("b", given.b), ("c", given.c)] {
            if let value, !(value > 0) { throw TriangleSolveError.invalidSide(name) }
        }
        for (name, value) in [("A", given.A), ("B", given.B), ("C", given.C)] {
            if let value, !(value > 0 && value < 180) { throw TriangleSolveError.invalidAngle(name) }
        }
    }

    private static func solveSSS(a: Double, b: Double, c: Double) throws -> TriangleSolution {
        guard a + b > c, a + c > b, b + c > a else { throw TriangleSolveError.invalidSSS }
        let A = toDegrees(acos(clamp((b * b + c * c - a * a) / (2 * b * c))))
        let B = toDegrees(acos(clamp((a * a + c * c - b * b) / (2 * a * c))))
        let C = 180 - A - B
        return TriangleSolution(a: a, b: b, c: c, A: A, B: B, C: C)
    }

    private static func solveAAA(_ given: TriangleGiven, defaultBase: Double) throws -> TriangleSolution {
        guard let A = given.A, let B = given.B, let C = given.C,
              abs(A + B + C - 180) <= 0.001 else { throw TriangleSolveError.angleSum }
        let adjusted = normalizedAngles(A, B, C)
        let c = defaultBase
        let a = c * sin(toRadians(adjusted.0)) / sin(toRadians(adjusted.2))
        let b = c * sin(toRadians(adjusted.1)) / sin(toRadians(adjusted.2))
        return TriangleSolution(a: a, b: b, c: c, A: adjusted.0, B: adjusted.1, C: adjusted.2, scale: defaultBase)
    }

    private static func solveAAS(_ given: TriangleGiven) throws -> TriangleSolution {
        var A = given.A ?? 0
        var B = given.B ?? 0
        var C = given.C ?? 0
        if given.A == nil { A = 180 - B - C }
        if given.B == nil { B = 180 - A - C }
        if given.C == nil { C = 180 - A - B }
        for (name, value) in [("A", A), ("B", B), ("C", C)] {
            guard value > 0 && value < 180 else { throw TriangleSolveError.invalidAngle(name) }
        }
        (A, B, C) = normalizedAngles(A, B, C)
        if let a = given.a {
            return TriangleSolution(a: a, b: a * sin(toRadians(B)) / sin(toRadians(A)), c: a * sin(toRadians(C)) / sin(toRadians(A)), A: A, B: B, C: C)
        }
        if let b = given.b {
            return TriangleSolution(a: b * sin(toRadians(A)) / sin(toRadians(B)), b: b, c: b * sin(toRadians(C)) / sin(toRadians(B)), A: A, B: B, C: C)
        }
        guard let c = given.c else { throw TriangleSolveError.unsupported }
        return TriangleSolution(a: c * sin(toRadians(A)) / sin(toRadians(C)), b: c * sin(toRadians(B)) / sin(toRadians(C)), c: c, A: A, B: B, C: C)
    }

    private static func isSAS(_ given: TriangleGiven) -> Bool {
        (given.A != nil && given.b != nil && given.c != nil)
            || (given.B != nil && given.a != nil && given.c != nil)
            || (given.C != nil && given.a != nil && given.b != nil)
    }

    private static func solveSAS(_ given: TriangleGiven) throws -> TriangleSolution {
        if let A = given.A, let b = given.b, let c = given.c {
            return try solveSSS(a: sqrt(b * b + c * c - 2 * b * c * cos(toRadians(A))), b: b, c: c)
        }
        if let B = given.B, let a = given.a, let c = given.c {
            return try solveSSS(a: a, b: sqrt(a * a + c * c - 2 * a * c * cos(toRadians(B))), c: c)
        }
        guard let C = given.C, let a = given.a, let b = given.b else { throw TriangleSolveError.unsupported }
        return try solveSSS(a: a, b: b, c: sqrt(a * a + b * b - 2 * a * b * cos(toRadians(C))))
    }

    private static func solveSSA(_ given: TriangleGiven) throws -> [TriangleSolution] {
        let known: (String, Double, Double)
        if let A = given.A, let a = given.a { known = ("A", A, a) }
        else if let B = given.B, let b = given.b { known = ("B", B, b) }
        else if let C = given.C, let c = given.c { known = ("C", C, c) }
        else { throw TriangleSolveError.unsupported }

        let other: (String, Double)
        if known.0 != "A", let a = given.a { other = ("A", a) }
        else if known.0 != "B", let b = given.b { other = ("B", b) }
        else if known.0 != "C", let c = given.c { other = ("C", c) }
        else { throw TriangleSolveError.unsupported }

        let sine = other.1 * sin(toRadians(known.1)) / known.2
        guard sine <= 1 + 1e-12 else { throw TriangleSolveError.noSolution }
        let first = toDegrees(asin(clamp(sine)))
        let candidates = sine >= 1 - 1e-12 ? [first] : [first, 180 - first]
        let results = candidates.compactMap { otherAngle -> TriangleSolution? in
            let third = 180 - known.1 - otherAngle
            guard third > 1e-6 else { return nil }
            var angles = ["A": 0.0, "B": 0.0, "C": 0.0]
            angles[known.0] = known.1
            angles[other.0] = otherAngle
            let thirdName = ["A", "B", "C"].first { $0 != known.0 && $0 != other.0 }!
            angles[thirdName] = third
            let A = angles["A"]!, B = angles["B"]!, C = angles["C"]!
            let scale = known.2 / sin(toRadians(known.1))
            return TriangleSolution(
                a: scale * sin(toRadians(A)),
                b: scale * sin(toRadians(B)),
                c: scale * sin(toRadians(C)),
                A: A, B: B, C: C
            )
        }
        guard !results.isEmpty else { throw TriangleSolveError.noSolution }
        return results
    }

    private static func normalizedAngles(_ A: Double, _ B: Double, _ C: Double) -> (Double, Double, Double) {
        let factor = 180 / (A + B + C)
        return (A * factor, B * factor, C * factor)
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(-1, value)) }
    private static func toRadians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func toDegrees(_ radians: Double) -> Double { radians * 180 / .pi }
}

enum TriangleKind: String, Codable, Sendable {
    case equilateral, isosceles, right, obtuse, acute

    var title: String {
        switch self {
        case .equilateral: "等边三角形"
        case .isosceles: "等腰三角形"
        case .right: "直角三角形"
        case .obtuse: "钝角三角形"
        case .acute: "锐角三角形"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .equilateral: language.text("等边三角形", "Equilateral triangle")
        case .isosceles: language.text("等腰三角形", "Isosceles triangle")
        case .right: language.text("直角三角形", "Right triangle")
        case .obtuse: language.text("钝角三角形", "Obtuse triangle")
        case .acute: language.text("锐角三角形", "Acute triangle")
        }
    }

    static func detect(_ solution: TriangleSolution) -> TriangleKind {
        let sides = [solution.a, solution.b, solution.c]
        let sideTolerance = max(sides.max() ?? 1, 1) * 1e-6
        let equal: (Double, Double) -> Bool = { abs($0 - $1) <= sideTolerance }
        if equal(solution.a, solution.b), equal(solution.b, solution.c) { return .equilateral }
        if equal(solution.a, solution.b) || equal(solution.b, solution.c) || equal(solution.a, solution.c) { return .isosceles }
        let angles = [solution.A, solution.B, solution.C]
        if angles.contains(where: { abs($0 - 90) <= 1e-6 }) { return .right }
        if angles.contains(where: { $0 > 90 }) { return .obtuse }
        return .acute
    }
}

extension Double {
    func formatted(maxDigits: Int) -> String {
        guard isFinite else { return "-" }
        // These strings also populate editable inputs; grouping separators would
        // be parsed as decimal separators by NumericInput (e.g. 1,200 -> 1.2).
        return formatted(.number
            .grouping(.never)
            .precision(.fractionLength(0...maxDigits))
            .locale(Locale(identifier: "en_US_POSIX")))
    }
}
