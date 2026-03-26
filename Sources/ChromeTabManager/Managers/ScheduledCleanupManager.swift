import Foundation
import UserNotifications

/// Scheduled cleanup configuration
struct ScheduledCleanup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var scheduleType: ScheduleType
    var lastRunAt: Date?
    var nextRunAt: Date?
    
    enum ScheduleType: Codable, Equatable {
        case daily(hour: Int, minute: Int)           // Every day at specific time
        case weekly(weekday: Int, hour: Int, minute: Int)  // Weekly on specific day
        case interval(hours: Int)                    // Every N hours
        
        var description: String {
            switch self {
            case .daily(let hour, let minute):
                return String(format: "Daily at %02d:%02d", hour, minute)
            case .weekly(let weekday, let hour, let minute):
                let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                return String(format: "Every %@ at %02d:%02d", days[weekday], hour, minute)
            case .interval(let hours):
                return "Every \(hours) hours"
            }
        }
        
        func nextRunDate(from date: Date = Date()) -> Date {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            
            switch self {
            case .daily(let hour, let minute):
                components.hour = hour
                components.minute = minute
                components.second = 0
                
                if let nextDate = calendar.date(from: components), nextDate <= date {
                    return calendar.date(byAdding: .day, value: 1, to: nextDate) ?? date.addingTimeInterval(86400)
                }
                return calendar.date(from: components) ?? date.addingTimeInterval(86400)
                
            case .weekly(let weekday, let hour, let minute):
                components.hour = hour
                components.minute = minute
                components.second = 0
                components.weekday = weekday + 1 // Calendar uses 1-7 for Sun-Sat
                
                if let nextDate = calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime) {
                    return nextDate
                }
                return date.addingTimeInterval(604800) // 1 week fallback
                
            case .interval(let hours):
                return date.addingTimeInterval(TimeInterval(hours * 3600))
            }
        }
    }
    
    init(id: UUID = UUID(), name: String, isEnabled: Bool = true, scheduleType: ScheduleType) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.scheduleType = scheduleType
        self.nextRunAt = scheduleType.nextRunDate()
    }
}

/// Manages scheduled cleanup with background reminders
@MainActor
class ScheduledCleanupManager: ObservableObject {
    static let shared = ScheduledCleanupManager()
    
    @Published var schedules: [ScheduledCleanup] = []
    @Published var isNotificationsAuthorized = false
    
    private let userDefaults = UserDefaults.standard
    private let schedulesKey = "scheduledCleanups"
    nonisolated(unsafe) private var timer: Timer?
    
    private init() {
        loadSchedules()
        setupTimer()
        requestNotificationAuthorization()
    }
    
    private func loadSchedules() {
        if let data = userDefaults.data(forKey: schedulesKey),
           let decoded = try? JSONDecoder().decode([ScheduledCleanup].self, from: data) {
            schedules = decoded
        }
    }
    
    private func saveSchedules() {
        if let encoded = try? JSONEncoder().encode(schedules) {
            userDefaults.set(encoded, forKey: schedulesKey)
        }
    }
    
    private func setupTimer() {
        // Check every minute for scheduled cleanups
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkScheduledCleanups()
            }
        }
    }
    
    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.isNotificationsAuthorized = granted
            }
        }
    }
    
    private func checkScheduledCleanups() async {
        let now = Date()
        _ = Calendar.current
        
        for index in schedules.indices where schedules[index].isEnabled {
            if let nextRun = schedules[index].nextRunAt,
               nextRun <= now {
                await performScheduledCleanup(schedule: schedules[index])
                
                // Update next run time
                schedules[index].lastRunAt = now
                schedules[index].nextRunAt = schedules[index].scheduleType.nextRunDate(from: now)
                saveSchedules()
            }
        }
    }
    
    private func performScheduledCleanup(schedule: ScheduledCleanup) async {
        guard AutoCleanupManager.shared.isEnabled else {
            await sendNotification(
                title: "Scheduled Cleanup Skipped",
                body: "Auto-cleanup is disabled. Enable it in Preferences to run scheduled cleanups."
            )
            return
        }
        
        await AutoCleanupManager.shared.performCleanupCheck()
        
        let cleanedCount = AutoCleanupManager.shared.lastCleanedCount
        if cleanedCount > 0 {
            await sendNotification(
                title: "Scheduled Cleanup Complete",
                body: "Closed \(cleanedCount) tab\(cleanedCount == 1 ? "" : "s") automatically."
            )
        }
    }
    
    private func sendNotification(title: String, body: String) async {
        guard isNotificationsAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Public API
    
    func addSchedule(_ schedule: ScheduledCleanup) {
        schedules.append(schedule)
        saveSchedules()
        scheduleNotification(for: schedule)
    }
    
    func removeSchedule(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        schedules.removeAll { $0.id == id }
        saveSchedules()
    }
    
    func updateSchedule(_ schedule: ScheduledCleanup) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
            saveSchedules()
            scheduleNotification(for: schedule)
        }
    }
    
    func toggleSchedule(id: UUID) {
        if let index = schedules.firstIndex(where: { $0.id == id }) {
            schedules[index].isEnabled.toggle()
            saveSchedules()
            
            if schedules[index].isEnabled {
                scheduleNotification(for: schedules[index])
            } else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
            }
        }
    }
    
    private func scheduleNotification(for schedule: ScheduledCleanup) {
        guard isNotificationsAuthorized, schedule.isEnabled, let nextRun = schedule.nextRunAt else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Tab Cleanup Scheduled"
        content.body = "\(schedule.name) will run at \(formatTime(nextRun))"
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextRun)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: schedule.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    /// Creates default schedules for new users
    func createDefaultSchedules() {
        guard schedules.isEmpty else { return }
        
        // Daily cleanup at 9 AM
        let dailyCleanup = ScheduledCleanup(
            name: "Daily Morning Cleanup",
            scheduleType: .daily(hour: 9, minute: 0)
        )
        
        // Weekly cleanup on Sunday at 10 AM
        let weeklyCleanup = ScheduledCleanup(
            name: "Weekly Deep Clean",
            scheduleType: .weekly(weekday: 0, hour: 10, minute: 0)
        )
        
        schedules = [dailyCleanup, weeklyCleanup]
        saveSchedules()
    }
}

// MARK: - Defaults Keys

extension DefaultsKeys {
    static let scheduledCleanups = "scheduledCleanups"
}
