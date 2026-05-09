import UIKit

/// One place for all the lock's tactile cues. Heavy haptic on lock close,
/// rigid haptic on emergency, soft success on session end.
enum Haptics {
    static func lockShut() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.prepare(); g.impactOccurred()
    }

    static func lockOpen() {
        let g = UINotificationFeedbackGenerator()
        g.prepare(); g.notificationOccurred(.success)
    }

    static func emergency() {
        let g = UIImpactFeedbackGenerator(style: .rigid)
        g.prepare(); g.impactOccurred(intensity: 1.0)
    }

    static func tap() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare(); g.impactOccurred()
    }

    static func warning() {
        let g = UINotificationFeedbackGenerator()
        g.prepare(); g.notificationOccurred(.warning)
    }
}
