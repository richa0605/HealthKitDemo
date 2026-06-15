import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private let dailyReminderIdentifier = "com.swifties.HealthKitDemo.daily_reminder"
    private let testReminderIdentifier = "com.swifties.HealthKitDemo.test_reminder"
    
    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        if granted {
            try await scheduleDailyReminder()
        }
        return granted
    }
    
    func scheduleDailyReminder() async throws {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        let alreadyScheduled = pendingRequests.contains { $0.identifier == dailyReminderIdentifier }
        
        guard !alreadyScheduled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Symptom Log"
        content.body = "Time to log today's symptoms"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderIdentifier, content: content, trigger: trigger)
        
        try await center.add(request)
    }
    
    func scheduleTestNotification() async throws {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Test Reminder"
        content.body = "Time to log today's symptoms"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: testReminderIdentifier, content: content, trigger: trigger)
        
        try await center.add(request)
    }
    
    func isNotificationPermissionGranted() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
}
