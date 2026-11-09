import XCTest
import CoreGraphics
@testable import BoboTriangle

final class TriangleCalculatorTests: XCTestCase {
    func testSSS345() throws {
        let solution = try XCTUnwrap(TriangleSolver.solve(TriangleGiven(a: 3, b: 4, c: 5)).first)
        XCTAssertEqual(solution.C, 90, accuracy: 1e-9)
        XCTAssertEqual(solution.area, 6, accuracy: 1e-9)
    }

    func testAAADefaultsToUnitBase() throws {
        let solution = try XCTUnwrap(TriangleSolver.solve(TriangleGiven(A: 60, B: 60, C: 60)).first)
        XCTAssertEqual(solution.a, 1, accuracy: 1e-9)
        XCTAssertEqual(solution.b, 1, accuracy: 1e-9)
        XCTAssertEqual(solution.c, 1, accuracy: 1e-9)
    }

    func testSSAReturnsTwoSolutions() throws {
        let solutions = try TriangleSolver.solve(TriangleGiven(a: 10, b: 12, A: 30))
        XCTAssertEqual(solutions.count, 2)
        XCTAssertTrue(solutions.allSatisfy(\.isAmbiguous))
    }

    func testSASUsesObtuseSafePath() throws {
        let solution = try XCTUnwrap(TriangleSolver.solve(TriangleGiven(b: 3, c: 4, A: 90)).first)
        XCTAssertEqual(solution.a, 5, accuracy: 1e-9)
        XCTAssertEqual(solution.A, 90, accuracy: 1e-9)
    }

    func testTwoAnglesAndSide() throws {
        let solution = try XCTUnwrap(TriangleSolver.solve(TriangleGiven(c: 10, A: 30, B: 60)).first)
        XCTAssertEqual(solution.C, 90, accuracy: 1e-9)
        XCTAssertEqual(solution.a, 5, accuracy: 1e-9)
        XCTAssertEqual(solution.b, 5 * sqrt(3), accuracy: 1e-9)
    }

    func testRadianInput() throws {
        let angle = Double.pi / 3
        let solution = try XCTUnwrap(TriangleSolver.solve(TriangleGiven(A: angle, B: angle, C: angle), angleUnit: .radians).first)
        XCTAssertEqual(solution.A, 60, accuracy: 1e-9)
        XCTAssertEqual(solution.a, 1, accuracy: 1e-9)
    }

    func testInvalidSSSFails() {
        XCTAssertThrowsError(try TriangleSolver.solve(TriangleGiven(a: 1, b: 2, c: 3)))
    }

    func testPipeOffset() throws {
        let result = try SceneCalculator.calculate(mode: .pipe, first: 300, second: 45)
        XCTAssertEqual(result.run, 300, accuracy: 1e-9)
        XCTAssertEqual(result.length, 300 * sqrt(2), accuracy: 1e-9)
    }

    func testStairsUsesOneFewerTread() throws {
        let result = try SceneCalculator.stairs(run: 840, rise: 700, risers: 4)
        XCTAssertEqual(result.treads, 3)
        XCTAssertEqual(result.riserHeight, 175, accuracy: 1e-9)
        XCTAssertEqual(result.treadDepth, 280, accuracy: 1e-9)
    }

    func testStairDiagramUsesRiserCount() {
        let left = CGPoint(x: 0, y: 100)
        let right = CGPoint(x: 90, y: 100)
        let top = CGPoint(x: 90, y: 0)

        let fourRisers = SceneDiagramGeometry.points(risers: 4, left: left, right: right, top: top)
        let sixRisers = SceneDiagramGeometry.points(risers: 6, left: left, right: right, top: top)

        XCTAssertEqual(fourRisers.count, 8)
        XCTAssertEqual(sixRisers.count, 12)
        XCTAssertEqual(fourRisers.last, top)
        XCTAssertEqual(sixRisers.last, top)
    }

    func testSceneDiagramPlaceholderDataMatchesMiniProgram() {
        let pipe = SceneDiagramGeometry.placeholderResult(mode: .pipe)
        let drop = SceneDiagramGeometry.placeholderResult(mode: .drop)
        let angle = SceneDiagramGeometry.placeholderResult(mode: .angle)
        let stairs = SceneDiagramGeometry.placeholderResult(mode: .stairs)

        XCTAssertEqual(pipe.rise, 1_200, accuracy: 1e-9)
        XCTAssertEqual(pipe.angle, 45, accuracy: 1e-9)
        XCTAssertEqual(drop.run, 1_200, accuracy: 1e-9)
        XCTAssertEqual(drop.slope, 25, accuracy: 1e-9)
        XCTAssertEqual(angle.run, 1_200, accuracy: 1e-9)
        XCTAssertEqual(angle.angle, 20, accuracy: 1e-9)
        XCTAssertEqual(stairs.run, 1_200, accuracy: 1e-9)
        XCTAssertEqual(stairs.rise, 800, accuracy: 1e-9)
    }

    func testStairDiagramDoesNotFakeOverlyDenseSteps() {
        let left = CGPoint(x: 0, y: 100)
        let right = CGPoint(x: 90, y: 100)
        let top = CGPoint(x: 90, y: 0)

        XCTAssertTrue(SceneDiagramGeometry.points(risers: 101, left: left, right: right, top: top).isEmpty)
    }

    func testStairDiagramPreservesRunRiseRatio() {
        let endpoints = SceneDiagramGeometry.endpoints(size: CGSize(width: 400, height: 200), run: 840, rise: 700)
        let width = endpoints.right.x - endpoints.left.x
        let height = endpoints.left.y - endpoints.top.y

        XCTAssertEqual(width / height, 840.0 / 700.0, accuracy: 1e-9)
    }

    func testOtherSceneDiagramUsesCalculatedDimensions() throws {
        let result = try XCTUnwrap(SceneDiagramGeometry.result(mode: .angle, first: 1_000, second: 30))
        let endpoints = SceneDiagramGeometry.endpoints(size: CGSize(width: 400, height: 200), run: result.run, rise: result.rise)
        let width = endpoints.right.x - endpoints.left.x
        let height = endpoints.left.y - endpoints.top.y

        XCTAssertEqual(result.rise, 1_000 * tan(.pi / 6), accuracy: 1e-9)
        XCTAssertEqual(width / height, result.run / result.rise, accuracy: 1e-9)
    }

    func testLengthUnitConversion() {
        XCTAssertEqual(LengthUnit.mm.convert(1_250, to: .m), 1.25, accuracy: 1e-12)
        XCTAssertEqual(LengthUnit.m.convert(1.25, to: .cm), 125, accuracy: 1e-12)
    }

    func testNumericFormattingDoesNotGroupThousands() throws {
        for value in [1_000.0, 1_200, 8_000, 10_000, 1_234_567.125] {
            let text = value.formatted(maxDigits: 8)
            XCTAssertFalse(text.contains(","))
            XCTAssertEqual(try XCTUnwrap(NumericInput.double(text)), value, accuracy: 1e-9)
        }
        XCTAssertEqual(1_200.0.formatted(maxDigits: 8), "1200")
        XCTAssertEqual(1.2.formatted(maxDigits: 8), "1.2")
        XCTAssertEqual(1_442.22051.formatted(maxDigits: 4), "1442.2205")
    }

    @MainActor
    func testAllSceneExampleInputsMatchMiniProgramAcrossUnits() throws {
        let examples: [(SceneMode, String, String, Bool, String)] = [
            (.brace, "1200", "800", true, ""),
            (.drop, "8000", "2", false, ""),
            (.slope, "10000", "150", true, ""),
            (.angle, "1000", "15", false, ""),
            (.pipe, "300", "45", false, ""),
            (.stairs, "840", "700", true, "4"),
            (.wood, "1200", "800", true, "")
        ]
        for language in AppLanguage.allCases {
            for (mode, first, second, secondIsLength, risers) in examples {
                let config = ScenesView.config(for: mode, language: language)
                let millimetres = config.exampleInputs(unit: .mm)
                XCTAssertEqual(millimetres.first, first)
                XCTAssertEqual(millimetres.second, second)
                XCTAssertEqual(millimetres.risers, risers)
                XCTAssertEqual(config.secondIsLength, secondIsLength)
                for unit in LengthUnit.allCases {
                    let inputs = config.exampleInputs(unit: unit)
                    let parsedFirst = try XCTUnwrap(NumericInput.double(inputs.first))
                    let parsedSecond = try XCTUnwrap(NumericInput.double(inputs.second))
                    let originalFirst = try XCTUnwrap(Double(first))
                    let originalSecond = try XCTUnwrap(Double(second))
                    XCTAssertEqual(unit.convert(parsedFirst, to: .mm), originalFirst, accuracy: 1e-8)
                    XCTAssertEqual(secondIsLength ? unit.convert(parsedSecond, to: .mm) : parsedSecond, originalSecond, accuracy: 1e-8)
                    XCTAssertEqual(inputs.risers, risers)
                    let convertedBack = unit.convert(parsedFirst, to: .mm).formatted(maxDigits: 10)
                    XCTAssertEqual(convertedBack, first)
                    let result = try SceneCalculator.calculate(mode: mode, first: parsedFirst, second: parsedSecond)
                    let original = try SceneCalculator.calculate(mode: mode, first: originalFirst, second: originalSecond)
                    XCTAssertEqual(unit.convert(result.length, to: .mm), original.length, accuracy: 1e-7)
                    XCTAssertEqual(result.angle, original.angle, accuracy: 1e-9)
                }
            }
        }
    }

    func testTwoAnglesAutoFillThirdAngleInDegrees() {
        var fields = TriangleInputFields(A: "35", B: "65")

        XCTAssertEqual(fields.autoFillThirdAngle(angleUnit: .degrees), .filled(.C))
        XCTAssertEqual(fields.C, "80")
    }

    func testTwoAnglesAutoFillThirdAngleInRadians() throws {
        var fields = TriangleInputFields(A: "1", B: "0.5")

        XCTAssertEqual(fields.autoFillThirdAngle(angleUnit: .radians), .filled(.C))
        XCTAssertEqual(try XCTUnwrap(NumericInput.double(fields.C)), .pi - 1.5, accuracy: 1e-9)
    }

    func testThirdAngleDoesNotAutoFillWhenSideExists() {
        var fields = TriangleInputFields(a: "10", A: "35", B: "65")

        XCTAssertEqual(fields.autoFillThirdAngle(angleUnit: .degrees), .none)
        XCTAssertTrue(fields.C.isEmpty)
    }

    func testInvalidTwoAngleSumIsReported() {
        var fields = TriangleInputFields(A: "100", B: "80")

        XCTAssertEqual(fields.autoFillThirdAngle(angleUnit: .degrees), .invalid("两角之和需小于 180"))
        XCTAssertTrue(fields.C.isEmpty)
    }

    func testLocalizedNumericInput() {
        XCTAssertEqual(NumericInput.double("１２，５"), 12.5)
        XCTAssertEqual(NumericInput.integer("４"), 4)
    }

    @MainActor
    func testCalculationStepsFollowSSSMethod() throws {
        let given = TriangleGiven(a: 3, b: 4, c: 5)
        let solution = try XCTUnwrap(TriangleSolver.solve(given).first)
        let steps = TriangleCalculatorViewModel.buildSteps(given: given, solution: solution)

        XCTAssertEqual(steps.count, 4)
        XCTAssertTrue(steps[0].title.contains("SSS"))
        XCTAssertEqual(steps[1].formula, "cos A = (b² + c² − a²) / (2bc)")
        XCTAssertEqual(steps[3].formula, "C = 180° − A − B")
    }

    @MainActor
    func testCalculationStepsFollowSASMethod() throws {
        let given = TriangleGiven(b: 3, c: 4, A: 90)
        let solution = try XCTUnwrap(TriangleSolver.solve(given).first)
        let steps = TriangleCalculatorViewModel.buildSteps(given: given, solution: solution)

        XCTAssertTrue(steps[0].title.contains("SAS"))
        XCTAssertEqual(steps[1].formula, "a² = b² + c² − 2bc·cos A")
        XCTAssertTrue(steps[2].formula?.contains("cos B") == true)
    }

    @MainActor
    func testCalculationStepsFollowAASMethod() throws {
        let given = TriangleGiven(c: 10, A: 30, B: 60)
        let solution = try XCTUnwrap(TriangleSolver.solve(given).first)
        let steps = TriangleCalculatorViewModel.buildSteps(given: given, solution: solution)

        XCTAssertTrue(steps[0].title.contains("AAS"))
        XCTAssertEqual(steps[1].formula, "C = 180° − A − B")
        XCTAssertTrue(steps.contains { $0.formula == "a = c × sin A / sin C" })
    }

    @MainActor
    func testCalculationStepsFollowSSAAmbiguousSolution() throws {
        let given = TriangleGiven(a: 10, b: 12, A: 30)
        let solution = try XCTUnwrap(TriangleSolver.solve(given).last)
        let steps = TriangleCalculatorViewModel.buildSteps(given: given, solution: solution, language: .english)

        XCTAssertTrue(steps[0].title.contains("SSA"))
        XCTAssertTrue(steps[1].title.contains("Solution 2"))
        XCTAssertTrue(steps.contains { $0.formula == "sin B / b = sin A / a" })
    }

    @MainActor
    func testCalculationStepsFollowAAAMethod() throws {
        let given = TriangleGiven(A: 50, B: 60, C: 70)
        let solution = try XCTUnwrap(TriangleSolver.solve(given).first)
        let steps = TriangleCalculatorViewModel.buildSteps(given: given, solution: solution)

        XCTAssertTrue(steps[0].title.contains("AAA"))
        XCTAssertEqual(steps[1].formula, "c = 1")
    }

    @MainActor
    func testLanguagePreferencePersists() throws {
        let suiteName = "TriangleCalculatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = AppStore(defaults: defaults)
        firstStore.language = .english
        let restoredStore = AppStore(defaults: defaults)

        XCTAssertEqual(restoredStore.language, .english)
    }

    @MainActor
    func testDefaultSceneToolOrder() throws {
        let suiteName = "TriangleCalculatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppStore(defaults: defaults)

        XCTAssertEqual(store.sceneTools.map(\.id), [.stairs, .wood, .pipe, .slope, .brace])
    }

    @MainActor
    func testSubscriptionUnlockOpensUnderMoreTab() throws {
        let suiteName = "TriangleCalculatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppStore(defaults: defaults)

        store.openSubscription()

        XCTAssertEqual(store.selectedTab, 2)
        XCTAssertEqual(store.morePath, [.subscription])
    }

    @MainActor
    func testLegacyDefaultSceneOrderMigrates() throws {
        let suiteName = "TriangleCalculatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let originalStore = AppStore(defaults: defaults)
        originalStore.sceneTools = SceneID.allCases.map { SceneToolPreference(id: $0, isEnabled: true) }

        let migratedStore = AppStore(defaults: defaults)

        XCTAssertEqual(migratedStore.sceneTools.map(\.id), [.stairs, .wood, .pipe, .slope, .brace])
    }

    @MainActor
    func testAngleEditingAutoFillsAndSolvesAfterDebounce() async throws {
        let suiteName = "TriangleCalculatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppStore(defaults: defaults)
        let model = TriangleCalculatorViewModel()

        model.updateField(.A, value: "35", store: store)
        model.updateField(.B, value: "6", store: store)
        model.updateField(.B, value: "65", store: store)
        try await Task.sleep(for: .milliseconds(800))

        XCTAssertEqual(model.fields.C, "80")
        XCTAssertEqual(model.state, .success)
        XCTAssertEqual(model.selectedSolution?.C, 80)
    }

    @MainActor
    func testWritingSameFieldValueDoesNotRecalculate() throws {
        let suiteName = "TriangleCalculatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppStore(defaults: defaults)
        let model = TriangleCalculatorViewModel()
        model.fields = TriangleInputFields(a: "3", b: "4", c: "5")
        model.compute(store: store, save: false)
        let originalSteps = model.steps
        let originalSolution = model.selectedSolution

        model.updateField(.a, value: "3", store: store)

        XCTAssertEqual(model.state, .success)
        XCTAssertEqual(model.steps, originalSteps)
        XCTAssertEqual(model.selectedSolution, originalSolution)
    }
}
