import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case simplifiedChinese
    case english

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: self == .simplifiedChinese ? "zh-Hans" : "en") }
    var title: String { self == .simplifiedChinese ? "简体中文" : "English" }

    func text(_ chinese: String, _ english: String) -> String {
        self == .simplifiedChinese ? chinese : english
    }
}

struct TriangleHistoryRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let given: TriangleGiven
    let angleUnit: AngleUnit
    let solution: TriangleSolution
    let solutionCount: Int
    let kind: TriangleKind

    var fingerprint: String {
        [given.pattern, given.summary(angleUnit: angleUnit), solution.a.formatted(maxDigits: 8), solution.b.formatted(maxDigits: 8), solution.c.formatted(maxDigits: 8)]
            .joined(separator: "|")
    }
}

struct SceneToolPreference: Identifiable, Codable, Equatable, Sendable {
    let id: SceneID
    var isEnabled: Bool
}

enum MoreRoute: Hashable {
    case subscription
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var history: [TriangleHistoryRecord] = []
    @Published var sceneEnabled: Bool { didSet { persistSettings() } }
    @Published var sceneTools: [SceneToolPreference] { didSet { persistSettings() } }
    @Published var language: AppLanguage { didSet { persistSettings() } }
    @Published var selectedTab = 0
    @Published var morePath: [MoreRoute] = []
    @Published var pendingRestore: TriangleHistoryRecord?

    private let defaults: UserDefaults
    private static let historyKey = "triangle_calculation_history_ios_v1"
    private static let sceneEnabledKey = "scene_page_enabled_ios_v1"
    private static let sceneToolsKey = "scene_tools_ios_v1"
    private static let languageKey = "app_language_ios_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.historyKey),
           let decoded = try? JSONDecoder().decode([TriangleHistoryRecord].self, from: data) {
            history = Array(decoded.prefix(20))
        }
        sceneEnabled = defaults.object(forKey: Self.sceneEnabledKey) as? Bool ?? true
        language = AppLanguage(rawValue: defaults.string(forKey: Self.languageKey) ?? "") ?? .simplifiedChinese
        if let data = defaults.data(forKey: Self.sceneToolsKey),
           let decoded = try? JSONDecoder().decode([SceneToolPreference].self, from: data),
           Set(decoded.map(\.id)) == Set(SceneID.allCases) {
            sceneTools = decoded == Self.legacyDefaultTools ? Self.defaultTools : decoded
        } else {
            sceneTools = Self.defaultTools
        }
    }

    static var defaultTools: [SceneToolPreference] {
        [.stairs, .wood, .pipe, .slope, .brace].map { SceneToolPreference(id: $0, isEnabled: true) }
    }

    private static var legacyDefaultTools: [SceneToolPreference] {
        SceneID.allCases.map { SceneToolPreference(id: $0, isEnabled: true) }
    }

    var enabledSceneTools: [SceneToolPreference] {
        guard sceneEnabled else { return [] }
        return sceneTools.filter(\.isEnabled)
    }

    func saveHistory(given: TriangleGiven, angleUnit: AngleUnit, solution: TriangleSolution, solutionCount: Int) {
        let record = TriangleHistoryRecord(
            id: UUID(), createdAt: Date(), given: given, angleUnit: angleUnit,
            solution: solution, solutionCount: solutionCount, kind: .detect(solution)
        )
        if history.first?.fingerprint == record.fingerprint { return }
        history.removeAll { $0.fingerprint == record.fingerprint }
        history.insert(record, at: 0)
        history = Array(history.prefix(20))
        persistHistory()
    }

    func deleteHistory(id: UUID) {
        history.removeAll { $0.id == id }
        persistHistory()
    }

    func clearHistory() {
        history = []
        defaults.removeObject(forKey: Self.historyKey)
    }

    func restore(_ record: TriangleHistoryRecord) {
        pendingRestore = record
        selectedTab = 0
    }

    func openSubscription() {
        morePath = [.subscription]
        selectedTab = 2
    }

    func restoreDefaultScenes() {
        sceneEnabled = true
        sceneTools = Self.defaultTools
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Self.historyKey)
    }

    private func persistSettings() {
        defaults.set(sceneEnabled, forKey: Self.sceneEnabledKey)
        defaults.set(language.rawValue, forKey: Self.languageKey)
        guard let data = try? JSONEncoder().encode(sceneTools) else { return }
        defaults.set(data, forKey: Self.sceneToolsKey)
    }
}
