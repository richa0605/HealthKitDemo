import Foundation
import Observation

@Observable
class HealthDataViewModel {
    var isAuthorized = false
    var authorizationError: String? = nil
    var isLoading = false
    var showPermissionAlert = false
    var showNotificationPermissionAlert = false
    
    let cyclePhase = "Follicular Phase · Day 8"
    
    private let dataManager = HealthDataManager()
    private let notificationManager = NotificationManager.shared
    
    var dailyMetrics: [DailyHealthMetric] {
        dataManager.dailyMetrics
    }
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }
    
    func setupAndRequestPermissions() async {
        isLoading = true
        authorizationError = nil
        
        do {
            try await dataManager.requestAuthorization()
            isAuthorized = true
            dataManager.startObservingChanges()
            try await Task.sleep(nanoseconds: 500_000_000)
            await fetchHealthData()
        } catch {
            isAuthorized = false
            authorizationError = error.localizedDescription
            await MainActor.run {
                self.showPermissionAlert = true
            }
        }
        
        isLoading = false
        
        do {
            _ = try await notificationManager.requestAuthorization()
        } catch {
        }
    }
    
    func fetchHealthData() async {
        guard isAuthorized else {
            await MainActor.run {
                self.showPermissionAlert = true
            }
            return
        }
        
        await MainActor.run {
            let data = dataManager.dailyMetrics
            let hasNoData = data.allSatisfy { $0.stepCount == nil && $0.restingHeartRate == nil }
            if hasNoData {
                self.showPermissionAlert = true
            }
        }
    }
    
    func triggerTestNotification() async -> Bool {
        let granted = await notificationManager.isNotificationPermissionGranted()
        if granted {
            do {
                try await notificationManager.scheduleTestNotification()
                return true
            } catch {
                return false
            }
        } else {
            await MainActor.run {
                self.showNotificationPermissionAlert = true
            }
            return false
        }
    }
}
