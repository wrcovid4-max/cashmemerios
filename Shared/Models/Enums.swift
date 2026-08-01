import Foundation

enum ReceiptCategory: String, CaseIterable, Codable, Identifiable {
    case shopping, groceries, food, fuel, travel, utilities, health, education, services, other

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .shopping: "bag"
        case .groceries: "cart"
        case .food: "fork.knife"
        case .fuel: "fuelpump"
        case .travel: "airplane"
        case .utilities: "bolt"
        case .health: "cross.case"
        case .education: "book"
        case .services: "wrench.and.screwdriver"
        case .other: "square.grid.2x2"
        }
    }

    var key: L10n.Key {
        switch self {
        case .shopping: .categoryShopping
        case .groceries: .categoryGroceries
        case .food: .categoryFood
        case .fuel: .categoryFuel
        case .travel: .categoryTravel
        case .utilities: .categoryUtilities
        case .health: .categoryHealth
        case .education: .categoryEducation
        case .services: .categoryServices
        case .other: .categoryOther
        }
    }
}

enum PaymentMethod: String, CaseIterable, Codable, Identifiable {
    case cash, applePay, card, bankTransfer, easypaisa, jazzcash, credit

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .cash: "banknote"
        case .applePay: "applelogo"
        case .card: "creditcard"
        case .bankTransfer: "building.columns"
        case .easypaisa, .jazzcash: "phone.badge.waveform"
        case .credit: "clock.arrow.circlepath"
        }
    }

    var key: L10n.Key {
        switch self {
        case .cash: .methodCash
        case .applePay: .methodApplePay
        case .card: .methodCard
        case .bankTransfer: .methodBankTransfer
        case .easypaisa: .methodEasypaisa
        case .jazzcash: .methodJazzcash
        case .credit: .methodCredit
        }
    }
}

enum DiscountType: String, CaseIterable, Codable, Identifiable {
    case none, percentage, fixed

    var id: String { rawValue }

    var key: L10n.Key {
        switch self {
        case .none: .discountNone
        case .percentage: .discountPercentage
        case .fixed: .discountFixed
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
        case .english: "ENG"
        case .urdu: "اردو"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var key: L10n.Key {
        switch self {
        case .system: .themeSystem
        case .light: .themeLight
        case .dark: .themeDark
        }
    }
}

enum DashboardPeriod: String, CaseIterable, Identifiable {
    case today, week, month, year, custom

    var id: String { rawValue }

    var key: L10n.Key {
        switch self {
        case .today: .periodToday
        case .week: .periodWeek
        case .month: .periodMonth
        case .year: .periodYear
        case .custom: .periodCustom
        }
    }

    /// Date range for the period, or `nil` for `.custom` (the caller supplies its own).
    func range(now: Date = .now, calendar: Calendar = .current) -> ClosedRange<Date>? {
        let component: Calendar.Component
        switch self {
        case .today: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        case .custom: return nil
        }
        guard let interval = calendar.dateInterval(of: component, for: now) else { return nil }
        return interval.start...interval.end
    }
}
