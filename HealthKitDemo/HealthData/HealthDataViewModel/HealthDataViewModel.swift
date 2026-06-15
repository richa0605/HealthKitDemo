import Foundation
import Observation

@Observable
class HealthDataViewModel {
    var dailyMetrics: [DailyHealthMetric] = []
    var isAuthorized = false
    var authorizationError: String? = nil
    var isLoading = false
    var showPermissionAlert = false
    var showNotificationPermissionAlert = false
    
    let cyclePhase = "Follicular Phase · Day 8"
    
    private let dataManager = HealthDataManager()
    private let notificationManager = NotificationManager.shared
    
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
            await fetchHealthData()
            setupBackgroundObservation()
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
            // Notifications authorization failure does not block the UI
        }
    }
    
    func fetchHealthData() async {
        guard isAuthorized else {
            await MainActor.run {
                self.showPermissionAlert = true
            }
            return
        }
        
        do {
            let data = try await dataManager.fetchLast7DaysData()
            await MainActor.run {
                self.dailyMetrics = data
                
                let hasNoData = data.allSatisfy { $0.stepCount == nil && $0.restingHeartRate == nil }
                if hasNoData {
                    self.showPermissionAlert = true
                }
            }
        } catch {
            await MainActor.run {
                self.authorizationError = error.localizedDescription
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
    
    private func setupBackgroundObservation() {
        dataManager.startObservingUpdates { [weak self] in
            Task {
                await self?.fetchHealthData()
            }
        }
    }
}
