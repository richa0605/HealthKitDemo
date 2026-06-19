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
  - The view model uses Swift’s `@Observable` macro to notify the view of state changes.
  - The data retrieval logic and notification logic are completely separated from the UI layer into `HealthDataManager` and `NotificationManager`.

- **Real-Time Incremental Sync (`HKAnchoredObjectQueryDescriptor`)**:
  - Replaced the initial static query model with `HKAnchoredObjectQueryDescriptor` which streams real-time additions and deletions as an async sequence.
  - Keeps in-memory caches of step count and resting heart rate samples, appending and subtracting deltas dynamically as they are synced.
  - Performs local calculations (sum for step counts, average for resting heart rate) to update the daily dashboard.
  - Optimizes system battery and network calls by only requesting updated or new samples since the last recorded query anchor.
  - Automatically garbage-collects cached samples that fall outside the rolling 7-day calendar window.

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
   - Add unit tests for the anchored query manager and local calculations using the Swift Testing framework.
2. **Dynamic Cycle Phase Tracking**:
   - Replace the hardcoded cycle phase string with a functional calculator based on user-logged period logs or ovulation tracking.
3. **CoreData Cache Persistence**:
   - Persist query anchors and cached samples to local storage so the dashboard renders instantly on cold start before new incremental syncs complete.
