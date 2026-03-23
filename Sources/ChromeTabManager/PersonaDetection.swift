import Foundation

enum UserPersona: String, CaseIterable {
    case light = "light"
    case standard = "standard"
    case power = "power"
    case superUser = "super"
    
    var icon: String {
        switch self {
        case .light: return "L"
        case .standard: return "S"
        case .power: return "P"
        case .superUser: return "SU"
        }
    }
    
    var title: String {
        switch self {
        case .light: return "Light Mode"
        case .standard: return "Standard Mode"
        case .power: return "Power User Mode"
        case .superUser: return "Super User Mode"
        }
    }
    
    var description: String {
        switch self {
        case .light:
            return "Simple, one-click cleanup for casual browsing"
        case .standard:
            return "Balanced features for most users"
        case .power:
            return "Advanced controls for heavy users"
        case .superUser:
            return "Maximum efficiency for high-volume workflows"
        }
    }
}

struct PersonaConfig {
    let showDetails: Bool
    let showSearch: Bool
    let showWindowBreakdown: Bool
    let maxDuplicatesShown: Int
    let confirmClose: Bool
    let celebration: Bool
    let bulkActions: Bool
    let oneClickClean: Bool
    let showAge: Bool
    let showUrls: Bool
    let cardStyle: CardStyle
    let showStats: Bool
    let enableQuickActions: Bool
    
    enum CardStyle {
        case simple, standard, compact, dense
    }
    
    static func forPersona(_ persona: UserPersona) -> PersonaConfig {
        switch persona {
        case .light:
            return PersonaConfig(
                showDetails: false,
                showSearch: false,
                showWindowBreakdown: false,
                maxDuplicatesShown: 5,
                confirmClose: true,
                celebration: true,
                bulkActions: false,
                oneClickClean: true,
                showAge: false,
                showUrls: false,
                cardStyle: .simple,
                showStats: false,
                enableQuickActions: false
            )
        case .standard:
            return PersonaConfig(
                showDetails: true,
                showSearch: true,
                showWindowBreakdown: true,
                maxDuplicatesShown: 20,
                confirmClose: true,
                celebration: true,
                bulkActions: true,
                oneClickClean: false,
                showAge: true,
                showUrls: true,
                cardStyle: .standard,
                showStats: true,
                enableQuickActions: true
            )
        case .power:
            return PersonaConfig(
                showDetails: true,
                showSearch: true,
                showWindowBreakdown: true,
                maxDuplicatesShown: 100,
                confirmClose: false,
                celebration: false,
                bulkActions: true,
                oneClickClean: false,
                showAge: true,
                showUrls: true,
                cardStyle: .compact,
                showStats: true,
                enableQuickActions: true
            )
        case .superUser:
            return PersonaConfig(
                showDetails: true,
                showSearch: true,
                showWindowBreakdown: true,
                maxDuplicatesShown: 1000,
                confirmClose: false,
                celebration: false,
                bulkActions: true,
                oneClickClean: false,
                showAge: true,
                showUrls: true,
                cardStyle: .dense,
                showStats: true,
                enableQuickActions: true
            )
        }
    }
}

struct UserAnalysis {
    let persona: UserPersona
    let totalTabs: Int
    let windowCount: Int
    let tabsPerWindow: Double
    let duplicateGroups: Int
    let wastedTabs: Int
    
    var icon: String { persona.icon }
    var title: String { persona.title }
    var description: String {
        switch persona {
        case .superUser:
            return "You have \(totalTabs) tabs across \(windowCount) windows! This is power-user territory."
        case .power:
            return "You have \(totalTabs) tabs in \(windowCount) windows. Advanced features unlocked."
        case .standard:
            return "You have \(totalTabs) tabs in \(windowCount) windows."
        case .light:
            return "You have \(totalTabs) tabs. Keeping it simple for you!"
        }
    }
    
    var config: PersonaConfig {
        PersonaConfig.forPersona(persona)
    }
}

func analyzeUser(tabs: [TabInfo], duplicates: [DuplicateGroup]) -> UserAnalysis {
    let totalTabs = tabs.count
    let windows = Set(tabs.map { $0.windowId })
    let windowCount = windows.count
    let tabsPerWindow = windowCount > 0 ? Double(totalTabs) / Double(windowCount) : 0
    
    let persona: UserPersona
    if totalTabs > 1000 || windowCount > 50 {
        persona = .superUser
    } else if totalTabs > 200 || windowCount > 15 {
        persona = .power
    } else if totalTabs > 50 || windowCount > 5 {
        persona = .standard
    } else {
        persona = .light
    }
    
    return UserAnalysis(
        persona: persona,
        totalTabs: totalTabs,
        windowCount: windowCount,
        tabsPerWindow: tabsPerWindow,
        duplicateGroups: duplicates.count,
        wastedTabs: duplicates.reduce(0) { result, group in result + group.wastedCount }
    )
}
