import SwiftUI

/// Layout raiz: sidebar · conteúdo · coluna de stats.
struct NotetakerShell: View {
    let model: MeetingSession

    @State private var selection: NavSection = .dictation
    @State private var settings = AppSettings()
    @State private var hotkey = GlobalHotkey(id: 1)
    @State private var gesture = DictationGesture()
    @State private var dictation = DictationSession()
    @State private var files = FileTranscriptionModel()
    @State private var snippets = SnippetStore()
    @State private var isSidebarCollapsed = false
    @State private var meetings: [Meeting] = []
    @State private var meetingStartedAt: Date?
    @State private var elapsed: TimeInterval = 0
    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection, isCollapsed: $isSidebarCollapsed)

            HStack(alignment: .top, spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if selection == .notetaker, !meetings.isEmpty, !model.phase.isRunning {
                    StatsRailView(stats: UsageStats(meetings: meetings))
                        .padding(.top, 30)
                        .padding(.trailing, 30)
                }
            }
            .background(Theme.canvas)
        }
        .id(settings.localeIdentifier)
        .frame(minWidth: 1_060, minHeight: 700)
        .background(Theme.canvas)
        .onAppear {
            registerHotkeys()
            gesture.onStart = startDictation
            gesture.onFinish = finishDictation
            dictation.onFinish = handleDictationOutcome
            dictation.onFailure = handleDictationFailure
        }
        .onChange(of: settings.hotkey) { _, _ in registerHotkeys() }
        .onChange(of: HotkeyCapture.shared.isCapturing) { _, isCapturing in
            isCapturing ? hotkey.unregister() : registerHotkeys()
        }
        .onChange(of: model.phase) { _, phase in
            guard case .failed = phase else { return }
            setRecording(false)
            meetingStartedAt = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .tagarelaNavigate)) { note in
            if let target = note.object as? NavSection {
                selection = target
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tagarelaToggleDictation)) { _ in
            toggleDictation()
        }
        .task(id: meetingStartedAt) {
            guard let startedAt = meetingStartedAt else { return }
            while !Task.isCancelled {
                elapsed = Date().timeIntervalSince(startedAt)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .dictation:
            DictationView(
                session: dictation,
                hotkey: settings.hotkey,
                onToggle: toggleDictation
            )
        case .notetaker:
            MeetingFeedView(
                days: MeetingDay.group(meetings),
                model: model,
                elapsed: elapsed,
                capturesSystemAudio: settings.captureSystemAudio,
                onStartMeeting: toggleMeeting,
                onUseMicrophoneOnly: {
                    settings.captureSystemAudio = false
                    toggleMeeting()
                }
            )
        case .files:
            FileTranscriptionView(
                model: files,
                onChooseFile: {
                    files.chooseFile(
                        localeIdentifier: settings.localeIdentifier,
                        mode: settings.recognitionMode
                    )
                },
                onDrop: { url in
                    files.transcribe(
                        url: url,
                        localeIdentifier: settings.localeIdentifier,
                        mode: settings.recognitionMode
                    )
                }
            )
        case .dictionary:
            SnippetsView(store: snippets)
        case .settings:
            SettingsView(settings: settings)
        }
    }

    private func handleDictationFailure(_ message: String) {
        setRecording(false)
        NotificationCenter.default.post(name: .tagarelaWarning, object: message)
        playFeedback(.warning)
    }

    private func handleDictationOutcome(_ outcome: DictationOutcome) {
        // Sem campo de texto em foco não há onde colar: o texto vai pra área de
        // transferência, e o som de aviso diz que ele não foi colado.
        if outcome.needsCopy {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(outcome.text, forType: .string)
            playFeedback(.warning)
        } else if !outcome.text.isEmpty {
            playFeedback(.finish)
        }
    }

    private func registerHotkeys() {
        if settings.hotkey.isFunctionKey { GlobeKeyAction.disableIfNeeded() }

        guard !HotkeyCapture.shared.isCapturing else { return }

        hotkey.register(
            settings.hotkey,
            onPress: { guard !model.phase.isRunning else { return }; gesture.keyDown() },
            onRelease: { gesture.keyUp() }
        )
    }

    /// O botão Falar e o menu da barra entram por aqui; o gesto precisa saber
    /// para não achar que ainda está gravando no próximo toque da tecla.
    private func toggleDictation() {
        guard !model.phase.isRunning else { return }
        gesture.reset()
        dictation.isRunning ? finishDictation() : startDictation()
    }

    private func startDictation() {
        dictation.start(
            localeIdentifier: settings.localeIdentifier,
            mode: settings.recognitionMode,
            inputDeviceUID: settings.inputDeviceUID,
            contextualTerms: SpokenTerms.all(with: snippets.snippets.map(\.expansion)),
            formatAsMarkdown: settings.formatAsMarkdown,
            polishTerms: settings.polishTerms,
            softenLanguage: settings.softenLanguage,
            expand: { snippets.expand($0) }
        )
        setRecording(true)
        playFeedback(.start)
    }

    private func finishDictation() {
        dictation.finish()
        setRecording(false)
    }

    private func setRecording(_ isRecording: Bool) {
        NotificationCenter.default.post(name: .tagarelaRecordingChanged, object: isRecording)
    }

    private func playFeedback(_ kind: Feedback.Kind) {
        Feedback.play(
            kind,
            sound: settings.soundFeedback,
            haptic: settings.hapticFeedback
        )
    }

    private func toggleMeeting() {
        if model.phase.isRunning {
            finishMeeting()
        } else {
            model.localeIdentifier = settings.localeIdentifier
            model.recognitionMode = settings.recognitionMode
            model.inputDeviceUID = settings.inputDeviceUID
            if settings.captureSystemAudio {
                model.startCall()
            } else {
                model.startMicrophone()
            }
            meetingStartedAt = Date()
            elapsed = 0
            setRecording(true)
        }
    }

    private func finishMeeting() {
        let startedAt = meetingStartedAt ?? Date()
        let duration = Date().timeIntervalSince(startedAt)
        let you = model.youTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let others = model.othersTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

        model.stop()
        setRecording(false)
        meetingStartedAt = nil
        elapsed = 0
        guard !you.isEmpty || !others.isEmpty else { return }

        let excerpt = [you, others].first { !$0.isEmpty } ?? ""
        meetings.insert(
            Meeting(
                title: t(
                    "Reunião de \(Meeting.titleFormatter.string(from: startedAt))",
                    "Meeting at \(Meeting.titleFormatter.string(from: startedAt))"
                ),
                startedAt: startedAt,
                duration: duration,
                participants: others.isEmpty ? 1 : 2,
                excerpt: excerpt,
                wordCount: (you + " " + others).split(separator: " ").count
            ),
            at: 0
        )
    }
}
