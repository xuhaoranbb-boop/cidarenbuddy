import SwiftUI

struct VocabularyView: View {
    @EnvironmentObject private var store: StudyStore

    var body: some View {
        NavigationStack {
            Group {
                if store.entries.isEmpty {
                    ContentUnavailableView(
                        "生词本还是空的",
                        systemImage: "books.vertical",
                        description: Text("在“识词”页点选英文单词，再加入拼写练习。")
                    )
                } else {
                    List {
                        ForEach(store.entries) { entry in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.word)
                                    .font(.headline)
                                Text(entry.meaning)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if !entry.context.isEmpty && entry.context != entry.meaning {
                                    Text(entry.context)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { offsets in
                            for index in offsets { store.remove(store.entries[index]) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("生词本 · \(store.entries.count)")
            .toolbar { EditButton() }
        }
    }
}
