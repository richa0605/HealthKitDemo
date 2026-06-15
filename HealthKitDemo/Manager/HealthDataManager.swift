import Foundation
import HealthKit

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

class HealthDataManager {
    private let healthStore = HKHealthStore()
    
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
    
    func fetchLast7DaysData() async throws -> [DailyHealthMetric] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitError.invalidType
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else {
            throw HealthKitError.queryFailed
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let interval = DateComponents(day: 1)
        
        let stepsData = try await fetchSteps(type: stepsType, predicate: predicate, anchor: startOfToday, interval: interval, start: startDate, end: now)
        let heartRateData = try await fetchHeartRate(type: heartRateType, predicate: predicate, anchor: startOfToday, interval: interval, start: startDate, end: now)
        
        var metrics: [DailyHealthMetric] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: startOfToday) {
                let normalizedDate = calendar.startOfDay(for: date)
                let steps = stepsData[normalizedDate]
                let heart = heartRateData[normalizedDate]
                metrics.append(DailyHealthMetric(date: normalizedDate, stepCount: steps, restingHeartRate: heart))
            }
        }
        
        return metrics.reversed()
    }
    
    func startObservingUpdates(onUpdate: @escaping () -> Void) {
        guard let steps = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let heartRate = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return
        }
        
        let stepsQuery = HKObserverQuery(sampleType: steps, predicate: nil) { _, completionHandler, error in
            if error == nil {
                onUpdate()
            }
            completionHandler()
        }
        
        let heartQuery = HKObserverQuery(sampleType: heartRate, predicate: nil) { _, completionHandler, error in
            if error == nil {
                onUpdate()
            }
            completionHandler()
        }
        
        healthStore.execute(stepsQuery)
        healthStore.execute(heartQuery)
        
        healthStore.enableBackgroundDelivery(for: steps, frequency: .immediate) { _, _ in }
        healthStore.enableBackgroundDelivery(for: heartRate, frequency: .immediate) { _, _ in }
    }
    
    private func fetchSteps(type: HKQuantityType, predicate: NSPredicate, anchor: Date, interval: DateComponents, start: Date, end: Date) async throws -> [Date: Double] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                var data: [Date: Double] = [:]
                guard let results = results else {
                    continuation.resume(returning: data)
                    return
                }
                
                let calendar = Calendar.current
                results.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let dayDate = calendar.startOfDay(for: statistics.startDate)
                    if let sum = statistics.sumQuantity() {
                        data[dayDate] = sum.doubleValue(for: .count())
                    }
                }
                
                continuation.resume(returning: data)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    private func fetchHeartRate(type: HKQuantityType, predicate: NSPredicate, anchor: Date, interval: DateComponents, start: Date, end: Date) async throws -> [Date: Double] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: anchor,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                var data: [Date: Double] = [:]
                guard let results = results else {
                    continuation.resume(returning: data)
                    return
                }
                
                let calendar = Calendar.current
                results.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let dayDate = calendar.startOfDay(for: statistics.startDate)
                    if let average = statistics.averageQuantity() {
                        data[dayDate] = average.doubleValue(for: HKUnit(from: "count/min"))
                    }
                }
                
                continuation.resume(returning: data)
            }
            
            self.healthStore.execute(query)
        }
    }
}
