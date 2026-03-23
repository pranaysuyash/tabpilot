import Foundation
import SwiftUI

actor DIContainer {
    static let shared = DIContainer()

    private var dependencies: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]

    private init() {}

    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        dependencies[key] = instance
    }

    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }

    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)

        if let instance = dependencies[key] as? T {
            return instance
        }

        if let factory = factories[key], let instance = factory() as? T {
            dependencies[key] = instance
            return instance
        }

        fatalError("Dependency \(type) not registered")
    }

    func resolve<T>(_ type: T.Type, default defaultValue: T) -> T {
        let key = String(describing: type)

        if let instance = dependencies[key] as? T {
            return instance
        }

        if let factory = factories[key], let instance = factory() as? T {
            dependencies[key] = instance
            return instance
        }

        return defaultValue
    }

    func create<T>(_ type: T.Type) -> T {
        let key = String(describing: type)

        guard let factory = factories[key], let instance = factory() as? T else {
            fatalError("Factory for \(type) not registered")
        }

        return instance
    }

    func reset() {
        dependencies.removeAll()
        factories.removeAll()
    }
}

private struct DIContainerKey: EnvironmentKey {
    static let defaultValue: DIContainer = .shared
}

extension EnvironmentValues {
    var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}
