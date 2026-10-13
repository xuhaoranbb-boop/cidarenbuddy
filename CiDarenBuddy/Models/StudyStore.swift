import Foundation
import Combine

struct VocabularyEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var word: String
    var meaning: String
    var context: String
    var addedAt: Date = Date()
    var wrongAttempts: Int = 0
}

@MainActor
final class StudyStore: ObservableObject {
    @Published private(set) var entries: [VocabularyEntry] = []

    private let storageKey = "cidarenbuddy.vocabulary.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let savedEntries = try? JSONDecoder().decode([VocabularyEntry].self, from: data) else {
            return
        }
        entries = savedEntries
    }

    func add(word: String, meaning: String, context: String = "") {
        let cleanedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedWord.isEmpty else { return }

        if let index = entries.firstIndex(where: { $0.word.caseInsensitiveCompare(cleanedWord) == .orderedSame }) {
            entries[index].meaning = meaning
            if !context.isEmpty { entries[index].context = context }
        } else {
            entries.insert(VocabularyEntry(word: cleanedWord, meaning: meaning, context: context), at: 0)
        }
        persist()
    }

    func recordWrongAttempt(for id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].wrongAttempts += 1
        persist()
    }

    func remove(_ entry: VocabularyEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
