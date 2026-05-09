import Foundation

/// Stand-in for a FamilyActivitySelection on simulator. Real device uses
/// FamilyControls' picker; this keeps our domain layer testable + sim-runnable.
struct BlockedAppGroup: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let symbol: String
    var enabled: Bool

    static let presets: [BlockedAppGroup] = [
        .init(id: "social",   title: "Social",            symbol: "bubble.left.and.bubble.right.fill", enabled: true),
        .init(id: "video",    title: "Video & Streaming", symbol: "play.rectangle.fill",                enabled: true),
        .init(id: "news",     title: "News & Doomscroll", symbol: "newspaper.fill",                     enabled: false),
        .init(id: "shopping", title: "Shopping",          symbol: "bag.fill",                           enabled: false),
        .init(id: "games",    title: "Games",             symbol: "gamecontroller.fill",                enabled: false),
        .init(id: "browser",  title: "Browsers",          symbol: "safari.fill",                        enabled: false)
    ]
}
