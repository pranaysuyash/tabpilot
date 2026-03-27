import SwiftUI

/// Guide view for installing the Chrome extension
struct ExtensionInstallationGuide: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = ExtensionInstallationManager.shared
    @State private var showDontShowAgain = false
    @State private var isChromeInstalled = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("Install TabPilot Extension")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Track your tab usage and see detailed time analytics")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color.adaptiveOverlayBackground)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !isChromeInstalled {
                        chromeNotInstalledSection
                    } else {
                        whatExtensionDoesSection
                        installationStepsSection
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer
            VStack(spacing: 12) {
                if showDontShowAgain {
                    Toggle("Don't show this again", isOn: .init(
                        get: { manager.shouldShowGuide() == false },
                        set: { if $0 { manager.markDontShowAgain() } }
                    ))
                    .toggleStyle(.checkbox)
                }
                
                HStack(spacing: 12) {
                    Button("Remind Me Later") {
                        manager.dismissGuide()
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                    
                    Button("Open Chrome Extensions") {
                        manager.openChromeExtensions()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isChromeInstalled)
                }
            }
            .padding(16)
            .background(Color.adaptiveOverlayBackground)
        }
        .frame(width: 500, height: 600)
        .onAppear {
            checkChromeInstallation()
        }
    }
    
    private var chromeNotInstalledSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Chrome Not Detected", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.orange)
            
            Text("The TabPilot extension requires Google Chrome to be installed on your Mac. The extension tracks your tab activity and sends time data to this app.")
                .font(.body)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("To use this feature:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                BulletPoint(text: "Download and install Google Chrome from google.com/chrome")
                BulletPoint(text: "Return to TabPilot and open this guide again")
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var whatExtensionDoesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What the Extension Does", systemImage: "info.circle")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "clock", text: "Tracks time spent on each website")
                FeatureRow(icon: "chart.bar", text: "Shows detailed usage statistics")
                FeatureRow(icon: "timer", text: "Identifies your most visited domains")
                FeatureRow(icon: "lock.shield", text: "Data stays on your device - no cloud")
            }
        }
        .padding()
        .background(Color.adaptiveTextBackground)
        .cornerRadius(8)
    }
    
    private var installationStepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Installation Steps", systemImage: "list.number")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                StepRow(
                    number: 1,
                    title: "Open Chrome Extensions",
                    description: "Click the button below or navigate to chrome://extensions",
                    action: { manager.openChromeExtensions() }
                )
                
                StepRow(
                    number: 2,
                    title: "Enable Developer Mode",
                    description: "Toggle the \"Developer mode\" switch in the top-right corner",
                    action: nil
                )
                
                StepRow(
                    number: 3,
                    title: "Load Unpacked Extension",
                    description: "Click \"Load unpacked\" and select the extension folder",
                    action: nil
                )
                
                StepRow(
                    number: 4,
                    title: "Grant Permissions",
                    description: "Allow the extension to access tab data when prompted",
                    action: nil
                )
            }
        }
        .padding()
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }
    
    private func checkChromeInstallation() {
        // Check if Chrome is installed by looking for the app
        let chromePath = "/Applications/Google Chrome.app"
        isChromeInstalled = FileManager.default.fileExists(atPath: chromePath)
    }
}

// MARK: - Supporting Views

private struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.body)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
        }
    }
}

private struct StepRow: View {
    let number: Int
    let title: String
    let description: String
    let action: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Number circle
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 28, height: 28)
                
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if let action = action {
                        Button("Open") {
                            action()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview("With Chrome") {
    ExtensionInstallationGuide()
}

#Preview("Without Chrome") {
    ExtensionInstallationGuide()
        .onAppear {
            // Simulate Chrome not installed
            UserDefaults.standard.set(false, forKey: "chromeInstalled_preview")
        }
}
