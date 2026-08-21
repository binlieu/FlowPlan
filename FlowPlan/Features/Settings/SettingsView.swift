import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(ProjectionStore.self) private var projectionStore

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage(AutoLockInterval.storageKey)
    private var autoLockInterval: AutoLockInterval = .oneMinute

    private let biometricAvailability = BiometricAuthenticator().canEvaluate()

    var body: some View {
        Form {
            ScreenHeader(
                title: "Settings",
                subtitle: "PROFILE, PREFERENCES & DATA"
            )

            profileSection
            preferencesSection
            organizationSection
            dataSection
            securitySection
            aboutSection
        }
        .designSystemForm()
        .contentMargins(.top, Spacing.none, for: .scrollContent)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: appState.carryBalanceForward) {
            projectionStore.refresh()
        }
        .onChange(of: appState.recordAutopayAutomatically) {
            projectionStore.refresh()
        }
    }

    private var profileSection: some View {
        Section {
            TextField("Name", text: binding(\.userName))
                .textContentType(.name)

            Picker("Currency", selection: binding(\.currencyCode)) {
                ForEach(currencyCodes, id: \.self) { code in
                    Text(code).tag(code)
                }
            }

            LabeledContent("Region", value: regionName)
        } header: {
            Text("Profile")
                .designSystemSectionHeader()
        }
        .designSystemRows()
    }

    private var preferencesSection: some View {
        Section {
            Picker("Appearance", selection: binding(\.appearancePreference)) {
                ForEach(AppearancePreference.allCases, id: \.self) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }

            Toggle("Haptic feedback", isOn: binding(\.isHapticsEnabled))

            Toggle(isOn: binding(\.recordAutopayAutomatically)) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Record auto-pay automatically")
                    Text("Auto-pay bills and debts are recorded as spent once their due date passes.")
                        .footnoteTypography()
                        .foregroundStyle(Palette.inkSecondary)
                }
            }

            Toggle(isOn: binding(\.carryBalanceForward)) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Carry balance forward")
                    Text("Each month starts with what was left at the end of the previous one.")
                        .footnoteTypography()
                        .foregroundStyle(Palette.inkSecondary)
                }
            }

            Toggle("Notifications", isOn: $notificationsEnabled)
        } header: {
            Text("Preferences")
                .designSystemSectionHeader()
        } footer: {
            Text("Notification scheduling is not enabled in this version.")
                .designSystemSectionFooter()
        }
        .designSystemRows()
    }

    private var organizationSection: some View {
        Section {
            NavigationLink("Accounts") {
                AccountsSettingsView()
            }

            NavigationLink("Categories") {
                CategoriesSettingsView()
            }
        } header: {
            Text("Organization")
                .designSystemSectionHeader()
        }
        .designSystemRows()
    }

    private var dataSection: some View {
        Section {
            NavigationLink("Data") {
                DataSettingsView()
            }
        } header: {
            Text("Data")
                .designSystemSectionHeader()
        }
        .designSystemRows()
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
                .footnoteTypography()
                .foregroundStyle(Palette.inkSecondary)
        } header: {
            Text("Security")
                .designSystemSectionHeader()
        } footer: {
            if !isFaceIDAvailable {
                Text(biometricAvailability.explanation)
                    .designSystemSectionFooter()
            }
        }
        .designSystemRows()
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Author", value: "Simon Lieu")

            LabeledContent("Version", value: version)

            NavigationLink("Projection method") {
                ProjectionMethodView()
            }
        } header: {
            Text("About")
                .designSystemSectionHeader()
        }
        .designSystemRows()
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

        guard let shortVersion, !shortVersion.isEmpty else {
            return "Unavailable"
        }

        if let build, !build.isEmpty {
            return "\(shortVersion) (\(build))"
        }

        return shortVersion
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
            Section {
                Text("Current available balance, plus remaining expected income, minus remaining bills, spending budgets, and the remaining savings goal.")
            } header: {
                Text("Projected month-end balance")
                    .designSystemSectionHeader()
            }
            .designSystemRows()

            Section {
                Text("The plan uses the month's starting balance and planned amounts. Variance is the projected month-end balance minus the planned month-end balance.")
            } header: {
                Text("Plan comparison")
                    .designSystemSectionHeader()
            }
            .designSystemRows()

            Section {
                Text("Spendable cash is divided across the remaining days and rounded down to avoid overstating the daily amount.")
            } header: {
                Text("Safe to spend")
                    .designSystemSectionHeader()
            }
            .designSystemRows()
        }
        .designSystemList()
        .navigationTitle("Projection Method")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
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

#if DEBUG
#Preview("Settings — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            SettingsView()
        }
    }
}

#Preview("Settings — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            SettingsView()
        }
    }
}
#endif
