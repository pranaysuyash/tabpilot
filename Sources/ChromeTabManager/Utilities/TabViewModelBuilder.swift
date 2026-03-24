import Foundation

typealias TabManagerViewModel = AppViewModel
typealias TabViewModel = AppViewModel

final class TabViewModelBuilder {
    @MainActor
    func build() -> AppViewModel {
        return AppViewModel()
    }
}
