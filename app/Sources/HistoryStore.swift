import CryptoKit
import Foundation

struct HistoryClip: Identifiable, Codable, Equatable {
    var id: String
    var created: Date
    var mode: String
    var voice: String
    var title: String
    var fingerprint: String
    var duration: Double
    var chars: Int
}

struct HistoryIndex: Codable {
    var clips: [HistoryClip]
}

struct ClipLibrary {
    let dir: URL
    private let indexURL: URL
    private let fm = FileManager.default

    init(grokHome: URL) {
        dir = grokHome.appendingPathComponent("speak-history", isDirectory: true)
        indexURL = dir.appendingPathComponent("index.json")
    }

    func mp3URL(for id: String) -> URL { dir.appendingPathComponent("\(id).mp3") }
    func timestampsURL(for id: String) -> URL { dir.appendingPathComponent("\(id).json") }
    func sourceURL(for id: String) -> URL { dir.appendingPathComponent("\(id).source.txt") }

    func filesExist(_ clip: HistoryClip) -> Bool {
        fm.fileExists(atPath: mp3URL(for: clip.id).path)
    }

    func load() -> [HistoryClip] {
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let index = try? decoder.decode(HistoryIndex.self, from: data)
        else { return [] }
        return index.clips.filter { filesExist($0) }
    }

    func save(_ clips: [HistoryClip]) {
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try? encoder.encode(HistoryIndex(clips: clips))
        try? data?.write(to: indexURL, options: .atomic)
    }

    func add(
        source: String,
        spoken: String,
        mode: String,
        voice: String,
        fingerprint: String,
        duration: Double,
        mp3: URL,
        timestamps: URL
    ) throws -> HistoryClip {
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let id = Self.makeId()
        let destMp3 = mp3URL(for: id)
        let destTs = timestampsURL(for: id)
        let destSrc = sourceURL(for: id)
        if fm.fileExists(atPath: destMp3.path) { try fm.removeItem(at: destMp3) }
        try fm.copyItem(at: mp3, to: destMp3)
        if fm.fileExists(atPath: timestamps.path) {
            if fm.fileExists(atPath: destTs.path) { try fm.removeItem(at: destTs) }
            try fm.copyItem(at: timestamps, to: destTs)
        }
        try source.write(to: destSrc, atomically: true, encoding: .utf8)
        return HistoryClip(
            id: id,
            created: Date(),
            mode: mode,
            voice: voice,
            title: Self.title(from: spoken),
            fingerprint: fingerprint,
            duration: duration,
            chars: spoken.count
        )
    }

    func delete(_ clip: HistoryClip) {
        try? fm.removeItem(at: mp3URL(for: clip.id))
        try? fm.removeItem(at: timestampsURL(for: clip.id))
        try? fm.removeItem(at: sourceURL(for: clip.id))
    }

    func clip(matching fingerprint: String, in clips: [HistoryClip]) -> HistoryClip? {
        clips.first { $0.fingerprint == fingerprint && filesExist($0) }
    }

    static func fingerprint(mode: String, voice: String, text: String) -> String {
        let raw = "\(mode)|\(voice)|\(text)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func title(from spoken: String) -> String {
        let collapsed = spoken
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if collapsed.count <= 72 { return collapsed.isEmpty ? "Untitled clip" : collapsed }
        return String(collapsed.prefix(71)) + "…"
    }

    private static func makeId() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = fmt.string(from: Date())
        let suffix = UUID().uuidString.prefix(4).lowercased()
        return "\(stamp)-\(suffix)"
    }
}
