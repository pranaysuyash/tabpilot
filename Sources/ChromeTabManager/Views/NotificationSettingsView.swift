import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = TabTimeNotificationManager.shared
    @State private var newDomain: String = ""
    @State private var newThreshold: Double = 30
    @State private var showingAuthorizationAlert = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Time Notifications", isOn: $notificationManager.isEnabled)
                    .onChange(of: notificationManager.isEnabled) { _, newValue in
                        if newValue {
                            notificationManager.requestAuthorization()
                        } else {
                            notificationManager.stopMonitoring()
                        }
                    }
                
                if notificationManager.authorizationStatus == .denied {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Notifications are disabled in System Settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Settings") {
                            openNotificationSettings()
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            
            if notificationManager.isEnabled {
                Section("Global Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Threshold")
                            Spacer()
                            Text("\(Int(notificationManager.globalThresholdMinutes)) minutes")
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(
                            value: $notificationManager.globalThresholdMinutes,
                            in: 5...120,
                            step: 5
                        )
                        
                        Text("Notify when you spend this much time on any website")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Cooldown Period")
                            Spacer()
                            Text("\(Int(notificationManager.cooldownMinutes)) minutes")
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(
                            value: $notificationManager.cooldownMinutes,
                            in: 15...240,
                            step: 15
                        )
                        
                        Text("Wait this long before sending another notification for the same site")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Quiet Hours") {
                    Toggle("Enable Quiet Hours", isOn: $notificationManager.quietHoursEnabled)
                    
                    if notificationManager.quietHoursEnabled {
                        DatePicker(
                            "Start",
                            selection: $notificationManager.quietHoursStart,
                            displayedComponents: .hourAndMinute
                        )
                        
                        DatePicker(
                            "End",
                            selection: $notificationManager.quietHoursEnd,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
                
                Section("Weekly Summary") {
                    Toggle("Enable Weekly Summary", isOn: $notificationManager.weeklySummaryEnabled)
                    
                    Text("Receive a summary of your browsing time every Sunday")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Per-Domain Thresholds") {
                    Text("Override the default threshold for specific domains")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if notificationManager.domainThresholds.isEmpty {
                        Text("No custom thresholds set")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(notificationManager.domainThresholds.keys.sorted()), id: \.self) { domain in
                            if let threshold = notificationManager.domainThresholds[domain] {
                                HStack {
                                    Text(domain)
                                    Spacer()
                                    Text("\(Int(threshold)) min")
                                        .foregroundStyle(.secondary)
                                    Button("Remove") {
                                        notificationManager.removeDomainThreshold(domain: domain)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    
                    VStack(spacing: 8) {
                        TextField("Domain (e.g., youtube.com)", text: $newDomain)
                        
                        HStack {
                            Text("Threshold: \(Int(newThreshold)) minutes")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Slider(value: $newThreshold, in: 5...120, step: 5)
                                .frame(width: 150)
                        }
                        
                        Button("Add Custom Threshold") {
                            let trimmed = newDomain.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                notificationManager.addDomainThreshold(domain: trimmed, minutes: newThreshold)
                                newDomain = ""
                                newThreshold = 30
                            }
                        }
                        .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Section("Ignored Domains") {
                    Text("Domains you don't want to receive notifications for")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if notificationManager.ignoredDomains.isEmpty {
                        Text("No domains ignored")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(notificationManager.ignoredDomains, id: \.self) { domain in
                            HStack {
                                Text(domain)
                                Spacer()
                                Button("Remove") {
                                    notificationManager.unignoreDomain(domain)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Reset All Notification Times") {
                        notificationManager.resetAllNotificationTimes()
                    }
                    .foregroundStyle(.red)
                    
                    Text("This will allow notifications to be sent again for all domains, regardless of previous cooldown periods")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            notificationManager.checkAuthorizationStatus()
        }
    }
    
    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    NotificationSettingsView()
        .frame(width: 500, height: 600)
}
