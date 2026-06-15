# HealthKitDemo iOS Application

A SwiftUI iOS application demonstrating HealthKit integration, daily symptom logging reminders (local notifications), and activity summary visualization using SwiftUI Charts. The application is built using modern Swift 5.10 / iOS 17+ features, following the MVVM architectural pattern.

## What Was Built

1. **HealthKit Sync Dashboard**: 
   - Displays a greeting dynamically updated based on the system hour (e.g., "Good Morning", "Good Afternoon", "Good Evening").
   - Shows a hardcoded cycle phase indicator (`Follicular Phase · Day 8`).
   - Requests read authorization for `stepCount` and `restingHeartRate` metrics.
   - Summarizes the last 7 calendar days (including today) using a list of `Date · Step Count · Resting Heart Rate`.
   - Handles missing values gracefully by outputting `-` instead of crashing.
   - Shows error states and fallbacks for restricted or denied HealthKit permissions.

2. **Daily Symptom Log Reminders**:
   - Asks permission for local notifications on first launch.
   - Schedules a daily recurring reminder at 8:00 PM with the text `"Time to log today's symptoms"`.
   - Prevents duplicate reminders by verifying existing pending requests.
   - Provides a "Test 10s Reminder" button to easily verify notification scheduling in the simulator.

3. **Step Count Mini Chart**:
   - Visualizes step counts over the 7-day period using a bar chart via the SwiftUI `Charts` framework.

---

## Key Implementation Decisions

- **MVVM Architecture & Swift Observation**:
  - The view model uses Swift’s `@Observable` macro to notify the view of state changes. This is standard in iOS 17+, removing the boilerplate associated with `@Published` and `@StateObject`.
  - The data retrieval logic and notification logic are completely separated from the UI layer into `HealthDataManager` and `NotificationManager`.

- **Aggregate Data Queries (`HKStatisticsCollectionQuery`)**:
  - Used `HKStatisticsCollectionQuery` as required to aggregate step counts (`.cumulativeSum`) and resting heart rates (`.discreteAverage`) over 1-day intervals. This avoids querying raw samples and performs calculations directly on the HealthKit store.

- **Reactive Updates & Background Delivery**:
  - Implemented `HKObserverQuery` and `enableBackgroundDelivery(for:frequency:completion:)` in `HealthDataManager` to receive background updates from HealthKit. When new health data is synchronized, the manager notifies the view model to automatically refresh the dashboard.

---

## Assumptions Made

1. **Target Environment**:
   - Targeted Xcode 16+ and iOS 17+ (the project target is set to iOS 18.5) to utilize SwiftUI Charts and the Observation framework.
2. **Resting Heart Rate Unit**:
   - Assumed the unit for resting heart rate is beats per minute (`count/min` in HealthKit).
3. **Greeting Time Slots**:
   - 5:00 AM - 11:59 AM -> "Good Morning"
   - 12:00 PM - 4:59 PM -> "Good Afternoon"
   - 5:00 PM - 4:59 AM -> "Good Evening"

---

## What I Would Improve With More Time

1. **Unit Testing Coverage**:
   - Add unit tests for the data managers and view model logic using `XCTest` or Swift Testing. Mock the HealthKit store to simulate success and authorization error conditions.
2. **Expanded Health Metrics**:
   - Integrate more metrics like Active Energy Burned, Sleep Analysis, and Water Intake.
3. **Dynamic Cycle Phase Tracking**:
   - Replace the hardcoded cycle phase string with a functional calculator based on user-logged period logs or ovulation tracking.
4. **Enhanced Data Synchronization Caching**:
   - Implement local persistence (CoreData/SwiftData) to cache the latest metrics and show them immediately while loading or when HealthKit permissions are temporarily restricted.
