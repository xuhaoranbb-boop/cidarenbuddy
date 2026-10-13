import SwiftUI

@main
struct CiDarenBuddyApp: App {
    @StateObject private var studyStore = StudyStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(studyStore)
                .tint(Color(red: 0.22, green: 0.36, blue: 0.30))
        }
    }
}

private struct ContentView: View {
    var body: some View {
        TabView {
            LiveStudyView()
                .tabItem { Label("实时识词", systemImage: "dot.radiowaves.left.and.right") }

            VocabularyView()
                .tabItem { Label("生词本", systemImage: "books.vertical") }

            SpellingPracticeView()
                .tabItem { Label("拼写", systemImage: "character.cursor.ibeam") }
        }
    }
}
