import Foundation
import UserNotifications
import Combine

/// Manages notifications for time spent on websites
@MainActor
final class TabTimeNotificationManager: NSObject, ObservableObject {
    static let shared = TabTimeNotificationManager()
    
    // MARK: - Published State
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: DefaultsKeys.notificationsEnabled)
            if isEnabled {
                requestAuthorization()
            } else {
                stopMonitoring()
            }
        }
    }
    
    @Published var globalThresholdMinutes: Double {
        didSet {
            UserDefaults.standard.set(globalThresholdMinutes, forKey: DefaultsKeys.notificationGlobalThreshold)
        }
    }
    
    @Published var cooldownMinutes: Double {
        didSet {
            UserDefaults.standard.set(cooldownMinutes, forKey: DefaultsKeys.notificationCooldown)
        }
    }
    
    @Published var quietHoursEnabled: Bool {
        didSet {
            UserDefaults.standard.set(quietHoursEnabled, forKey: DefaultsKeys.notificationQuietHoursEnabled)
        }
    }
    
    @Published var quietHoursStart: Date {
        didSet {
            UserDefaults.standard.set(quietHoursStart, forKey: DefaultsKeys.notificationQuietHoursStart)
        }
    }
    
    @Published var quietHoursEnd: Date {
        didSet {
            UserDefaults.standard.set(quietHoursEnd, forKey: DefaultsKeys.notificationQuietHoursEnd)
        }
    }
    
    @Published var weeklySummaryEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weeklySummaryEnabled, forKey: DefaultsKeys.notificationWeeklySummary)
            if weeklySummaryEnabled {
                if isEnabled {
                    scheduleWeeklySummary()
                }
            } else {
                notificationCenter.removePendingNotificationRequests(withIdentifiers: ["weekly-summary-scheduled"])
            }
        }
    }
    
    @Published var domainThresholds: [String: Double] {
        didSet {
            if let encoded = try? JSONEncoder().encode(domainThresholds) {
                UserDefaults.standard.set(encoded, forKey: DefaultsKeys.notificationDomainThresholds)
            }
        }
    }
    
    @Published var ignoredDomains: [String] {
        didSet {
            UserDefaults.standard.set(ignoredDomains, forKey: DefaultsKeys.notificationIgnoredDomains)
        }
    }
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    // MARK: - Private State
    private var lastNotificationTimes: [String: Date] = [:]
    private var monitoringTask: Task<Void, Never>?
    private var previousDomainTimes: [String: Double] = [:]
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - Initialization
    private override init() {
        let defaults = UserDefaults.standard
        
        // Load values from UserDefaults into local variables first
        let enabled = defaults.bool(forKey: DefaultsKeys.notificationsEnabled)
        
        var threshold = defaults.double(forKey: DefaultsKeys.notificationGlobalThreshold)
        if threshold == 0 {
            threshold = 30 // Default: 30 minutes
        }
        
        var cooldown = defaults.double(forKey: DefaultsKeys.notificationCooldown)
        if cooldown == 0 {
            cooldown = 60 // Default: 60 minutes cooldown
        }
        
        let quietEnabled = defaults.bool(forKey: DefaultsKeys.notificationQuietHoursEnabled)
        
        let quietStart: Date
        if let startDate = defaults.object(forKey: DefaultsKeys.notificationQuietHoursStart) as? Date {
            quietStart = startDate
        } else {
            var components = DateComponents()
            components.hour = 22
            components.minute = 0
            quietStart = Calendar.current.date(from: components) ?? Date()
        }
        
        let quietEnd: Date
        if let endDate = defaults.object(forKey: DefaultsKeys.notificationQuietHoursEnd) as? Date {
            quietEnd = endDate
        } else {
            var components = DateComponents()
            components.hour = 8
            components.minute = 0
            quietEnd = Calendar.current.date(from: components) ?? Date()
        }
        
        let weekly = defaults.bool(forKey: DefaultsKeys.notificationWeeklySummary)
        
        let domainThresholds: [String: Double]
        if let data = defaults.data(forKey: DefaultsKeys.notificationDomainThresholds),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            domainThresholds = decoded
        } else {
            domainThresholds = [:]
        }
        
        let ignored = defaults.stringArray(forKey: DefaultsKeys.notificationIgnoredDomains) ?? []
        
        // Initialize properties with local variables (no didSet will be called during init)
        self._isEnabled = Published(initialValue: enabled)
        self._globalThresholdMinutes = Published(initialValue: threshold)
        self._cooldownMinutes = Published(initialValue: cooldown)
        self._quietHoursEnabled = Published(initialValue: quietEnabled)
        self._quietHoursStart = Published(initialValue: quietStart)
        self._quietHoursEnd = Published(initialValue: quietEnd)
        self._weeklySummaryEnabled = Published(initialValue: weekly)
        self._domainThresholds = Published(initialValue: domainThresholds)
        self._ignoredDomains = Published(initialValue: ignored)
        
        super.init()
        
        notificationCenter.delegate = self
        checkAuthorizationStatus()
        
        if isEnabled {
            startMonitoring()
        }
    }
    
    // MARK: - Authorization
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            Task { @MainActor in
                if let error = error {
                    Logger.general.error("Notification authorization error: \(error.localizedDescription)")
                }
                self?.authorizationStatus = granted ? .authorized : .denied
                if granted {
                    self?.setupNotificationCategories()
                    self?.startMonitoring()
                }
            }
        }
    }
    
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                self?.authorizationStatus = status
            }
        }
    }
    
    private func setupNotificationCategories() {
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: .destructive
        )
        
        let closeTabAction = UNNotificationAction(
            identifier: "CLOSE_TAB",
            title: "Close Tab",
            options: .foreground
        )
        
        let ignoreDomainAction = UNNotificationAction(
            identifier: "IGNORE_DOMAIN",
            title: "Ignore This Domain",
            options: .destructive
        )
        
        let timeAlertCategory = UNNotificationCategory(
            identifier: "TIME_ALERT",
            actions: [dismissAction, closeTabAction, ignoreDomainAction],
            intentIdentifiers: [],
            options: []
        )
        
        let weeklySummaryCategory = UNNotificationCategory(
            identifier: "WEEKLY_SUMMARY",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([timeAlertCategory, weeklySummaryCategory])
    }
    
    // MARK: - Monitoring
    func startMonitoring() {
        guard monitoringTask == nil else { return }
        
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkTimeThresholds()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // Check every 30 seconds
            }
        }
        
        if weeklySummaryEnabled {
            scheduleWeeklySummary()
        }
    }
    
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    private func checkTimeThresholds() async {
        guard isEnabled else { return }
        guard authorizationStatus == .authorized else { return }
        guard !isInQuietHours() else { return }
        
        // Get current domain times from TabTimeStore
        let domains = await TabTimeStore.shared.topDomains(limit: 100)
        
        for (domain, seconds) in domains {
            let timeMinutes = seconds / 60.0
            
            // Skip ignored domains
            guard !ignoredDomains.contains(domain) else { continue }
            
            // Get threshold for this domain (use global if no override)
            let threshold = domainThresholds[domain] ?? globalThresholdMinutes
            
            // Check if threshold is exceeded
            guard timeMinutes >= threshold else { continue }
            
            // Check if we already notified for this domain recently (cooldown)
            if let lastNotification = lastNotificationTimes[domain] {
                let minutesSinceLastNotification = Date().timeIntervalSince(lastNotification) / 60.0
                guard minutesSinceLastNotification >= cooldownMinutes else { continue }
            }
            
            // Check if time has increased since last check (still actively using)
            let previousTime = previousDomainTimes[domain] ?? 0
            guard seconds > previousTime else { continue }
            
            // Send notification
            await sendTimeAlertNotification(domain: domain, minutes: Int(timeMinutes))
            lastNotificationTimes[domain] = Date()
        }
        
        // Update previous times
        var newPreviousTimes: [String: Double] = [:]
        for (domain, seconds) in domains {
            newPreviousTimes[domain] = seconds
        }
        previousDomainTimes = newPreviousTimes
    }
    
    // MARK: - Notifications
    private func sendTimeAlertNotification(domain: String, minutes: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Time Alert"
        content.body = "You've spent \(minutes) minutes on \(domain)."
        content.sound = .default
        content.categoryIdentifier = "TIME_ALERT"
        content.userInfo = ["domain": domain]
        
        let request = UNNotificationRequest(
            identifier: "time-alert-\(domain)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate
        )
        
        do {
            try await notificationCenter.add(request)
            Logger.general.info("Sent time alert for \(domain) (\(minutes) minutes)")
        } catch {
            Logger.general.error("Failed to send notification: \(error.localizedDescription)")
        }
    }
    
    func sendWeeklySummary() async {
        guard weeklySummaryEnabled else { return }
        guard authorizationStatus == .authorized else { return }
        
        let stats = await TabTimeStore.shared.getHistoricalStatistics(days: 7)
        let topDomains = stats.aggregatedDomainTime.prefix(3)
        
        let totalHours = Int(stats.totalTimeSeconds / 3600)
        let totalMinutes = Int((stats.totalTimeSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
        
        var body = "This week: \(totalHours)h \(totalMinutes)m total browsing time."
        if !topDomains.isEmpty {
            let topSites = topDomains.map { "\($0.domain) (\(Int($0.seconds/60))m)" }.joined(separator: ", ")
            body += " Top sites: \(topSites)"
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Browsing Summary"
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_SUMMARY"
        
        let request = UNNotificationRequest(
            identifier: "weekly-summary-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            Logger.general.error("Failed to send weekly summary: \(error.localizedDescription)")
        }
    }
    
    private func scheduleWeeklySummary() {
        // Remove existing scheduled summary
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["weekly-summary-scheduled"])
        
        // Schedule for next Sunday at 10 AM
        var components = DateComponents()
        components.weekday = 1 // Sunday
        components.hour = 10
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Browsing Summary"
        content.body = "Your browsing summary is ready!"
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_SUMMARY"
        
        let request = UNNotificationRequest(
            identifier: "weekly-summary-scheduled",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                Logger.general.error("Failed to schedule weekly summary: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func isInQuietHours() -> Bool {
        guard quietHoursEnabled else { return false }
        
        let calendar = Calendar.current
        let now = Date()
        
        let startComponents = calendar.dateComponents([.hour, .minute], from: quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)
        
        guard let startHour = startComponents.hour, let startMinute = startComponents.minute,
              let endHour = endComponents.hour, let endMinute = endComponents.minute else {
            return false
        }
        
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        guard let currentHour = nowComponents.hour, let currentMinute = nowComponents.minute else {
            return false
        }
        
        let currentTime = currentHour * 60 + currentMinute
        let startTime = startHour * 60 + startMinute
        let endTime = endHour * 60 + endMinute
        
        if startTime < endTime {
            return currentTime >= startTime && currentTime < endTime
        } else {
            // Crosses midnight
            return currentTime >= startTime || currentTime < endTime
        }
    }
    
    func addDomainThreshold(domain: String, minutes: Double) {
        domainThresholds[domain] = minutes
    }
    
    func removeDomainThreshold(domain: String) {
        domainThresholds.removeValue(forKey: domain)
    }
    
    func ignoreDomain(_ domain: String) {
        if !ignoredDomains.contains(domain) {
            ignoredDomains.append(domain)
        }
    }
    
    func unignoreDomain(_ domain: String) {
        ignoredDomains.removeAll { $0 == domain }
    }
    
    func resetLastNotificationTime(for domain: String) {
        lastNotificationTimes.removeValue(forKey: domain)
    }
    
    func resetAllNotificationTimes() {
        lastNotificationTimes.removeAll()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension TabTimeNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let extractedActionIdentifier = response.actionIdentifier
        let extractedDomain = response.notification.request.content.userInfo["domain"] as? String
        
        Task { @MainActor [extractedActionIdentifier, extractedDomain] in
            switch extractedActionIdentifier {
            case "CLOSE_TAB":
                if let domain = extractedDomain {
                    await closeTabsForDomain(domain)
                }
                
            case "IGNORE_DOMAIN":
                if let domain = extractedDomain {
                    TabTimeNotificationManager.shared.ignoreDomain(domain)
                }
                
            case "DISMISS", UNNotificationDefaultActionIdentifier:
                break
                
            default:
                break
            }
        }
        
        completionHandler()
    }
    
    private func closeTabsForDomain(_ domain: String) async {
        // Post notification that the view model can observe
        NotificationCenter.default.post(
            name: .closeTabsForDomain,
            object: nil,
            userInfo: ["domain": domain]
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let closeTabsForDomain = Notification.Name("closeTabsForDomain")
}
