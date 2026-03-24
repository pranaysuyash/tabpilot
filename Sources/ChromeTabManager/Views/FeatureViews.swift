import SwiftUI

// RECOVERY-ADDON (2026-03-24):
// This file restores the original file boundary name `FeatureViews.swift`
// without replacing existing working implementations.
// Canonical implementations currently live in:
// - DuplicateViews.swift
// - MainContentView.swift
//
// These wrappers keep call sites additive-safe if any previous code referenced
// feature-oriented names.

struct FeatureDuplicateGroupView: View {
    let group: DuplicateGroup
    @ObservedObject var viewModel: TabManagerViewModel

    var body: some View {
        DuplicateGroupSection(group: group, viewModel: viewModel)
    }
}

struct FeatureSimpleDuplicateRowView: View {
    let group: DuplicateGroup

    var body: some View {
        SimpleDuplicateRow(group: group)
    }
}

struct FeatureSuperDuplicateRowView: View {
    let group: DuplicateGroup
    @ObservedObject var viewModel: TabManagerViewModel

    var body: some View {
        SuperDuplicateRow(group: group, viewModel: viewModel)
    }
}

struct FeatureMainContentView: View {
    @ObservedObject var viewModel: TabManagerViewModel

    var body: some View {
        MainContentView(viewModel: viewModel)
    }
}
