import SwiftUI

struct AutoCleanupPreferencesView: View {
    @State private var isEnabled = false
    @State private var checkInterval: Double = 15
    @State private var rules: [CleanupRule] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Auto-Cleanup Settings")
                .font(.headline)
            
            Toggle("Enable Auto-Cleanup", isOn: $isEnabled)
                .onChange(of: isEnabled) { newValue in
                    AutoCleanupManager.shared.isEnabled = newValue
                }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Check Interval: \(Int(checkInterval)) minutes")
                Slider(value: $checkInterval, in: 5...60, step: 5)
                    .onChange(of: checkInterval) { newValue in
                        AutoCleanupManager.shared.checkInterval = newValue * 60
                    }
            }
            
            Divider()
            
            Text("Cleanup Rules")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if rules.isEmpty {
                Text("No cleanup rules configured")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                List {
                    ForEach(rules) { rule in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(rule.name)
                                    .font(.subheadline)
                                Text(rule.pattern.pattern)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if rule.enabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            
            HStack {
                Button("Add Rule") {
                }
                
                Spacer()
                
                Button("Refresh") {
                    loadRules()
                }
            }
        }
        .padding()
        .onAppear {
            loadSettings()
            loadRules()
        }
    }
    
    private func loadSettings() {
        isEnabled = AutoCleanupManager.shared.isEnabled
        checkInterval = AutoCleanupManager.shared.checkInterval / 60
    }
    
    private func loadRules() {
        rules = CleanupRuleStore.shared.rules
    }
}rules = CleanupRuleStore.shared.loadRules()
    }
}
