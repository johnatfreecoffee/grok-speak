import AVFoundation
import AppKit
import Combine
import Foundation
import MediaPlayer

enum SpeakMode: String, CaseIterable, Identifiable {
    case verbatim, concise, casual, full
    var id: String { rawValue }
    var label: String {
        switch self {
        case .verbatim: "Verbatim"
        case .concise: "Concise"
        case .casual: "Casual"
        case .full: "Full"
        }
    }
    var hint: String {
        switch self {
        case .verbatim: "Read the text as written"
        case .concise: "Short spoken brief"
        case .casual: "Like telling a friend"
        case .full: "Whole thing as spoken English"
        }
    }
}

struct VoiceOption: Identifiable, Hashable {
    var id: String { voiceId }
    let voiceId: String
    let name: String
    let detail: String
    var menuTitle: String { "\(name) — \(detail)" }

    static let builtin: [VoiceOption] = [
        .init(voiceId: "rex", name: "Rex", detail: "Confident and clear"),
        .init(voiceId: "ara", name: "Ara", detail: "Warm and friendly"),
        .init(voiceId: "eve", name: "Eve", detail: "Energetic and upbeat"),
        .init(voiceId: "leo", name: "Leo", detail: "Authoritative and strong"),
        .init(voiceId: "sal", name: "Sal", detail: "Smooth and balanced"),
        .init(voiceId: "orion", name: "Orion", detail: "Rich, cinematic"),
        .init(voiceId: "luna", name: "Luna", detail: "Gentle, patient"),
        .init(voiceId: "iris", name: "Iris", detail: "Friendly, upbeat"),
        .init(voiceId: "altair", name: "Altair", detail: "Elegant, refined"),
        .init(voiceId: "atlas", name: "Atlas", detail: "Confident, commanding"),
        .init(voiceId: "aurora", name: "Aurora", detail: "Serene, steady"),
        .init(voiceId: "carina", name: "Carina", detail: "Soft, empathetic"),
        .init(voiceId: "castor", name: "Castor", detail: "Down-to-earth"),
        .init(voiceId: "celeste", name: "Celeste", detail: "Compassionate"),
        .init(voiceId: "cosmo", name: "Cosmo", detail: "Bright, curious"),
        .init(voiceId: "helios", name: "Helios", detail: "Upbeat, versatile"),
        .init(voiceId: "helix", name: "Helix", detail: "Bold, dynamic"),
        .init(voiceId: "kepler", name: "Kepler", detail: "Inventive"),
        .init(voiceId: "liora", name: "Liora", detail: "Calm, grounded"),
        .init(voiceId: "lumen", name: "Lumen", detail: "Warm, articulate"),
        .init(voiceId: "lux", name: "Lux", detail: "Grounded, calm"),
        .init(voiceId: "naksh", name: "Naksh", detail: "Warm, thoughtful"),
        .init(voiceId: "perseus", name: "Perseus", detail: "Strong, trustworthy"),
        .init(voiceId: "rigel", name: "Rigel", detail: "Precise, professional"),
        .init(voiceId: "sirius", name: "Sirius", detail: "Quick-witted"),
        .init(voiceId: "ursa", name: "Ursa", detail: "Friendly, steadfast"),
        .init(voiceId: "zagan", name: "Zagan", detail: "Powerful, dramatic"),
        .init(voiceId: "zenith", name: "Zenith", detail: "Sharp, focused"),
    ]
}

@MainActor
final class SpeakModel: ObservableObject {
    @Published var text = ""
    @Published var mode: SpeakMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "mode") }
    }
    @Published var voiceId: String {
        didSet { UserDefaults.standard.set(voiceId, forKey: "voice") }
    }
    @Published var rate: Double {
        didSet {
            UserDefaults.standard.set(rate, forKey: "rate")
            if isPlaying { player?.rate = Float(rate) }
        }
    }
    @Published var status = "Paste text, then Speak."
    @Published var error: String?
    @Published var busy = false
    @Published var isPlaying = false
    @Published var current: Double = 0
    @Published var duration: Double = 0
    @Published var hasAudio = false
    @Published var spokenText = ""
    @Published var words: [SpokenWord] = []
    @Published var activeWord: Int?
    @Published var showingReader = false
    @Published var isSeeking = false

    let voices = VoiceOption.builtin
    let rates: [Double] = [0.75, 1, 1.25, 1.5, 2]
    let skipSeconds: Double = 15
    let maxChars = 15_000

    var charCount: Int { text.count }
    var overLimit: Bool { charCount > maxChars }
    var audioStale: Bool { hasAudio && fingerprint != currentFingerprint }
    var canSpeak: Bool { !busy && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var currentVoiceName: String {
        voices.first(where: { $0.voiceId == voiceId })?.name ?? voiceId
    }

    private var currentFingerprint: String { "\(mode.rawValue)|\(voiceId)|\(text)" }
    private var fingerprint = ""
    private var player: AVPlayer?
    private var timeObs: Any?
    private var endObs: NSObjectProtocol?
    private var process: Process?
    private let grokHome: URL
    private let mp3URL: URL
    private let spokenURL: URL
    private let timestampsURL: URL
    private let lastReplyURL: URL

    init() {
        let defaults = UserDefaults.standard
        let savedMode = SpeakMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .verbatim
        mode = savedMode
        rate = defaults.object(forKey: "rate") as? Double ?? 1
        grokHome = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".grok")
        mp3URL = grokHome.appendingPathComponent("speak-app.mp3")
        spokenURL = grokHome.appendingPathComponent("speak-app.txt")
        timestampsURL = grokHome.appendingPathComponent("speak-app.json")
        lastReplyURL = grokHome.appendingPathComponent("last-reply.txt")
        let tomlVoice = Self.voiceFromToml(grokHome.appendingPathComponent("speak.toml"))
        voiceId = defaults.string(forKey: "voice") ?? tomlVoice ?? "rex"
        setupRemote()
    }

    deinit {
        process?.terminate()
    }

    func onAppear() {
        if FileManager.default.fileExists(atPath: mp3URL.path) {
            loadAudio()
            loadTimestamps()
            if !spokenText.isEmpty {
                showingReader = true
            }
            status = "Last clip ready — play, click a word, or skip."
        }
    }

    func loadLastReply() {
        guard FileManager.default.fileExists(atPath: lastReplyURL.path),
              let body = try? String(contentsOf: lastReplyURL, encoding: .utf8),
              !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            error = "No last Grok reply cached. Finish a TUI turn first."
            return
        }
        text = body
        showingReader = false
        error = nil
        status = "Loaded last Grok reply."
    }

    func pasteClipboard() {
        let paste = NSPasteboard.general.string(forType: .string) ?? ""
        guard !paste.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Clipboard is empty."
            return
        }
        text = paste
        showingReader = false
        error = nil
        status = "Pasted \(paste.count) characters."
    }

    func clear() {
        text = ""
        showingReader = false
        error = nil
        status = "Paste text, then Speak."
    }

    func editSource() {
        showingReader = false
        error = nil
        status = "Edit the source, then Speak."
    }

    func copySpoken() {
        let body = spokenText.isEmpty ? text : spokenText
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(body, forType: .string)
        status = "Copied spoken text."
    }

    func jumpToWord(_ word: SpokenWord) {
        guard hasAudio else { return }
        seek(to: word.start)
        if let idx = words.firstIndex(where: { $0.from == word.from && $0.start == word.start }) {
            activeWord = idx
        }
        if !isPlaying, !busy {
            player?.play()
            player?.rate = Float(rate)
            isPlaying = true
        }
        updateNowPlaying()
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                let url: URL? = {
                    if let data = item as? Data, let s = String(data: data, encoding: .utf8) {
                        return URL(string: s)
                    }
                    if let url = item as? URL { return url }
                    return nil
                }()
                guard let url, let body = try? String(contentsOf: url, encoding: .utf8) else { return }
                Task { @MainActor in
                    self.text = body
                    self.showingReader = false
                    self.error = nil
                    self.status = "Loaded \(url.lastPathComponent)."
                }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier("public.utf8-plain-text") {
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                guard let text else { return }
                Task { @MainActor in
                    self.text = text
                    self.showingReader = false
                    self.error = nil
                    self.status = "Dropped text."
                }
            }
            return true
        }
        return false
    }

    func speak() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            loadLastReply()
        }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        guard !busy else { return }

        let bin = grokSpeakBin()
        guard FileManager.default.isExecutableFile(atPath: bin.path) else {
            error = "Missing ~/.grok/bin/grok-speak — run ./scripts/install.sh"
            return
        }

        stopSynth()
        player?.pause()
        isPlaying = false
        busy = true
        error = nil
        status = mode == .verbatim ? "Fetching Grok voice…" : "Writing a \(mode.rawValue) spoken recap…"

        let tmp = grokHome.appendingPathComponent("speak-app-in.txt")
        do {
            try FileManager.default.createDirectory(at: grokHome, withIntermediateDirectories: true)
            try body.write(to: tmp, atomically: true, encoding: .utf8)
        } catch {
            self.error = "Could not write temp file."
            busy = false
            return
        }

        let proc = Process()
        proc.executableURL = bin
        proc.arguments = [
            "--synthesize",
            mode.rawValue,
            "--file", tmp.path,
            "--voice", voiceId,
            "--out", mp3URL.path,
            "--spoken-out", spokenURL.path,
            "--timestamps-out", timestampsURL.path,
        ]
        let errPipe = Pipe()
        let outPipe = Pipe()
        proc.standardError = errPipe
        proc.standardOutput = outPipe
        proc.standardInput = FileHandle.nullDevice
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "\(grokHome.appendingPathComponent("bin").path):/usr/bin:/bin:/usr/sbin:/sbin"
        env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        proc.environment = env

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            let line = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: \.isNewline)
                .last.map(String.init) ?? ""
            guard !line.isEmpty else { return }
            Task { @MainActor in
                self?.status = line
            }
        }

        proc.terminationHandler = { [weak self] finished in
            Task { @MainActor in
                self?.processFinished(finished)
            }
        }

        process = proc
        do {
            try proc.run()
        } catch {
            busy = false
            self.error = "Could not start grok-speak."
            process = nil
        }
    }

    func stop() {
        stopSynth()
        player?.pause()
        isPlaying = false
        if hasAudio {
            seek(to: 0)
        }
        status = "Stopped."
        updateNowPlaying()
        runGrokSpeak(["--stop"])
    }

    func togglePlay() {
        guard hasAudio, !busy else { return }
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            if duration > 0, current >= duration - 0.2 {
                seek(to: 0)
            }
            player?.play()
            player?.rate = Float(rate)
            isPlaying = true
        }
        updateNowPlaying()
    }

    func skip(_ delta: Double) {
        seek(to: current + delta)
    }

    func seek(to seconds: Double) {
        guard let player, duration > 0 else { return }
        let t = min(max(0, seconds), max(duration, 0))
        current = t
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        updateActiveWord(at: t)
        updateNowPlaying()
    }

    private func loadTimestamps() {
        if let data = try? Data(contentsOf: timestampsURL),
           let file = try? JSONDecoder().decode(TimestampFile.self, from: data)
        {
            spokenText = file.text
            words = file.words
            if spokenText.isEmpty {
                spokenText = (try? String(contentsOf: spokenURL, encoding: .utf8)) ?? ""
            }
            if words.isEmpty, !spokenText.isEmpty {
                words = Self.estimateWords(spokenText, duration: file.duration ?? duration)
            }
            return
        }
        spokenText = (try? String(contentsOf: spokenURL, encoding: .utf8)) ?? ""
        words = Self.estimateWords(spokenText, duration: duration)
    }

    private func updateActiveWord(at time: Double? = nil) {
        let t = time ?? current
        guard !words.isEmpty else {
            activeWord = nil
            return
        }
        var found = 0
        var lo = 0
        var hi = words.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if words[mid].start <= t {
                found = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        activeWord = found
    }

    private static func estimateWords(_ text: String, duration: Double) -> [SpokenWord] {
        let ns = text as NSString
        var words: [SpokenWord] = []
        let range = NSRange(location: 0, length: ns.length)
        ns.enumerateSubstrings(in: range, options: [.byWords, .localized]) { substring, wordRange, _, _ in
            guard let substring else { return }
            words.append(
                SpokenWord(
                    text: substring,
                    start: 0,
                    end: 0,
                    from: wordRange.location,
                    to: wordRange.location + wordRange.length
                )
            )
        }
        let dur = duration > 0 ? duration : max(Double(words.count) * 0.35, 1)
        guard !words.isEmpty else { return [] }
        let slice = dur / Double(words.count)
        for i in words.indices {
            words[i].start = slice * Double(i)
            words[i].end = slice * Double(i + 1)
        }
        return words
    }

    private func processFinished(_ proc: Process) {
        process = nil
        busy = false
        if proc.terminationStatus != 0 {
            if proc.terminationReason == .uncaughtSignal {
                status = "Stopped."
                return
            }
            let err = (try? String(contentsOf: spokenURL, encoding: .utf8)) ?? ""
            error = status.isEmpty ? "TTS failed (\(proc.terminationStatus))." : status
            if !err.isEmpty, error?.contains("TTS") == true {
                error = String(err.prefix(240))
            }
            return
        }
        fingerprint = currentFingerprint
        loadTimestamps()
        showingReader = !spokenText.isEmpty
        loadAudio()
        player?.play()
        player?.rate = Float(rate)
        isPlaying = true
        status = "\(mode.label) · \(currentVoiceName) · click a word to jump"
        updateNowPlaying()
    }

    private func stopSynth() {
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        busy = false
        runGrokSpeak(["--stop"])
    }

    private func loadAudio() {
        tearDownPlayer()
        guard FileManager.default.fileExists(atPath: mp3URL.path) else {
            hasAudio = false
            return
        }
        let item = AVPlayerItem(url: mp3URL)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.actionAtItemEnd = .pause
        player = newPlayer
        hasAudio = true
        current = 0
        duration = 0

        timeObs = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self, !self.isSeeking else { return }
                self.current = max(0, time.seconds)
                let d = self.player?.currentItem?.duration.seconds ?? 0
                if d.isFinite, d > 0 {
                    self.duration = d
                }
                self.isPlaying = self.player?.rate ?? 0 > 0
                self.updateActiveWord(at: self.current)
            }
        }

        endObs = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.current = self?.duration ?? 0
                self?.updateNowPlaying()
            }
        }
    }

    private func tearDownPlayer() {
        if let timeObs, let player {
            player.removeTimeObserver(timeObs)
        }
        timeObs = nil
        if let endObs {
            NotificationCenter.default.removeObserver(endObs)
        }
        endObs = nil
        player?.pause()
        player = nil
        isPlaying = false
    }

    private func grokSpeakBin() -> URL {
        grokHome.appendingPathComponent("bin/grok-speak")
    }

    private func runGrokSpeak(_ args: [String]) {
        let bin = grokSpeakBin()
        guard FileManager.default.isExecutableFile(atPath: bin.path) else { return }
        let proc = Process()
        proc.executableURL = bin
        proc.arguments = args
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        proc.standardInput = FileHandle.nullDevice
        do { try proc.run() } catch {}
    }

    private func setupRemote() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.skipBackwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: skipSeconds)]
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipSeconds)]
        center.changePlaybackPositionCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == false { self?.togglePlay() }
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == true { self?.togglePlay() }
            }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlay() }
            return .success
        }
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(self?.skipSeconds ?? 15) }
            return .success
        }
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(-(self?.skipSeconds ?? 15)) }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "Grok Speak",
            MPMediaItemPropertyArtist: currentVoiceName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: current,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: rate,
        ]
        if !spokenText.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = String(spokenText.prefix(80))
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private static func voiceFromToml(_ url: URL) -> String? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        for line in raw.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0] == "voice" {
                return parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return nil
    }
}

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds.rounded(.down))
    let m = total / 60
    let s = total % 60
    return String(format: "%d:%02d", m, s)
}
