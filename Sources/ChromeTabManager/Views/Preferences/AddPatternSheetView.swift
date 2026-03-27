import SwiftUI

struct AddPatternSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var onSave: (() -> Void)? = nil

    @State private var name = ""
    @State private var patternText = ""
    @State private var action: URLPattern.PatternAction = .keep

    var body: some View {
        VStack(spacing: 16) {
            Text("Add URL Pattern")
                .font(.headline)

            Form {
                Section("Pattern") {
                    TextField("Name", text: $name)
                    TextField("URL pattern (e.g. *.example.com)", text: $patternText)
                }

                Section("Action") {
                    Picker("Action", selection: $action) {
                        ForEach(URLPattern.PatternAction.allCases, id: \.self) { act in
                            Label(act.rawValue, systemImage: act.icon)
                                .tag(act)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    save()
                    dismiss()
                    onSave?()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(patternText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 420, height: 280)
    }

    private func save() {
        let trimmedPattern = patternText.trimmingCharacters(in: .whitespaces)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let pattern = URLPattern(
            pattern: trimmedPattern,
            description: trimmedName.isEmpty ? trimmedPattern : trimmedName,
            action: action
        )
        var patterns = URLPatternStore.shared.loadPatterns()
        patterns.append(pattern)
        URLPatternStore.shared.savePatterns(patterns)
    }
}
