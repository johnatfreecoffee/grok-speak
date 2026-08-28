import SwiftUI
import UniformTypeIdentifiers

private let sky = Color(red: 14 / 255, green: 165 / 255, blue: 233 / 255)

struct ContentView: View {
    @StateObject private var model = SpeakModel()
    @FocusState private var editorFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            if model.showHistory {
                HistoryPane(model: model)
                    .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
                Divider()
            }
            VStack(spacing: 0) {
                header
                Divider()
                editor
                Divider()
                player
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            model.onAppear()
            editorFocused = true
        }
        .onDrop(of: [.fileURL, .plainText, .utf8PlainText], isTargeted: nil, perform: model.handleDrop)
        .onReceive(NotificationCenter.default.publisher(for: .speakNow)) { _ in
            Task { await model.speak() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .speakForce)) { _ in
            Task { await model.speak(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopNow)) { _ in
            model.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: .togglePlay)) { _ in
            model.togglePlay()
        }
        .onReceive(NotificationCenter.default.publisher(for: .skipBack)) { _ in
            model.skip(-model.skipSeconds)
        }
        .onReceive(NotificationCenter.default.publisher(for: .skipForward)) { _ in
            model.skip(model.skipSeconds)
        }
        .onReceive(NotificationCenter.default.publisher(for: .loadLastReply)) { _ in
            model.loadLastReply()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(sky)
                    .font(.title2)
                Text("Grok Speak")
                    .font(.title2.weight(.semibold))
                Text("Official Grok voice")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.showHistory.toggle()
                } label: {
                    Image(systemName: "clock")
                }
                .help("History")
                Picker("Voice", selection: $model.voiceId) {
                    ForEach(model.voices) { voice in
                        Text(voice.menuTitle).tag(voice.voiceId)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
            }

            Picker("Mode", selection: $model.mode) {
                ForEach(SpeakMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(model.showingReader
                 ? "Click a word to jump. Highlight follows playback."
                 : model.mode.hint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.showingReader, !model.spokenText.isEmpty {
                SpokenReaderView(
                    spoken: model.spokenText,
                    words: model.words,
                    activeIndex: model.activeWord,
                    onSelect: { model.jumpToWord($0) }
                )
                .padding(.horizontal, 8)
                .padding(.top, 4)
            } else {
                ZStack(alignment: .topLeading) {
                    if model.text.isEmpty {
                        Text("Paste anything to read aloud. Default is verbatim — it reads the text, it does not recap it.")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $model.text)
                        .font(.system(.body, design: .default))
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .focused($editorFocused)
                        .disabled(model.busy)
                }
            }

            HStack(spacing: 12) {
                Text(charLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(model.overLimit ? Color.orange : Color.secondary)
                if model.audioStale {
                    Text("Changed — Speak again to refresh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.showingReader {
                    Button("Edit source") { model.editSource() }
                        .disabled(model.busy)
                    Button("Copy") { model.copySpoken() }
                    Button("Clear") { model.clear() }
                        .disabled(model.busy)
                } else {
                    Button("Last reply") { model.loadLastReply() }
                        .disabled(model.busy)
                    Button("Paste") { model.pasteClipboard() }
                        .disabled(model.busy)
                    Button("Clear") { model.clear() }
                        .disabled(model.busy || model.text.isEmpty)
                }
            }
            .controlSize(.small)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var player: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(formatTime(model.current))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { model.current },
                        set: { model.current = $0 }
                    ),
                    in: 0 ... max(model.duration, 0.001),
                    onEditingChanged: { editing in
                        model.isSeeking = editing
                        if !editing {
                            model.seek(to: model.current)
                        }
                    }
                )
                .disabled(!model.hasAudio)
                .tint(sky)
                Text(formatTime(model.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            HStack(spacing: 16) {
                Button {
                    model.skip(-model.skipSeconds)
                } label: {
                    Label("-15s", systemImage: "gobackward.15")
                }
                .disabled(!model.hasAudio)

                Button {
                    model.togglePlay()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 36, height: 28)
                }
                .disabled(!model.hasAudio || model.busy)

                Button {
                    model.skip(model.skipSeconds)
                } label: {
                    Label("+15s", systemImage: "goforward.15")
                }
                .disabled(!model.hasAudio)

                Picker("Speed", selection: $model.rate) {
                    ForEach(model.rates, id: \.self) { rate in
                        Text(rate == 1 ? "1×" : String(format: "%g×", rate)).tag(rate)
                    }
                }
                .labelsHidden()
                .frame(width: 72)
                .disabled(!model.hasAudio)

                Spacer()

                if model.busy {
                    ProgressView()
                        .controlSize(.small)
                    Button("Stop") { model.stop() }
                        .keyboardShortcut(.escape, modifiers: [])
                } else {
                    Button {
                        Task { await model.speak() }
                    } label: {
                        Text("Speak")
                            .frame(minWidth: 72)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(sky)
                    .disabled(model.busy)
                    .keyboardShortcut(.return, modifiers: .command)

                    if model.hasAudio, !model.audioStale {
                        Button("New take") {
                            Task { await model.speak(force: true) }
                        }
                        .help("Fetch a new TTS clip even if this one is saved")
                        .disabled(model.busy)
                    }

                    if model.hasAudio || model.isPlaying {
                        Button("Stop") { model.stop() }
                    }
                }
            }
            .controlSize(.regular)

            HStack(alignment: .top, spacing: 8) {
                if let error = model.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                } else {
                    Text(model.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var charLabel: String {
        if model.showingReader {
            return "\(model.spokenText.count.formatted()) spoken · \(model.mode.label)"
        }
        let n = model.charCount.formatted()
        let cap = model.maxChars.formatted()
        return "\(n) / \(cap)"
    }
}

struct HistoryPane: View {
    @ObservedObject var model: SpeakModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                Button {
                    model.revealHistoryFolder()
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
                .help("Open saved clips folder")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if model.clips.isEmpty {
                Text("Saved clips land here after Speak. Play never makes a new call.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(14)
                Spacer()
            } else {
                List {
                    ForEach(model.clips) { clip in
                        HistoryRow(clip: clip, voiceName: model.voices.first(where: { $0.voiceId == clip.voice })?.name ?? clip.voice)
                            .listRowBackground(
                                clip.id == model.selectedClipId
                                    ? sky.opacity(0.16)
                                    : Color.clear
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { model.openClip(clip, autoplay: false) }
                            .contextMenu {
                                Button("Play") { model.openClip(clip, autoplay: true) }
                                Button("Show in Finder") { model.revealClip(clip) }
                                Divider()
                                Button("Delete", role: .destructive) { model.deleteClip(clip) }
                            }
                    }
                    .onDelete { indexSet in
                        for i in indexSet.sorted(by: >) {
                            model.deleteClip(model.clips[i])
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct HistoryRow: View {
    let clip: HistoryClip
    let voiceName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(clip.title.isEmpty ? "Untitled clip" : clip.title)
                .font(.callout)
                .lineLimit(2)
            Text("\(clip.mode.capitalized) · \(voiceName) · \(formatTime(clip.duration))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(clip.created.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
