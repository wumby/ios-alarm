import Foundation

struct TriviaService {
    static let shared = TriviaService()

    let questions: [TriviaQuestion]

    init(bundle: Bundle = .main) {
        let loadedQuestions = Self.loadQuestions(from: bundle)
        if loadedQuestions.isEmpty {
            Self.debugLog("No valid bundled trivia questions were loaded. Using emergency fallback question.")
            questions = [Self.fallbackQuestion]
        } else {
            questions = loadedQuestions
        }
    }

    func nextQuestion(
        categoryIDs: Set<String>,
        difficulty: TriviaDifficulty,
        excluding previousID: String? = nil
    ) -> TriviaQuestion {
        let selectedCategories = Set(categoryIDs.compactMap(TriviaCategory.init(rawValue:)))
        let matchingQuestions = questions.filter { question in
            (selectedCategories.isEmpty || selectedCategories.contains(question.category))
            && (difficulty == .mixed || question.difficulty == difficulty)
            && question.id != previousID
        }

        let question = Self.nextUnseenQuestion(from: matchingQuestions, allQuestions: questions, previousID: previousID)
        TriviaQuestionHistoryStore.shared.markSeen(question.id)
        return question
    }

    private static func nextUnseenQuestion(
        from matchingQuestions: [TriviaQuestion],
        allQuestions: [TriviaQuestion],
        previousID: String?
    ) -> TriviaQuestion {
        if let question = randomUnseenQuestion(from: matchingQuestions) {
            return question
        }

        if !matchingQuestions.isEmpty {
            TriviaQuestionHistoryStore.shared.clearSeenIDs(matchingQuestions.map(\.id))
            debugLog("Question pool exhausted for current filters. Resetting that pool.")
            return matchingQuestions.randomElement() ?? matchingQuestions[0]
        }

        let fallbackQuestions = allQuestions.filter { $0.id != previousID }
        if let question = randomUnseenQuestion(from: fallbackQuestions) {
            return question
        }

        if !fallbackQuestions.isEmpty {
            TriviaQuestionHistoryStore.shared.clearSeenIDs(fallbackQuestions.map(\.id))
            debugLog("Fallback question pool exhausted. Resetting fallback pool.")
            return fallbackQuestions.randomElement() ?? fallbackQuestions[0]
        }

        return allQuestions[0]
    }

    private static func randomUnseenQuestion(from questions: [TriviaQuestion]) -> TriviaQuestion? {
        let seenIDs = TriviaQuestionHistoryStore.shared.seenIDs
        return questions.filter { !seenIDs.contains($0.id) }.randomElement()
    }

    private static func loadQuestions(from bundle: Bundle) -> [TriviaQuestion] {
        guard let resourceURL = bundle.resourceURL else {
            debugLog("Bundle resource URL was unavailable.")
            return []
        }

        let fileURLs = triviaJSONFileURLs(in: resourceURL)
        guard !fileURLs.isEmpty else {
            debugLog("No trivia_*.json files found in bundle resources.")
            return []
        }

        var questions: [TriviaQuestion] = []
        var seenIDs = Set<String>()
        let decoder = JSONDecoder()

        for fileURL in fileURLs {
            do {
                let data = try Data(contentsOf: fileURL)
                let entries = try decoder.decode([BundledTriviaQuestion].self, from: data)
                var validCount = 0

                for entry in entries {
                    guard let question = entry.validatedQuestion(sourceFile: fileURL.lastPathComponent) else {
                        continue
                    }

                    guard !Self.isLowQualityGeneratedQuestion(question) else {
                        continue
                    }

                    guard seenIDs.insert(question.id).inserted else {
                        debugLog("Skipping duplicate trivia id '\(question.id)' in \(fileURL.lastPathComponent).")
                        continue
                    }

                    questions.append(question)
                    validCount += 1
                }

                debugLog("Loaded \(validCount) valid trivia questions from \(fileURL.lastPathComponent).")
            } catch {
                debugLog("Skipping malformed trivia file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        debugLog("Loaded \(questions.count) total bundled trivia questions.")
        return questions
    }

    private static func isLowQualityGeneratedQuestion(_ question: TriviaQuestion) -> Bool {
        guard question.id.contains("_wd_") else { return false }

        // The Wikidata science import is dominated by chemistry lookups and
        // placeholder element names. Keep Science focused on approachable,
        // interesting facts instead of periodic-table recall.
        if question.category == .science {
            return true
        }

        if question.difficulty == .hard {
            return true
        }

        return question.prompt.hasPrefix("What was ")
            || question.prompt.hasPrefix("Which country is ")
            || question.prompt.hasPrefix("Which sport is ")
            || question.prompt.hasPrefix("Which country did ")
            || question.prompt.hasPrefix("In what year was ")
            || question.prompt.hasPrefix("In what year did ")
    }

    private static func triviaJSONFileURLs(in resourceURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item -> URL? in
            guard let url = item as? URL else { return nil }
            let filename = url.deletingPathExtension().lastPathComponent
            guard url.pathExtension.lowercased() == "json", filename.hasPrefix("trivia_") else {
                return nil
            }
            return url
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static let fallbackQuestion = TriviaQuestion(
        id: "fallback_0001",
        category: .general,
        difficulty: .easy,
        prompt: "What is 2 + 2?",
        answers: ["3", "4", "5", "6"],
        correctAnswer: "4"
    )

    fileprivate static func debugLog(_ message: String) {
        #if DEBUG
        print("[TriviaService] \(message)")
        #endif
    }
}

private struct BundledTriviaQuestion: Decodable {
    let id: String
    let question: String
    let answers: [String]
    let correctIndex: Int
    let category: String
    let difficulty: String

    func validatedQuestion(sourceFile: String) -> TriviaQuestion? {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else {
            TriviaService.debugLog("Skipping question with empty id in \(sourceFile).")
            return nil
        }

        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            TriviaService.debugLog("Skipping \(trimmedID): empty question text.")
            return nil
        }

        guard answers.count == 4 else {
            TriviaService.debugLog("Skipping \(trimmedID): expected exactly 4 answers, found \(answers.count).")
            return nil
        }

        guard answers.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            TriviaService.debugLog("Skipping \(trimmedID): answers cannot be empty.")
            return nil
        }

        guard answers.indices.contains(correctIndex) else {
            TriviaService.debugLog("Skipping \(trimmedID): invalid correctIndex \(correctIndex).")
            return nil
        }

        guard let category = TriviaCategory(jsonValue: category) else {
            TriviaService.debugLog("Skipping \(trimmedID): invalid category '\(category)'.")
            return nil
        }

        guard let difficulty = TriviaDifficulty(jsonValue: difficulty), difficulty != .mixed else {
            TriviaService.debugLog("Skipping \(trimmedID): invalid difficulty '\(difficulty)'.")
            return nil
        }

        return TriviaQuestion(
            id: trimmedID,
            category: category,
            difficulty: difficulty,
            prompt: trimmedQuestion,
            answers: answers,
            correctAnswer: answers[correctIndex]
        )
    }
}

private extension TriviaCategory {
    init?(jsonValue: String) {
        let normalizedValue = jsonValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.init(rawValue: normalizedValue)
    }
}

private extension TriviaDifficulty {
    init?(jsonValue: String) {
        let normalizedValue = jsonValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let difficulty = Self.allCases.first(where: { $0.rawValue.lowercased() == normalizedValue }) else {
            return nil
        }
        self = difficulty
    }
}

private final class TriviaQuestionHistoryStore {
    static let shared = TriviaQuestionHistoryStore()

    private let seenQuestionIDsKey = "seenTriviaQuestionIDs"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var seenIDs: Set<String> {
        Set(defaults.stringArray(forKey: seenQuestionIDsKey) ?? [])
    }

    func markSeen(_ id: String) {
        var ids = seenIDs
        ids.insert(id)
        save(ids)
    }

    func clearSeenIDs(_ ids: [String]) {
        guard !ids.isEmpty else { return }

        var currentIDs = seenIDs
        currentIDs.subtract(ids)
        save(currentIDs)
    }

    private func save(_ ids: Set<String>) {
        defaults.set(ids.sorted(), forKey: seenQuestionIDsKey)
    }
}
