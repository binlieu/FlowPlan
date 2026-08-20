import Foundation
import Observation
import SwiftUI
import FlowPlanDomain

enum AppearancePreference: String, CaseIterable {
    case system
    case light
    case dark
}

@Observable
@MainActor
final class AppState {
    @ObservationIgnored @AppStorage("userName") private var storedUserName = ""
    @ObservationIgnored @AppStorage("currencyCode") private var storedCurrencyCode = "USD"
    @ObservationIgnored @AppStorage("isFaceIDEnabled") private var storedIsFaceIDEnabled = false
    @ObservationIgnored @AppStorage("isHapticsEnabled") private var storedIsHapticsEnabled = true
    @ObservationIgnored @AppStorage("carryBalanceForward") private var storedCarryBalanceForward = true
    @ObservationIgnored @AppStorage("recordAutopayAutomatically") private var storedRecordAutopayAutomatically = true
    @ObservationIgnored @AppStorage("appearancePreference") private var storedAppearancePreference: AppearancePreference = .system
    @ObservationIgnored @AppStorage("isSampleDataEnabled") private var storedIsSampleDataEnabled = false

    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date

    var selectedMonth: MonthKey

    var userName: String {
        didSet { storedUserName = userName }
    }

    var currencyCode: String {
        didSet { storedCurrencyCode = currencyCode }
    }

    var isFaceIDEnabled: Bool {
        didSet { storedIsFaceIDEnabled = isFaceIDEnabled }
    }

    var isHapticsEnabled: Bool {
        didSet { storedIsHapticsEnabled = isHapticsEnabled }
    }

    var carryBalanceForward: Bool {
        didSet { storedCarryBalanceForward = carryBalanceForward }
    }

    var recordAutopayAutomatically: Bool {
        didSet { storedRecordAutopayAutomatically = recordAutopayAutomatically }
    }

    var appearancePreference: AppearancePreference {
        didSet { storedAppearancePreference = appearancePreference }
    }

    var isSampleDataEnabled: Bool {
        didSet { storedIsSampleDataEnabled = isSampleDataEnabled }
    }

    var canGoForward: Bool {
        selectedMonth < currentMonth.adding(months: 12)
    }

    init(
        selectedMonth: MonthKey? = nil,
        calendar: Calendar = .current,
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        let defaultCurrencyCode = Locale.current.currency?.identifier ?? "USD"

        _storedUserName = AppStorage(
            wrappedValue: "",
            "userName",
            store: userDefaults
        )
        _storedCurrencyCode = AppStorage(
            wrappedValue: defaultCurrencyCode,
            "currencyCode",
            store: userDefaults
        )
        _storedIsFaceIDEnabled = AppStorage(
            wrappedValue: false,
            "isFaceIDEnabled",
            store: userDefaults
        )
        _storedIsHapticsEnabled = AppStorage(
            wrappedValue: true,
            "isHapticsEnabled",
            store: userDefaults
        )
        _storedCarryBalanceForward = AppStorage(
            wrappedValue: true,
            "carryBalanceForward",
            store: userDefaults
        )
        _storedRecordAutopayAutomatically = AppStorage(
            wrappedValue: true,
            "recordAutopayAutomatically",
            store: userDefaults
        )
        _storedAppearancePreference = AppStorage(
            wrappedValue: .system,
            "appearancePreference",
            store: userDefaults
        )
        _storedIsSampleDataEnabled = AppStorage(
            wrappedValue: false,
            "isSampleDataEnabled",
            store: userDefaults
        )

        self.calendar = calendar
        self.now = now
        self.selectedMonth = selectedMonth ?? MonthKey(date: now(), calendar: calendar)
        userName = _storedUserName.wrappedValue
        currencyCode = _storedCurrencyCode.wrappedValue
        isFaceIDEnabled = _storedIsFaceIDEnabled.wrappedValue
        isHapticsEnabled = _storedIsHapticsEnabled.wrappedValue
        carryBalanceForward = _storedCarryBalanceForward.wrappedValue
        recordAutopayAutomatically = _storedRecordAutopayAutomatically.wrappedValue
        appearancePreference = _storedAppearancePreference.wrappedValue
        isSampleDataEnabled = _storedIsSampleDataEnabled.wrappedValue
    }

    func goToPreviousMonth() {
        selectedMonth = selectedMonth.previous
    }

    func goToNextMonth() {
        guard canGoForward else {
            return
        }
        selectedMonth = selectedMonth.next
    }

    func goToCurrentMonth() {
        selectedMonth = currentMonth
    }

    private var currentMonth: MonthKey {
        MonthKey(date: now(), calendar: calendar)
    }
}
