import SwiftUI

struct PaywallView: View {
    @StateObject private var licenseManager = LicenseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)
                
                Text(PaywallCopy.title)
                    .font(.largeTitle.bold())
                
                Text(PaywallCopy.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // Pricing
            Text(PaywallCopy.price)
                .font(.title2.bold())
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            // Features
            VStack(alignment: .leading, spacing: 12) {
                ForEach(PaywallCopy.features, id: \.self) { feature in
                    Label(feature, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    Task {
                        let success = await licenseManager.purchaseLicense()
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    if licenseManager.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(PaywallCopy.callToAction)
                            .font(.headline)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(licenseManager.isLoading)
                
                Button {
                    Task {
                        let restored = await licenseManager.restorePurchases()
                        if restored {
                            dismiss()
                        }
                    }
                } label: {
                    Text("Restore Purchases")
                }
                .buttonStyle(.plain)
                .disabled(licenseManager.isLoading)
                
                Button {
                    dismiss()
                } label: {
                    Text("Maybe Later")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(40)
        .frame(width: 500, height: 600)
    }
}
