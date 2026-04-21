import Foundation

/// Thread-safe in-memory response cache with per-entry TTL.
/// Used to avoid redundant AI calls for stable results (breed recs, plans).
final class ResponseCache<Key: Hashable, Value> {

    private struct Entry {
        let value: Value
        let storedAt: Date
    }

    private var store: [Key: Entry] = [:]
    private let lock = NSLock()

    func get(_ key: Key, ttl: TimeInterval) -> Value? {
        lock.lock(); defer { lock.unlock() }
        guard let entry = store[key] else { return nil }
        guard Date().timeIntervalSince(entry.storedAt) < ttl else {
            store.removeValue(forKey: key)
            return nil
        }
        return entry.value
    }

    func set(_ value: Value, for key: Key) {
        lock.lock(); defer { lock.unlock() }
        store[key] = Entry(value: value, storedAt: Date())
    }

    func invalidate(_ key: Key) {
        lock.lock(); defer { lock.unlock() }
        store.removeValue(forKey: key)
    }

    func invalidateAll() {
        lock.lock(); defer { lock.unlock() }
        store.removeAll()
    }
}
