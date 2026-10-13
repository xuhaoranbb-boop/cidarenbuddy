import SwiftUI
import Translation

struct LiveStudyView: View {
    @EnvironmentObject private var store: StudyStore
    @StateObject private var capture = LiveCaptureManager()
    @StateObject private var pip = TranslationPiPController()
    @State private var targetLanguage = "zh-Hans"
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var lookupConfiguration: TranslationSession.Configuration?
    @State private var translations: [String: String] = [:]
    @State private var wordMeanings: [String: String] = [:]
    @State private var selectedWord: String?
    @State private var selectedWordMeaning = "正在查词…"
    @State private var message: String?
    @State private var isTranslating = false

    private var translateToChinese: Bool { targetLanguage == "zh-Hans" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    introCard
                    directionPicker
                    captureControls
                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if capture.recognizedLines.isEmpty {
                        waitingCard
                    } else {
                        resultHeader
                        ForEach(Array(capture.recognizedLines.enumerated()), id: \.offset) { _, line in
                            recognizedCard(line)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.96, green: 0.96, blue: 0.93))
            .navigationTitle("词伴 · 实时")
            .translationTask(translationConfiguration) { session in
                await translateCurrentScreen(using: session)
            }
            .translationTask(lookupConfiguration) { session in
                guard let selectedWord else { return }
                do {
                    let response = try await session.translate(selectedWord)
                    wordMeanings[selectedWord] = response.targetText
                    selectedWordMeaning = response.targetText
                } catch {
                    selectedWordMeaning = "查词失败：\(error.localizedDescription)"
                }
            }
            .onChange(of: capture.recognizedLines) { _, _ in
                translations = [:]
                refreshTranslationConfiguration()
            }
            .onChange(of: targetLanguage) { _, _ in refreshTranslationConfiguration() }
            .overlay(alignment: .bottomTrailing) {
                SampleBufferLayerHost(displayLayer: pip.displayLayer)
                    .frame(width: 2, height: 2)
                    .opacity(0.01)
                    .allowsHitTesting(false)
            }
            .sheet(isPresented: Binding(
                get: { selectedWord != nil },
                set: { if !$0 { selectedWord = nil } }
            )) {
                wordSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("持续读取微信词达人屏幕", systemImage: "dot.radiowaves.left.and.right")
                .font(.title3.weight(.semibold))
            Text("点开始后，在系统窗口选择整个屏幕，再切回微信。画面帧只在内存中处理，不保存截图或录屏文件。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var directionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("翻译方向")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("翻译方向", selection: $targetLanguage) {
                Text("译成中文").tag("zh-Hans")
                Text("译成英文").tag("en")
            }
            .pickerStyle(.segmented)
        }
    }

    private var captureControls: some View {
        VStack(spacing: 10) {
            Button(action: capture.startPicker) {
                Label("开始实时读屏", systemImage: "record.circle")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(red: 0.22, green: 0.36, blue: 0.30), in: RoundedRectangle(cornerRadius: 15))
            }
            Button("停止屏幕共享", role: .destructive, action: capture.stop)
                .font(.subheadline.weight(.medium))
            HStack(spacing: 12) {
                Button(action: pip.start) {
                    Label("开启译文小窗", systemImage: "pip")
                }
                Button("关闭小窗", action: pip.stop)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                Circle().fill(capture.status.contains("共享中") ? .green : .secondary).frame(width: 8, height: 8)
                Text(capture.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            Text(pip.status)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var waitingCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("开始共享后，识别到的词句会显示在这里")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(26)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private var resultHeader: some View {
        HStack {
            Text("当前屏幕文字")
                .font(.title3.weight(.semibold))
            Spacer()
            if isTranslating { ProgressView().controlSize(.small) }
            Text("实时采帧 · OCR 耗时见状态栏")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func recognizedCard(_ line: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(line)
                .font(.body.weight(.medium))
                .textSelection(.enabled)
            if let translation = translations[line], !translation.isEmpty {
                Text(translation)
                    .font(.body)
                    .foregroundStyle(Color(red: 0.22, green: 0.36, blue: 0.30))
            }
            let words = englishWords(in: line)
            if !words.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(words, id: \.self) { word in
                            Button(word) { lookUp(word) }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.91, green: 0.94, blue: 0.90), in: Capsule())
                        }
                    }
                }
            } else if let translation = translations[line], !translation.isEmpty, !translateToChinese {
                Button {
                    store.add(word: translation, meaning: line, context: line)
                    message = "已加入拼写练习"
                } label: {
                    Label("练习拼写这句英文", systemImage: "plus.circle")
                        .font(.subheadline.weight(.medium))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private var wordSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedWord ?? "单词")
                .font(.largeTitle.weight(.semibold))
            Text(selectedWordMeaning)
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                guard let selectedWord else { return }
                store.add(word: selectedWord, meaning: selectedWordMeaning)
                self.selectedWord = nil
            } label: {
                Label("加入拼写练习", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(red: 0.22, green: 0.36, blue: 0.30), in: RoundedRectangle(cornerRadius: 15))
            }
        }
        .padding(24)
    }

    private func refreshTranslationConfiguration() {
        let sourceLines = capture.recognizedLines.filter { containsHan($0) == !translateToChinese }
        let targetLines = capture.recognizedLines.filter { containsHan($0) == translateToChinese }
        for line in targetLines { translations[line] = "原文已是目标语言" }
        for line in sourceLines { translations[line] = "" }
        let hasSourceLines = !sourceLines.isEmpty
        guard hasSourceLines else {
            message = "当前画面已是所选目标语言。"
            return
        }

        let source = Locale.Language(identifier: translateToChinese ? "en" : "zh-Hans")
        let target = Locale.Language(identifier: targetLanguage)
        if var configuration = translationConfiguration {
            configuration = TranslationSession.Configuration(source: source, target: target)
            configuration.invalidate()
            translationConfiguration = configuration
        } else {
            translationConfiguration = TranslationSession.Configuration(source: source, target: target)
        }
        if let latestSource = sourceLines.last {
            pip.update(original: latestSource, translated: translations[latestSource] ?? "正在翻译…")
        }
    }

    private func translateCurrentScreen(using session: TranslationSession) async {
        let sourceLines = capture.recognizedLines.filter { containsHan($0) == !translateToChinese }
        guard !sourceLines.isEmpty else {
            isTranslating = false
            return
        }
        isTranslating = true
        do {
            let requests = sourceLines.map { TranslationSession.Request(sourceText: $0, clientIdentifier: $0) }
            let responses = try await session.translations(from: requests)
            for response in responses {
                guard let source = response.clientIdentifier else { continue }
                translations[source] = response.targetText
            }
            if let latestSource = sourceLines.last {
                pip.update(original: latestSource, translated: translations[latestSource] ?? "")
            }
            message = "译文已更新，模型由 iPhone 本地运行。"
        } catch {
            message = "翻译暂不可用：\(error.localizedDescription)"
        }
        isTranslating = false
    }

    private func lookUp(_ word: String) {
        selectedWord = word
        selectedWordMeaning = wordMeanings[word] ?? "正在查词…"
        let configuration = TranslationSession.Configuration(
            source: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "zh-Hans")
        )
        if var current = lookupConfiguration {
            current = configuration
            current.invalidate()
            lookupConfiguration = current
        } else {
            lookupConfiguration = configuration
        }
    }

    private func englishWords(in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: "\\b[A-Za-z][A-Za-z'-]{1,}\\b") else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private func containsHan(_ text: String) -> Bool {
        text.range(of: "\\p{Han}", options: .regularExpression) != nil
    }
}
