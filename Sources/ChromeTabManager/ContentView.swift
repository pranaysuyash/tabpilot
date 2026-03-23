import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: TabManagerViewModel

    init(viewModel: TabManagerViewModel = TabViewModelBuilder().build()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .frame(minWidth: 280)
        } detail: {
            MainContentView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $viewModel.showPreferences) {
            PreferencesView(viewModel: viewModel)
        }
        .toolbar {
            AppToolbarContent(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(viewModel.confirmationTitle, isPresented: $viewModel.showConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelConfirmation()
            }
            Button("Close", role: .destructive) {
                Task { await viewModel.executeConfirmation() }
            }
        } message: {
            Text(viewModel.confirmationMessage)
        }
        .overlay(
            ZStack {
                ToastView(message: viewModel.toastMessage, isShowing: viewModel.showToast)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.showToast)
                
                // Undo bar
                if viewModel.licenseManager.isLicensed && viewModel.canUndo {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 12) {
                                Text(viewModel.undoMessage)
                                    .font(.subheadline)
                                
                                Button {
                                    Task { await viewModel.undoLastClose() }
                                } label: {
                                    Label("Undo", systemImage: "arrow.uturn.backward")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                
                                Button {
                                    viewModel.dismissUndo()
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                            .background(Color(.windowBackgroundColor))
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom))
                }
            }
        )
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
