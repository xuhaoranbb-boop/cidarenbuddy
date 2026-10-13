import SwiftUI
import UIKit

struct SpellingPracticeView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var currentEntry: VocabularyEntry?
    @State private var answer = ""
    @State private var feedback: String?
    @State private var suggestions: [String] = []
    @State private var correctCount = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                if let currentEntry {
                    VStack(spacing: 12) {
                        Text("根据释义拼出英文")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(currentEntry.meaning)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        if !currentEntry.context.isEmpty && currentEntry.context != currentEntry.meaning {
                            Text(currentEntry.context)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22))

                    TextField("输入英文拼写", text: $answer)
                        .font(.title3.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .onSubmit(checkAnswer)

                    if let feedback {
                        VStack(spacing: 6) {
                            Text(feedback)
                                .font(.headline)
                                .foregroundStyle(feedback.hasPrefix("正确") ? .green : .orange)
                            if !suggestions.isEmpty {
                                Text("拼写建议：\(suggestions.joined(separator: " · "))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button(action: checkAnswer) {
                        Text("检查拼写")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color(red: 0.22, green: 0.36, blue: 0.30), in: RoundedRectangle(cornerRadius: 15))
                    }
                    .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    ContentUnavailableView(
                        "还没有练习词",
                        systemImage: "character.cursor.ibeam",
                        description: Text("先开始实时读屏，点识别到的英文单词加入拼写练习。")
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color(red: 0.96, green: 0.96, blue: 0.93))
            .navigationTitle("拼写练习")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("答对 \(correctCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear(perform: chooseNextEntry)
        }
    }

    private func checkAnswer() {
        guard let currentEntry else { return }
        let submitted = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submitted.isEmpty else { return }

        if submitted.caseInsensitiveCompare(currentEntry.word) == .orderedSame {
            feedback = "正确：\(currentEntry.word)"
            suggestions = []
            correctCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { chooseNextEntry() }
        } else {
            feedback = "再试一次"
            store.recordWrongAttempt(for: currentEntry.id)
            suggestions = spellingSuggestions(for: submitted)
        }
    }

    private func chooseNextEntry() {
        let candidates = store.entries
        guard !candidates.isEmpty else {
            currentEntry = nil
            return
        }
        let remaining = candidates.filter { $0.id != currentEntry?.id }
        currentEntry = (remaining.isEmpty ? candidates : remaining).randomElement()
        answer = ""
        feedback = nil
        suggestions = []
    }

    private func spellingSuggestions(for text: String) -> [String] {
        let checker = UITextChecker()
        let nsText = text as NSString
        let range = checker.rangeOfMisspelledWord(
            in: text,
            range: NSRange(location: 0, length: nsText.length),
            startingAt: 0,
            wrap: false,
            language: "en_US"
        )
        guard range.location != NSNotFound,
              let guesses = checker.guesses(forWordRange: range, in: text, language: "en_US") else { return [] }
        return Array(guesses.prefix(3))
    }
}
