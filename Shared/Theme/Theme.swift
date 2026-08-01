import SwiftUI

/// Colour, spacing and type ramp for Cash Memer.
///
/// Every colour is defined for both appearances so the Settings → Theme picker
/// (System / Light / Dark) works without a second design pass.
enum Theme {
    // MARK: Brand

    static let brand = Color(light: 0x1B7A24, dark: 0x34A93F)
    static let brandDeep = Color(light: 0x146018, dark: 0x2A8C33)
    static let brandSoft = Color(light: 0xE3F1E1, dark: 0x1B3320)
    /// Heading green used for section titles on the receipt form.
    static let heading = Color(light: 0x2F7A28, dark: 0x5FC167)
    /// The "CASH MEMO" title on the printed memo.
    static let memoTitle = Color(light: 0x245DA6, dark: 0x6BA6E8)

    // MARK: Surfaces

    static let background = Color(light: 0xF2F2F7, dark: 0x0C0C0F)
    static let card = Color(light: 0xFFFFFF, dark: 0x1A1A1E)
    static let cardAlt = Color(light: 0xF7F8F4, dark: 0x202024)
    static let separator = Color(light: 0xE3E3E8, dark: 0x2E2E34)
    /// The memo sheet itself stays near-white in both appearances so exports match print.
    static let memoPaper = Color(light: 0xFFFFFF, dark: 0xF7F8F4)
    static let memoInk = Color(light: 0x11131A, dark: 0x11131A)

    // MARK: Text

    static let textPrimary = Color(light: 0x11131A, dark: 0xF2F2F5)
    static let textSecondary = Color(light: 0x6C6C75, dark: 0x9C9CA6)
    static let textTertiary = Color(light: 0x9A9AA2, dark: 0x6E6E78)

    // MARK: Semantic

    static let destructive = Color(light: 0xB3261E, dark: 0xF2867E)
    static let destructiveSoft = Color(light: 0xFADAD6, dark: 0x3A1B18)
    static let warning = Color(light: 0xB8760B, dark: 0xE9A83A)
    static let googleBlue = Color(light: 0x1A73E8, dark: 0x4A90E2)

    /// Accents for the Dashboard stat tiles, in the order the row renders them.
    static let statAccents: [Color] = [
        Color(light: 0x1B7A24, dark: 0x34A93F),   // Invoices
        Color(light: 0x6C6C75, dark: 0x9C9CA6),   // Top Store
        Color(light: 0x2F6FD0, dark: 0x6BA6E8),   // This Month
        Color(light: 0x8E44C7, dark: 0xB98AE6),   // Avg. Receipt
        Color(light: 0x0E9AA7, dark: 0x3FC7D4),   // Total Items
        Color(light: 0xD62E5C, dark: 0xF07A99)    // Top Category
    ]

    // MARK: Metrics

    enum Radius {
        static let card: CGFloat = 14
        static let control: CGFloat = 10
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }
}

extension Color {
    /// Hex initialiser that resolves per appearance.
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        self.init(hex: light)
        #endif
    }

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

// MARK: - Reusable surfaces

/// The rounded white panel every section on the form and dashboard sits in.
struct CardSurface: ViewModifier {
    var padding: CGFloat = Theme.Spacing.l

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

extension View {
    func cardSurface(padding: CGFloat = Theme.Spacing.l) -> some View {
        modifier(CardSurface(padding: padding))
    }

    /// Uppercase grey caption that heads each form section ("RECEIPT DETAILS").
    func sectionCaption() -> some View {
        font(.caption)
            .textCase(.uppercase)
            .foregroundStyle(Theme.textSecondary)
            .kerning(0.4)
    }
}
