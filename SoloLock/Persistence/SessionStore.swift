import Foundation

/// Simple JSON-on-disk session log. Single source of truth for History.
final class SessionStore {
    private let url: URL
    private let queue = DispatchQueue(label: "sololock.sessionstore", qos: .userInitiated)

    init(filename: String = "sessions.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent(filename)
    }

    func loadAll() -> [Session] {
        queue.sync {
            guard let data = try? Data(contentsOf: url) else { return [] }
            return (try? JSONDecoder().decode([Session].self, from: data)) ?? []
        }
    }

    /// Inserts or replaces by id, then persists. Latest first.
    func save(_ session: Session) {
        queue.sync {
            var all = (try? JSONDecoder().decode([Session].self, from: (try? Data(contentsOf: url)) ?? Data())) ?? []
            if let i = all.firstIndex(where: { $0.id == session.id }) {
                all[i] = session
            } else {
                all.insert(session, at: 0)
            }
            // Sort newest first.
            all.sort { $0.startedAt > $1.startedAt }
            if let data = try? JSONEncoder().encode(all) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    func delete(_ id: UUID) {
        queue.sync {
            var all = (try? JSONDecoder().decode([Session].self, from: (try? Data(contentsOf: url)) ?? Data())) ?? []
            all.removeAll { $0.id == id }
            if let data = try? JSONEncoder().encode(all) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    /// Aggregate stats for History header.
    struct Stats {
        var totalSessions: Int
        var totalSecondsHeld: TimeInterval
        var charityDollars: Int
        var emergencyUnlocks: Int
    }

    func stats(from sessions: [Session]) -> Stats {
        var s = Stats(totalSessions: 0, totalSecondsHeld: 0, charityDollars: 0, emergencyUnlocks: 0)
        for session in sessions {
            s.totalSessions += 1
            switch session.outcome {
            case .completed, .emergencyUnlock, .abandoned:
                s.totalSecondsHeld += session.heldSeconds
                if session.outcome != .completed { s.emergencyUnlocks += 1 }
            case .charityCharged:
                s.totalSecondsHeld += session.heldSeconds
                s.emergencyUnlocks += 1
                s.charityDollars += session.charity?.amountDollars ?? 0
            case .running:
                break
            }
        }
        return s
    }
}
