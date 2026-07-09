import Foundation

enum TriviaDifficulty: String, CaseIterable, Identifiable, Codable {
    case mixed = "Mixed"
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var id: String { rawValue }
}

enum TriviaCategory: String, CaseIterable, Identifiable, Codable {
    case general
    case science
    case history
    case geography
    case entertainment
    case sports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .science: "Science"
        case .history: "History"
        case .geography: "Geography"
        case .entertainment: "Entertainment"
        case .sports: "Sports"
        }
    }

    static let defaultEnabled: [TriviaCategory] = Array(TriviaCategory.allCases)
}

struct TriviaQuestion: Identifiable, Hashable {
    let id: String
    let category: TriviaCategory
    let difficulty: TriviaDifficulty
    let prompt: String
    let answers: [String]
    let correctAnswer: String

    init(
        id: String,
        category: TriviaCategory,
        difficulty: TriviaDifficulty,
        prompt: String,
        answers: [String],
        correctAnswer: String
    ) {
        self.id = id
        self.category = category
        self.difficulty = difficulty
        self.prompt = prompt
        self.answers = answers
        self.correctAnswer = correctAnswer
    }
}
