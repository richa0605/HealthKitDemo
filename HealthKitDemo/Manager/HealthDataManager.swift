import Foundation
import HealthKit
import Observation

struct DailyHealthMetric: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let stepCount: Double?
    let restingHeartRate: Double?
}

enum HealthKitError: Error {
    case notAvailable
    case invalidType
    case queryFailed
}

@Observable
class HealthDataManager {
    var dailyMetrics: [DailyHealthMetric] = []
    
    private let healthStore = HKHealthStore()
    private var stepsSamples: [HKQuantitySample] = []
    private var heartRateSamples: [HKQuantitySample] = []
    
    private var stepsAnchor: HKQueryAnchor?
    private var heartRateAnchor: HKQueryAnchor?
    
    private var stepsTask: Task<Void, Never>?
    private var heartRateTask: Task<Void, Never>?
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        guard let steps = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let heartRate = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitError.invalidType
        }
        
        try await healthStore.requestAuthorization(toShare: [], read: [steps, heartRate])
    }
    
    func startObservingChanges() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return
        }
        
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        
        stepsTask = Task {
            let descriptor = HKAnchoredObjectQueryDescriptor(
                predicates: [.sample(type: stepsType, predicate: predicate)],
                anchor: stepsAnchor
            )
            do {
                for try await update in descriptor.results(for: healthStore) {
                    await MainActor.run {
                        self.processStepsChanges(added: update.addedSamples, deleted: update.deletedObjects)
                        self.stepsAnchor = update.newAnchor
                        self.updateDailyMetrics()
                    }
                }
            } catch {
            }
        }
        
        heartRateTask = Task {
            let descriptor = HKAnchoredObjectQueryDescriptor(
                predicates: [.sample(type: heartRateType, predicate: predicate)],
                anchor: heartRateAnchor
            )
            do {
                for try await update in descriptor.results(for: healthStore) {
                    await MainActor.run {
                        self.processHeartRateChanges(added: update.addedSamples, deleted: update.deletedObjects)
                        self.heartRateAnchor = update.newAnchor
                        self.updateDailyMetrics()
                    }
                }
            } catch {
            }
        }
    }
    
    func stopObserving() {
        stepsTask?.cancel()
        heartRateTask?.cancel()
    }
    
    @MainActor
    private func processStepsChanges(added: [HKSample], deleted: [HKDeletedObject]) {
        if let newSteps = added as? [HKQuantitySample] {
            let newUUIDs = Set(newSteps.map { $0.uuid })
            self.stepsSamples.removeAll { newUUIDs.contains($0.uuid) }
            self.stepsSamples.append(contentsOf: newSteps)
        }
        let deletedUUIDs = Set(deleted.map { $0.uuid })
        if !deletedUUIDs.isEmpty {
            self.stepsSamples.removeAll { deletedUUIDs.contains($0.uuid) }
        }
    }
    
    @MainActor
    private func processHeartRateChanges(added: [HKSample], deleted: [HKDeletedObject]) {
        if let newHeartRates = added as? [HKQuantitySample] {
            let newUUIDs = Set(newHeartRates.map { $0.uuid })
            self.heartRateSamples.removeAll { newUUIDs.contains($0.uuid) }
            self.heartRateSamples.append(contentsOf: newHeartRates)
        }
        let deletedUUIDs = Set(deleted.map { $0.uuid })
        if !deletedUUIDs.isEmpty {
            self.heartRateSamples.removeAll { deletedUUIDs.contains($0.uuid) }
        }
    }
    
    @MainActor
    private func updateDailyMetrics() {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return }
        
        self.stepsSamples.removeAll { $0.startDate < startDate }
        self.heartRateSamples.removeAll { $0.startDate < startDate }
        
        var metrics: [DailyHealthMetric] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: startOfToday) {
                let normalizedDate = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: normalizedDate) ?? normalizedDate
                
                let daySteps = stepsSamples.filter { $0.startDate >= normalizedDate && $0.startDate <= endOfDay }
                let stepCount: Double? = daySteps.isEmpty ? nil : daySteps.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .count()) }
                
                let dayHeart = heartRateSamples.filter { $0.startDate >= normalizedDate && $0.startDate <= endOfDay }
                let restingHeartRate: Double? = dayHeart.isEmpty ? nil : dayHeart.reduce(0.0) { $0 + $1.quantity.doubleValue(for: HKUnit(from: "count/min")) } / Double(dayHeart.count)
                
                metrics.append(DailyHealthMetric(date: normalizedDate, stepCount: stepCount, restingHeartRate: restingHeartRate))
            }
        }
        
        self.dailyMetrics = metrics.reversed()
    }
}
