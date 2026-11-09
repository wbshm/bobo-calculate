import Foundation

enum NumericInput {
    static func double(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let halfWidth = trimmed.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? trimmed
        let normalized = halfWidth
            .replacingOccurrences(of: "，", with: ".")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    static func integer(_ raw: String) -> Int? {
        guard let value = double(raw), value.rounded() == value,
              value >= Double(Int.min), value <= Double(Int.max) else { return nil }
        return Int(value)
    }
}

enum LengthUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case mm, cm, m
    var id: String { rawValue }

    private var millimetres: Double {
        switch self { case .mm: 1; case .cm: 10; case .m: 1_000 }
    }

    func convert(_ value: Double, to unit: LengthUnit) -> Double {
        value * millimetres / unit.millimetres
    }
}

enum SceneID: String, CaseIterable, Identifiable, Codable, Sendable {
    case brace, slope, pipe, stairs, wood
    var id: String { rawValue }
    var title: String {
        switch self {
        case .brace: "斜撑长度"
        case .slope: "坡度 / 高差"
        case .pipe: "管道偏移"
        case .stairs: "楼梯计算"
        case .wood: "木工斜切"
        }
    }
    func title(language: AppLanguage) -> String {
        switch self {
        case .brace: language.text("斜撑长度", "Brace Length")
        case .slope: language.text("坡度 / 高差", "Slope / Rise")
        case .pipe: language.text("管道偏移", "Pipe Offset")
        case .stairs: language.text("楼梯计算", "Stair Calculator")
        case .wood: language.text("木工斜切", "Wood Miter")
        }
    }
    var symbol: String {
        switch self {
        case .brace: "ruler"
        case .slope: "chart.line.uptrend.xyaxis"
        case .pipe: "point.bottomleft.forward.to.point.topright.scurvepath"
        case .stairs: "stairs"
        case .wood: "angle"
        }
    }
}

enum SceneMode: String, CaseIterable, Identifiable, Sendable {
    case brace, drop, slope, angle, pipe, stairs, wood
    var id: String { rawValue }
}

struct SceneResult: Equatable, Sendable {
    let run: Double
    let rise: Double
    let length: Double
    let angle: Double
    let slope: Double
}

struct StairsResult: Equatable, Sendable {
    let base: SceneResult
    let risers: Int
    let treads: Int
    let riserHeight: Double
    let treadDepth: Double
    let pitchAngle: Double
}

struct WoodResult: Equatable, Sendable {
    let base: SceneResult
    let horizontalCut: Double
    let verticalCut: Double
    let horizontalSaw: Double
    let verticalSaw: Double
}

enum SceneCalculationError: LocalizedError, Equatable {
    case invalidNumber
    case invalidFirst(SceneMode)
    case negativeSecond
    case zeroHeight
    case invalidAngle
    case invalidRisers
    case overflow

    var errorDescription: String? {
        switch self {
        case .invalidNumber: "请输入有效数字"
        case let .invalidFirst(mode): mode == .pipe ? "偏移高度必须大于 0" : "水平距离必须大于 0"
        case .negativeSecond: "高度、坡度或角度不能为负数"
        case .zeroHeight: "垂直高度必须大于 0"
        case .invalidAngle: "角度需大于 0° 且小于 90°"
        case .invalidRisers: "上升级数需为不小于 2 的整数"
        case .overflow: "数值过大，请缩小输入范围"
        }
    }

    func message(language: AppLanguage) -> String {
        switch self {
        case .invalidNumber: language.text("请输入有效数字", "Enter a valid number")
        case let .invalidFirst(mode): language.text(mode == .pipe ? "偏移高度必须大于 0" : "水平距离必须大于 0", mode == .pipe ? "Offset height must be greater than 0" : "Horizontal distance must be greater than 0")
        case .negativeSecond: language.text("高度、坡度或角度不能为负数", "Height, slope, or angle cannot be negative")
        case .zeroHeight: language.text("垂直高度必须大于 0", "Vertical height must be greater than 0")
        case .invalidAngle: language.text("角度需大于 0° 且小于 90°", "Angle must be greater than 0° and less than 90°")
        case .invalidRisers: language.text("上升级数需为不小于 2 的整数", "Riser count must be an integer of at least 2")
        case .overflow: language.text("数值过大，请缩小输入范围", "Values are too large; use a smaller range")
        }
    }
}

enum SceneCalculator {
    static func calculate(mode: SceneMode, first: Double, second: Double) throws -> SceneResult {
        guard first.isFinite, second.isFinite else { throw SceneCalculationError.invalidNumber }
        guard first > 0 else { throw SceneCalculationError.invalidFirst(mode) }
        guard second >= 0 else { throw SceneCalculationError.negativeSecond }

        var run = first
        var rise = second
        if mode == .drop { rise = first * second / 100 }
        if mode == .angle {
            guard second < 90 else { throw SceneCalculationError.invalidAngle }
            rise = first * tan(second * .pi / 180)
        }
        if [.brace, .stairs, .wood].contains(mode), second == 0 { throw SceneCalculationError.zeroHeight }
        if mode == .pipe {
            guard second > 0, second < 90 else { throw SceneCalculationError.invalidAngle }
            rise = first
            run = first / tan(second * .pi / 180)
        }
        let result = SceneResult(
            run: run,
            rise: rise,
            length: hypot(run, rise),
            angle: atan2(rise, run) * 180 / .pi,
            slope: rise / run * 100
        )
        guard [result.run, result.rise, result.length, result.angle, result.slope].allSatisfy(\.isFinite) else {
            throw SceneCalculationError.overflow
        }
        return result
    }

    static func stairs(run: Double, rise: Double, risers: Int) throws -> StairsResult {
        guard risers >= 2 else { throw SceneCalculationError.invalidRisers }
        let base = try calculate(mode: .stairs, first: run, second: rise)
        let treads = risers - 1
        let riserHeight = rise / Double(risers)
        let treadDepth = run / Double(treads)
        return StairsResult(
            base: base, risers: risers, treads: treads,
            riserHeight: riserHeight, treadDepth: treadDepth,
            pitchAngle: atan2(riserHeight, treadDepth) * 180 / .pi
        )
    }

    static func wood(run: Double, rise: Double) throws -> WoodResult {
        let base = try calculate(mode: .wood, first: run, second: rise)
        return WoodResult(
            base: base,
            horizontalCut: base.angle,
            verticalCut: 90 - base.angle,
            horizontalSaw: 90 - base.angle,
            verticalSaw: base.angle
        )
    }
}
