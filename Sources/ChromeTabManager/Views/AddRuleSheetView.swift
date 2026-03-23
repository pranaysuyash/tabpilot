import SwiftUI

struct AddRuleSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var patternText = ""
    @State private var patternDescription = ""
    @State private var isEnabled = true
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add URL Pattern")
                .font(.headline)
            
            Form {
                TextField("URL Pattern", text: $patternText)
                
                TextField("Description (optional)", text: $patternDescription)
                
                Toggle("Enabled", isOn: $isEnabled)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add Pattern") {
                    addPattern()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(patternText.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 280)
    }
    
    private func addPattern() {
        let pattern = URLPattern(
            pattern: patternText,
            enabled: isEnabled,
            description: patternDescription.isEmpty ? patternText : patternDescription
        )
        
        var patterns = URLPatternStore.shared.loadPatterns()
        patterns.append(pattern)
        URLPatternStore.shared.savePatterns(patterns)
    }
}
