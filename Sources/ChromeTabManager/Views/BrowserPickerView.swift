import SwiftUI

struct BrowserPickerView: View {
    @ObservedObject var viewModel: TabManagerViewModel

    var body: some View {
        Picker("Browser", selection: $viewModel.selectedBrowser) {
            ForEach(Browser.allCases, id: \.self) { browser in
                HStack {
                    Image(systemName: browserIcon(for: browser))
                    Text(browser.rawValue)
                    if viewModel.browserStatuses[browser] == true {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 8))
                    }
                }
                .tag(browser)
            }
        }
        .pickerStyle(.menu)
        .task {
            await viewModel.refreshBrowserStatuses()
        }
    }

    private func browserIcon(for browser: Browser) -> String {
        switch browser {
        case .chrome: return "globe"
        case .arc:    return "a.circle"
        case .edge:   return "e.circle"
        case .brave:  return "b.circle"
        case .vivaldi: return "v.circle"
        }
    }
}
