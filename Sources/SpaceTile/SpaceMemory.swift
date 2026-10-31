import Foundation

struct SpaceProfile: Codable, Identifiable {
    var id: String { "\(displayResolution)_\(apps.joined(separator: "+"))" }
    var apps: [String]
    var displayResolution: String
    var preferredLayout: String // "masterStack", "sideBySide", "terminalFocus", "custom"
    var learnedMasterRatio: Double?
    var observationsCount: Int
    var lastObserved: Date
}

class SpaceMemory {
    static let shared = SpaceMemory()

    private(set) var profiles: [SpaceProfile] = []

    static var storageURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/spacetile/space_memory.json")
    }

    init() {
        load()
    }

    func load() {
        let url = SpaceMemory.storageURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            profiles = try JSONDecoder().decode([SpaceProfile].self, from: data)
        } catch {
            print("[\u{001B}[33mSpaceMemory\u{001B}[0m] Fehler beim Laden: \(error)")
        }
    }

    func save() {
        let url = SpaceMemory.storageURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(profiles) {
            try? data.write(to: url)
        }
    }

    func findProfile(apps: [String], resolution: String) -> SpaceProfile? {
        let sorted = apps.sorted()
        return profiles.first { p in
            p.displayResolution == resolution && p.apps.sorted() == sorted
        }
    }

    func recordObservation(apps: [String], resolution: String, observedMasterRatio: Double, preferredLayout: String? = nil) {
        let sorted = apps.sorted()
        let layout = preferredLayout ?? (abs(observedMasterRatio - 0.5) < 0.06 ? "sideBySide" : "masterStack")

        if let idx = profiles.firstIndex(where: { $0.displayResolution == resolution && $0.apps.sorted() == sorted }) {
            var existing = profiles[idx]
            let oldRatio = existing.learnedMasterRatio ?? observedMasterRatio
            // Exponential moving average for smooth adaptation
            existing.learnedMasterRatio = (oldRatio * 0.7) + (observedMasterRatio * 0.3)
            existing.observationsCount += 1
            existing.lastObserved = Date()
            if let p = preferredLayout { existing.preferredLayout = p }
            profiles[idx] = existing
        } else {
            let newProf = SpaceProfile(
                apps: sorted,
                displayResolution: resolution,
                preferredLayout: layout,
                learnedMasterRatio: observedMasterRatio,
                observationsCount: 1,
                lastObserved: Date()
            )
            profiles.append(newProf)
        }
        save()
    }

    func clear() {
        profiles.removeAll()
        save()
    }
}
