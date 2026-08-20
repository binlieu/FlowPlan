import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("autoLockInterval") private var autoLockInterval: AutoLockInterval = .immediately

    private let biometricAvailability = BiometricAuthenticator().canEvaluate()

    var body: some View {
        Form {
            profileSection
            preferencesSection
            organizationSection
            dataSection
            securitySection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profileSection: some View {
        Section("Profile") {
            TextField("Name", text: binding(\.userName))
                .textContentType(.name)

            Picker("Currency", selection: binding(\.currencyCode)) {
                ForEach(currencyCodes, id: \.self) { code in
                    Text(code).tag(code)
                }
            }

            LabeledContent("Region", value: regionName)
        }
    }

    private var preferencesSection: some View {
        Section {
            Picker("Appearance", selection: binding(\.appearancePreference)) {
                ForEach(AppearancePreference.allCases, id: \.self) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }

            Toggle("Haptic feedback", isOn: binding(\.isHapticsEnabled))
            Toggle("Notifications", isOn: $notificationsEnabled)
        } header: {
            Text("Preferences")
        } footer: {
            Text("Notification scheduling is not enabled in this version.")
        }
    }

    private var organizationSection: some View {
        Section {
            NavigationLink("Categories") {
                CategoriesSettingsView()
            }
        }
    }

    private var dataSection: some View {
        Section {
            NavigationLink("Data") {
                DataSettingsView()
            }
        }
    }

    private var securitySection: some View {
        Section {
            Toggle("Face ID", isOn: binding(\.isFaceIDEnabled))
                .disabled(!isFaceIDAvailable)

            Picker("Auto-lock", selection: $autoLockInterval) {
                ForEach(AutoLockInterval.allCases) { interval in
                    Text(interval.title).tag(interval)
                }
            }
            .disabled(!appState.isFaceIDEnabled)

            Text("Your financial data is stored only on this device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Security")
        } footer: {
            if !isFaceIDAvailable {
                Text(biometricAvailability.explanation)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: version)

            NavigationLink("Projection method") {
                ProjectionMethodView()
            }
        }
    }

    private var currencyCodes: [String] {
        let common = ["USD", "CAD", "EUR", "GBP", "AUD", "NZD", "JPY", "CHF", "CNY", "INR"]
        return Array(Set(common + [appState.currencyCode])).sorted()
    }

    private var regionName: String {
        guard let regionCode = Locale.current.region?.identifier else {
            return "Not set"
        }
        return Locale.current.localizedString(forRegionCode: regionCode) ?? regionCode
    }

    private var isFaceIDAvailable: Bool {
        biometricAvailability.isAvailable && biometricAvailability.biometry == .faceID
    }

    private var version: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, build) {
        case let (.some(version), .some(build)):
            return "\(version) (\(build))"
        case let (.some(version), .none):
            return version
        default:
            return "1.0"
        }
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<AppState, Value>) -> Binding<Value> {
        Binding(
            get: { appState[keyPath: keyPath] },
            set: { appState[keyPath: keyPath] = $0 }
        )
    }
}

private struct ProjectionMethodView: View {
    var body: some View {
        List {
            Section("Projected month-end balance") {
                Text("Current available balance, plus remaining expected income, minus remaining bills, spending budgets, and the remaining savings goal.")
            }

            Section("Plan comparison") {
                Text("The plan uses the month's starting balance and planned amounts. Variance is the projected month-end balance minus the planned month-end balance.")
            }

            Section("Safe to spend") {
                Text("Spendable cash is divided across the remaining days and rounded down to avoid overstating the daily amount.")
            }
        }
        .navigationTitle("Projection Method")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension AppearancePreference {
    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}
