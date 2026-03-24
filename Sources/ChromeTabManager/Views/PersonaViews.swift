import SwiftUI

// RECOVERY-ADDON (2026-03-24):
// Restores `PersonaViews.swift` as an additive compatibility layer.
// Canonical persona/sidebar implementations currently live in SidebarView.swift.

struct PersonaSidebarCardView: View {
    let analysis: UserAnalysis
    @ObservedObject var viewModel: TabManagerViewModel

    var body: some View {
        PersonaCard(analysis: analysis, viewModel: viewModel)
    }
}

struct PersonaScanningCardView: View {
    @ObservedObject var viewModel: TabManagerViewModel

    var body: some View {
        ScanningCard(viewModel: viewModel)
    }
}

struct PersonaWelcomeCardView: View {
    var body: some View {
        WelcomeCard()
    }
}

struct PersonaWindowRowView: View {
    let window: WindowInfo

    var body: some View {
        WindowRow(window: window)
    }
}
