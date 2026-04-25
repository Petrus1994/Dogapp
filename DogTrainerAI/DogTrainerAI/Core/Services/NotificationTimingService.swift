import Foundation
import UserNotifications

@MainActor
final class NotificationTimingService {

    static let shared = NotificationTimingService()
    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Schedule from routine

    /// Cancel existing routine notifications and reschedule from the new routine.
    func scheduleNotifications(for routine: DailyRoutine, dogName: String) async {
        let center = UNUserNotificationCenter.current()

        // Remove old routine notifications
        let existingIds = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix("routine_") }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: existingIds)

        let now = Date()

        for cycle in routine.cycles {
            // Only schedule future notifications
            guard cycle.suggestedTime > now.addingTimeInterval(60) else { continue }
            guard !cycle.isCompleted && !cycle.skipped else { continue }

            let content = UNMutableNotificationContent()
            content.title = notificationTitle(for: cycle.phase, dogName: dogName)
            content.body  = notificationBody(for: cycle.phase, dogName: dogName,
                                              duration: cycle.expectedDurationMinutes)
            content.sound = .default
            content.badge = 1

            let components = Calendar.current.dateComponents([.hour, .minute], from: cycle.suggestedTime)
            let trigger    = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request    = UNNotificationRequest(
                identifier: "routine_\(cycle.id)",
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }

        // Evening summary if routine is incomplete
        await scheduleEveningSummaryIfNeeded(routine: routine, dogName: dogName)
    }

    // MARK: - Toilet-specific nudge (called when feeding is logged)

    func scheduleToiletReminderAfterFeeding(dogName: String, delay: TimeInterval = 15 * 60) async {
        let content = UNMutableNotificationContent()
        content.title = "🌿 Toilet time for \(dogName)"
        content.body  = "It's been about 15 minutes since feeding — perfect time for a toilet break."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request  = UNNotificationRequest(identifier: "toilet_after_feeding", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Manual push (used by AppState when activity is overdue)

    func sendOverdueActivityNudge(dogName: String, phase: CyclePhase) async {
        let content = UNMutableNotificationContent()
        content.title = "⏰ \(phase.displayName) overdue"
        content.body  = "\(dogName) is waiting. \(phase.notificationMessage)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request  = UNNotificationRequest(identifier: "overdue_\(phase.rawValue)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Smart daily nudge (based on dog state)

    func scheduleSmartDailyNudge(dogState: DogState, dogName: String) async {
        let center = UNUserNotificationCenter.current()

        // Cancel any existing smart nudge
        center.removePendingNotificationRequests(withIdentifiers: ["smart_nudge"])

        let content = UNMutableNotificationContent()
        content.sound = .default

        if dogState.energyLevel > 0.7 {
            content.title = "🦮 \(dogName) has energy to burn"
            content.body  = "High energy right now — a walk or play session will keep \(dogName) calm and balanced today."
        } else if dogState.hungerLevel > 0.75 {
            content.title = "🍖 Feeding time for \(dogName)"
            content.body  = "It looks like \(dogName) hasn't been fed recently. Consistent meal timing builds calm food habits."
        } else if dogState.satisfaction < 0.3 {
            content.title = "🎾 \(dogName) needs some play"
            content.body  = "Low satisfaction today — even 10 minutes of focused play makes a real difference."
        } else if dogState.focusOnOwner < 0.3 {
            content.title = "🎯 Quick training win with \(dogName)"
            content.body  = "3–5 minutes of name recall or a simple command builds attention and connection."
        } else {
            return // dog is balanced — no nudge needed
        }

        // Schedule 2 hours from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2 * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: "smart_nudge", content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Sunday weekly summary notification

    func scheduleWeeklySummaryNotification(dogName: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly_summary"])

        let content = UNMutableNotificationContent()
        content.title = "📊 \(dogName)'s weekly summary is ready"
        content.body  = "See how your week went — activity stats, behavior trends, and what to focus on next."
        content.sound = .default

        // Next Sunday at 9am
        var components = DateComponents()
        components.weekday = 1  // Sunday
        components.hour    = 9
        components.minute  = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_summary", content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Cancel all

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Helpers

    private func notificationTitle(for phase: CyclePhase, dogName: String) -> String {
        switch phase {
        case .toilet:   return "🌿 \(dogName) needs a toilet break"
        case .physical: return "🦮 Time for \(dogName)'s walk"
        case .mental:   return "🧠 Training time with \(dogName)"
        case .feeding:  return "🍖 \(dogName)'s feeding time"
        case .sleep:    return "😴 Rest time for \(dogName)"
        }
    }

    private func notificationBody(for phase: CyclePhase, dogName: String, duration: Int) -> String {
        switch phase {
        case .toilet:
            return "Take \(dogName) outside now — ideally right away after waking up."
        case .physical:
            return "A \(duration)-minute walk or play session helps \(dogName) stay calm and balanced."
        case .mental:
            return "\(duration) minutes of training — short sessions work better than long ones."
        case .feeding:
            return "Ask \(dogName) to sit calmly before the bowl goes down."
        case .sleep:
            return "Let \(dogName) rest. Puppies need sleep to grow and consolidate learning."
        }
    }

    private func scheduleEveningSummaryIfNeeded(routine: DailyRoutine, dogName: String) async {
        guard routine.completionFraction < 0.6 else { return }

        let cal = Calendar.current
        guard let eightPM = cal.date(bySettingHour: 20, minute: 0, second: 0, of: routine.date),
              eightPM > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "📋 \(dogName)'s day is running low"
        content.body  = "Only \(Int(routine.completionFraction * 100))% of today's routine done. A quick activity session before bed helps \(dogName) sleep better."
        content.sound = .default

        let components = cal.dateComponents([.hour, .minute], from: eightPM)
        let trigger    = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request    = UNNotificationRequest(identifier: "evening_summary", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
