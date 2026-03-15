import SwiftUI

struct FeedBack {
    func feedback(_ weight: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback: Any? = {
            // styleは.light, .medium, heavyの３種類がある
            let generator: UIFeedbackGenerator = UIImpactFeedbackGenerator(style: weight)
            generator.prepare()
            return generator
        }()
        if let generator = impactFeedback as? UIImpactFeedbackGenerator {
            generator.impactOccurred()
        }
    }

    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}
