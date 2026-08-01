import Foundation

// Swift 5.7 (Xcode 14.2) has no `switch` expressions, so every mapping below
// returns explicitly. Keep it that way until the project moves off Xcode 14.

enum ReceiptCategory: String, CaseIterable, Codable, Identifiable {
    case shopping, groceries, food, fuel, travel, utilities, health, education, services, other

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .shopping: return "bag"
        case .groceries: return "cart"
        case .food: return "fork.knife"
        case .fuel: return "fuelpump"
        case .travel: return "airplane"
        case .utilities: return "bolt"
        case .health: return "cross.case"
        case .education: return "book"
        case .services: return "wrench.and.screwdriver"
        case .other: return "square.grid.2x2"
        }
    }

    var key: L10n.Key {
        switch self {
        case .shopping: return .categoryShopping
        case .groceries: return .categoryGroceries
        case .food: return .categoryFood
        case .fuel: return .categoryFuel
        case .travel: return .categoryTravel
        case .utilities: return .categoryUtilities
        case .health: return .categoryHealth
        case .education: return .categoryEducation
        case .services: return .categoryServices
        case .other: return .categoryOther
        }
    }
}

enum PaymentMethod: String, CaseIterable, Codable, Identifiable {
    case cash, applePay, card, bankTransfer, easypaisa, jazzcash, credit

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .cash: return "banknote"
        case .applePay: return "applelogo"
        case .card: return "creditcard"
        case .bankTransfer: return "building.columns"
        case .easypaisa, .jazzcash: return "phone.badge.waveform"
        case .credit: return "clock.arrow.circlepath"
        }
    }

    var key: L10n.Key {
        switch self {
        case .cash: return .methodCash
        case .applePay: return .methodApplePay
        case .card: return .methodCard
        case .bankTransfer: return .methodBankTransfer
        case .easypaisa: return .methodEasypaisa
        case .jazzcash: return .methodJazzcash
        case .credit: return .methodCredit
        }
    }
}

enum DiscountType: String, CaseIterable, Codable, Identifiable {
    case none, percentage, fixed

    var id: String { rawValue }

    var key: L10n.Key {
        switch self {
        case .none: return .discountNone
        case .percentage: return .discountPercentage
        case .fixed: return .discountFixed
        }
    }
}

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case urdu = "ur"

    var id: String { rawValue }

    /// Urdu is written right-to-left; the whole UI mirrors when it is selected.
    var isRightToLeft: Bool { self == .urdu }

    var displayName: String {
        switch self {
        case .english: return "ENG"
        case .urdu: return "اردو"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var key: L10n.Key {
        switch self {
        case .system: return .themeSystem
        case .light: return .themeLight
        case .dark: return .themeDark
        }
    }
}

enum DashboardPeriod: String, CaseIterable, Identifiable {
    case today, week, month, year, custom

    var id: String { rawValue }

    var key: L10n.Key {
        switch self {
        case .today: return .periodToday
        case .week: return .periodWeek
        case .month: return .periodMonth
        case .year: return .periodYear
        case .custom: return .periodCustom
        }
    }

    /// Date range for the period, or `nil` for `.custom` (the caller supplies its own).
    func range(now: Date = Date(), calendar: Calendar = .current) -> Range<Date>? {
        let component: Calendar.Component
        switch self {
        case .today: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        case .custom: return nil
        }
        guard let interval = calendar.dateInterval(of: component, for: now) else { return nil }
        return interval.start..<interval.end
    }

    /// Granularity the revenue chart buckets by for this period.
    var chartComponent: Calendar.Component {
        switch self {
        case .today: return .hour
        case .week, .month: return .day
        case .year: return .month
        case .custom: return .day
        }
    }
}
