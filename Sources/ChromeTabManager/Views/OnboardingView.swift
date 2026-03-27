import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage
                    .tag(0)
                    .accessibilityLabel("Welcome page")
                
                permissionsPage
                    .tag(1)
                    .accessibilityLabel("Permissions page")
                
                gettingStartedPage
                    .tag(2)
                    .accessibilityLabel("Getting started page")
            }
            .tabViewStyle(.automatic)
            
            pageIndicator
                .accessibilityLabel("Page indicator, page \(currentPage + 1) of 3")
            
            navigationButtons
        }
        .frame(width: 600, height: 450)
    }
    
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            
             Image(systemName: "airplane.departure")
                    .font(.system(size: 80)) // Using system will respect accessibility settings
                    .foregroundStyle(.blue.gradient)
                .accessibilityLabel("TabPilot app icon")
            
            Text("Welcome to TabPilot")
                .font(.largeTitle.bold())
                .accessibilityLabel("Welcome to TabPilot")
            
            Text("Your Chrome tab cleanup companion. Download once, use forever.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Your Chrome tab cleanup companion. Download once, use forever.")
            
            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "doc.on.doc", text: "Find duplicate tabs across all windows")
                featureRow(icon: "arrow.uturn.backward", text: "30-second undo on every close")
                featureRow(icon: "shield.checkered", text: "Protected domains keep important tabs safe")
                featureRow(icon: "chart.bar.fill", text: "Tab Debt Score tracks your browser health")
            }
            .padding(.top, 12)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private var permissionsPage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange.gradient)
                .accessibilityLabel("Permissions icon")
            
            Text("Automation Access Required")
                .font(.largeTitle.bold())
                .accessibilityLabel("Automation Access Required")
            
            Text("TabPilot needs permission to control Google Chrome so it can scan and close your tabs.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityLabel("TabPilot needs permission to control Google Chrome so it can scan and close your tabs.")
            
            VStack(alignment: .leading, spacing: 16) {
                infoBox(
                    icon: "applescript",
                    title: "AppleScript Automation",
                    text: "TabPilot uses Apple's scripting system to communicate with Chrome. This is the same technology used by many macOS apps."
                )
                
                infoBox(
                    icon: "lock.shield",
                    title: "Your Data Stays Private",
                    text: "TabPilot never sends your tab data anywhere. All processing happens locally on your Mac."
                )
                
                infoBox(
                    icon: "checkmark.shield",
                    title: "You Stay in Control",
                    text: "Review every tab before closing. Use the undo button to restore any tab within 30 seconds."
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private var gettingStartedPage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "flag.checkered")
                .font(.system(size: 72))
                .foregroundStyle(.green.gradient)
                .accessibilityLabel("Getting started icon")
            
            Text("You're All Set!")
                .font(.largeTitle.bold())
                .accessibilityLabel("You are all set")
            
            Text("Here's how to get started with TabPilot.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Here is how to get started with TabPilot.")
            
            VStack(alignment: .leading, spacing: 16) {
                stepRow(number: 1, title: "Click 'Scan Now'", text: "TabPilot will scan all your Chrome windows and find duplicate tabs.")
                
                stepRow(number: 2, title: "Review Your Duplicates", text: "See every duplicate group. Keep the tabs you need, close the rest.")
                
                stepRow(number: 3, title: "Use Undo if Needed", text: "Accidentally closed something? Click the undo button within 30 seconds to restore it.")
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
                .accessibilityHidden(true)
            
            Text(text)
                .font(.body)
                .accessibilityLabel(text)
        }
    }
    
    private func infoBox(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 28)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .accessibilityLabel(title)
                
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(text)
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func stepRow(number: Int, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())
                .accessibilityLabel("Step \(number)")
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .accessibilityLabel(title)
                
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(text)
            }
        }
    }
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.blue : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(index == currentPage ? "Current page" : "Page \(index + 1)")
            }
        }
        .padding(.vertical, 20)
    }
    
    private var navigationButtons: some View {
        HStack {
            if currentPage > 0 {
                Button("Back") {
                    withAnimation {
                        currentPage -= 1
                    }
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .accessibleLabel("Go back", hint: "Go to the previous page")
            }
            
            Spacer()
            
            if currentPage < 2 {
                Button("Next") {
                    withAnimation {
                        currentPage += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .keyboardShortcut(.return, modifiers: [])
                .accessibleLabel("Next page", hint: "Go to the next page")
            } else {
                Button("Get Started") {
                    completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .accessibleLabel("Get started", hint: "Complete onboarding and start using TabPilot")
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = true
        AccessibilityAnnouncements.announce("Onboarding complete. TabPilot is ready to use.")
    }
}

extension UserDefaults {
    var hasCompletedOnboarding: Bool {
        get { bool(forKey: "hasCompletedOnboarding") }
        set { set(newValue, forKey: "hasCompletedOnboarding") }
    }
}
