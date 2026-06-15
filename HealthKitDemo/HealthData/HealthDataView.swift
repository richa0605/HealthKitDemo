import SwiftUI
import Charts

struct HealthDataView: View {
    @State private var viewModel = HealthDataViewModel()
    @State private var isTestNotificationScheduled = false
    
    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if !viewModel.isAuthorized {
                        permissionNeededView
                    } else {
                        metricsListView
                        chartSectionView
                    }
                    
                    actionsSectionView
                }
                .padding()
            }
            .navigationTitle("Health Sync")
            .refreshable {
                await viewModel.fetchHealthData()
            }
            .task {
                await viewModel.setupAndRequestPermissions()
            }
            .alert("Permissions Required", isPresented: $viewModel.showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please turn on HealthKit permissions for Step Count and Resting Heart Rate in system Settings -> Health -> Data Access & Devices -> HealthSync.")
            }
            .alert("Notification Permissions Required", isPresented: $viewModel.showNotificationPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please turn on Notifications permissions in system Settings -> Notifications -> HealthSync to receive symptom reminder alerts.")
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.greeting)
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                Spacer()
                Image(systemName: "heart.text.square.fill")
                    .font(.title)
                    .foregroundStyle(.pink)
            }
            
            Text(viewModel.cyclePhase)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.pink.opacity(0.1))
                .foregroundStyle(.pink)
                .clipShape(Capsule())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var permissionNeededView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Health Access Required")
                .font(.headline)
            
            Text("To display your data, please authorize HealthKit permissions in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if let error = viewModel.authorizationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            Button("Grant Access") {
                Task {
                    await viewModel.setupAndRequestPermissions()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var metricsListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Health Metrics")
                .font(.headline)
                .padding(.bottom, 4)
            
            ForEach(viewModel.dailyMetrics) { metric in
                HStack {
                    Text(metric.date.formatted(.dateTime.weekday().month().day()))
                        .font(.body)
                        .frame(width: 110, alignment: .leading)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.blue)
                        if let steps = metric.stepCount {
                            Text(String(format: "%.0f", steps))
                        } else {
                            Text("-")
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 90, alignment: .trailing)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        if let heartRate = metric.restingHeartRate {
                            Text(String(format: "%.0f bpm", heartRate))
                        } else {
                            Text("-")
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 90, alignment: .trailing)
                }
                .padding(.vertical, 8)
                
                if metric != viewModel.dailyMetrics.last {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var chartSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Step Activity")
                .font(.headline)
            
            Chart {
                ForEach(viewModel.dailyMetrics) { metric in
                    BarMark(
                        x: .value("Day", metric.date, unit: .day),
                        y: .value("Steps", metric.stepCount ?? 0)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.short))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var actionsSectionView: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    let success = await viewModel.triggerTestNotification()
                    if success {
                        isTestNotificationScheduled = true
                    }
                }
            }) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                    Text("Test 10s Reminder")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.pink)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if isTestNotificationScheduled {
                Text("Notification scheduled! Background the simulator now to verify.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    HealthDataView()
}
