import Foundation

/// Persistent, retry-capable queue for backend sync operations.
/// Items survive app restarts. Failed items are retried with exponential backoff.
/// Max 3 retries per item — after that the item is dropped with a debug log.
final class SyncQueue {
    static let shared = SyncQueue()

    private let defaults  = UserDefaults.standard
    private let storageKey = "sync_queue_v1"
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 5   // seconds

    private var flushTask: Task<Void, Never>?

    private init() {
        // Auto-flush on init for items that survived a previous session
        scheduleFlush(after: 2)
    }

    // MARK: - Enqueue

    func enqueue(_ item: SyncItem) {
        var queue = load()
        queue.append(item)
        save(queue)
        scheduleFlush(after: 0.5)
    }

    // MARK: - Flush

    private func scheduleFlush(after delay: TimeInterval) {
        flushTask?.cancel()
        flushTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await flush()
        }
    }

    private func flush() async {
        var queue = load()
        guard !queue.isEmpty else { return }

        var remaining: [SyncItem] = []

        for var item in queue {
            // Skip items still in backoff window
            if let nextRetry = item.nextRetryAt, nextRetry > Date() {
                remaining.append(item)
                continue
            }

            do {
                try await item.execute()
                // Success — item is dropped
                #if DEBUG
                print("[SyncQueue] ✅ \(item.tag)")
                #endif
            } catch {
                item.retryCount += 1
                #if DEBUG
                print("[SyncQueue] ⚠️ \(item.tag) failed (attempt \(item.retryCount)): \(error.localizedDescription)")
                #endif

                if item.retryCount < maxRetries {
                    let backoff = baseDelay * pow(2.0, Double(item.retryCount - 1))
                    item.nextRetryAt = Date().addingTimeInterval(backoff)
                    remaining.append(item)
                } else {
                    #if DEBUG
                    print("[SyncQueue] 🗑 \(item.tag) dropped after \(maxRetries) attempts.")
                    #endif
                }
            }
        }

        save(remaining)

        // If items remain, schedule another flush for the soonest retry
        if let soonest = remaining.compactMap({ $0.nextRetryAt }).min() {
            let delay = max(soonest.timeIntervalSinceNow, 1)
            scheduleFlush(after: delay)
        }
    }

    // MARK: - Persistence

    private func load() -> [SyncItem] {
        guard let data = defaults.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([SyncItem].self, from: data)
        else { return [] }
        return items
    }

    private func save(_ items: [SyncItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

// MARK: - SyncItem

struct SyncItem: Codable, Identifiable {
    let id: String
    let tag: String         // human-readable label for debug logs
    let payload: Data       // encoded request body
    let endpoint: String    // path relative to base URL
    let method: String
    var retryCount: Int     = 0
    var nextRetryAt: Date?
    var createdAt: Date     = Date()

    func execute() async throws {
        try await APIClient.shared.sendRaw(path: endpoint, method: method, body: payload)
    }
}

// MARK: - APIClient raw send extension

extension APIClient {
    /// Sends a pre-encoded body (Data) to the given path. Used by SyncQueue.
    func sendRaw(path: String, method: String, body: Data) async throws {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod  = method
        req.httpBody    = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = SessionManager.shared.getAccessToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
    }
}
