import UIKit

/// Shows the Halloween app icon when Holiday.halloween is on, the normal icon otherwise.
enum AppIconSwitcher {
    static func apply() {
        let wanted: String? = Holiday.halloween ? "HalloweenIcon" : nil
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != wanted else { return }
        UIApplication.shared.setAlternateIconName(wanted) { _ in }
    }
}
