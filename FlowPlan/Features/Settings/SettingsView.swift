import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(ProjectionStore.self) private var projectionStore

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage(AutoLockInterval.storageKey)
    private var autoLockInterval: AutoLockInterval = .oneMinute

    private let biometricAvailability = BiometricAuthenticator().canEvaluate()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(
                    title: "Settings",
                    subtitle: "PROFILE, PREFERENCES & DATA"
                )

                Group {
                    profileSection
                    preferencesSection
                    organizationSection
                    dataSection
                    securitySection
                    aboutSection
                }
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.background)
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeading(title: "Profile")
            GroupedList(0..<3, rowContent: profileRow)
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeading(title: "Preferences")
            GroupedList(0..<5, rowContent: preferenceRow)
            SettingsSectionFooter(
                text: "Notification scheduling is not enabled in this version."
            )
        }
    }

    private var organizationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeading(title: "Organization")
            GroupedList(0..<2, rowContent: organizationRow)
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeading(title: "Data")
            GroupedList(0..<1) { _ in
                NavigationLink {
                    DataSettingsView()
                } label: {
                    SettingsNavigationRow(title: "Data")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeading(title: "Security")
            GroupedList(0..<3, rowContent: securityRow)

            if !isFaceIDAvailable {
                SettingsSectionFooter(text: biometricAvailability.explanation)
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeading(title: "About")
            GroupedList(0..<3, rowContent: aboutRow)
        }
    }

    @ViewBuilder
    private func profileRow(_ row: Int) -> some View {
        switch row {
        case 0:
            TextField("Name", text: binding(\.userName))
                .textContentType(.name)
                .settingsRow()
        case 1:
            // A menu Picker outside a Form renders only its selected value, so the label is
            // laid out here. Form used to supply this; ScrollView does not.
            settingsPickerRow("Currency") {
                Picker("Currency", selection: binding(\.currencyCode)) {
                    ForEach(currencyCodes, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
            }
            .settingsRow()
        case 2:
            LabeledContent("Region", value: regionName)
                .settingsRow()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func preferenceRow(_ row: Int) -> some View {
        switch row {
        case 0:
            settingsPickerRow("Appearance") {
                Picker("Appearance", selection: binding(\.appearancePreference)) {
                    ForEach(AppearancePreference.allCases, id: \.self) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
            }
            .settingsRow()
        case 1:
            Toggle("Haptic feedback", isOn: binding(\.isHapticsEnabled))
                .settingsRow()
        case 2:
            Toggle(isOn: binding(\.recordAutopayAutomatically)) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Record auto-pay automatically")
                    Text("Auto-pay bills and debts are recorded as spent once their due date passes.")
                        .footnoteTypography()
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .settingsRow()
        case 3:
            Toggle(isOn: binding(\.carryBalanceForward)) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Carry balance forward")
                    Text("Each month starts with what was left at the end of the previous one.")
                        .footnoteTypography()
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .settingsRow()
        case 4:
            Toggle("Notifications", isOn: $notificationsEnabled)
                .settingsRow()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func organizationRow(_ row: Int) -> some View {
        switch row {
        case 0:
            NavigationLink {
                AccountsSettingsView()
            } label: {
                SettingsNavigationRow(title: "Accounts")
            }
            .buttonStyle(.plain)
        case 1:
            NavigationLink {
                CategoriesSettingsView()
            } label: {
                SettingsNavigationRow(title: "Categories")
            }
            .buttonStyle(.plain)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func securityRow(_ row: Int) -> some View {
        switch row {
        case 0:
            Toggle("Face ID", isOn: binding(\.isFaceIDEnabled))
                .disabled(!isFaceIDAvailable)
                .settingsRow()
        case 1:
            Picker("Auto-lock", selection: $autoLockInterval) {
                ForEach(AutoLockInterval.allCases) { interval in
                    Text(interval.title).tag(interval)
                }
            }
            .pickerStyle(.menu)
            .disabled(!appState.isFaceIDEnabled)
            .settingsRow()
        case 2:
            Text("Your financial data is stored only on this device.")
                .footnoteTypography()
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .settingsRow()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func aboutRow(_ row: Int) -> some View {
        switch row {
        case 0:
            LabeledContent("Author", value: "Simon Lieu")
                .settingsRow()
        case 1:
            LabeledContent("Version", value: version)
                .settingsRow()
        case 2:
            NavigationLink {
                ProjectionMethodView()
            } label: {
                SettingsNavigationRow(title: "Projection method")
            }
            .buttonStyle(.plain)
        default:
            EmptyView()
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

/// Lays out a menu picker as label-on-the-left, value-on-the-right. `Form` provided this for
/// free; outside one a menu `Picker` renders only its selected value, which silently dropped the
/// "Currency" and "Appearance" labels when Settings moved to a ScrollView.
private func settingsPickerRow<P: View>(
    _ label: String,
    @ViewBuilder picker: () -> P
) -> some View {
    HStack(spacing: Spacing.sm) {
        Text(label)
        Spacer(minLength: Spacing.sm)
        picker()
            .pickerStyle(.menu)
            .labelsHidden()
    }
}

private struct ProjectionMethodView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Projection Method")

                Group {
                    explanationSection(
                        title: "Projected month-end balance",
                        text: "Current available balance, plus remaining expected income, minus remaining bills, spending budgets, and the remaining savings goal."
                    )
                    explanationSection(
                        title: "Plan comparison",
                        text: "The plan uses the month's starting balance and planned amounts. Variance is the projected month-end balance minus the planned month-end balance."
                    )
                    explanationSection(
                        title: "Safe to spend",
                        text: "Spendable cash is divided across the remaining days and rounded down to avoid overstating the daily amount."
                    )
                }
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.background)
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func explanationSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeading(title: title)
            GroupedList(0..<1) { _ in
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
                    .settingsRow()
            }
        }
    }
}

struct SettingsNavigationRow: View {
    let title: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Spacing.sm)

            Image(systemName: "chevron.right")
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityHidden(true)
        }
        .settingsRow()
    }
}

struct SettingsSectionFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .footnoteTypography()
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.md)
    }
}

private struct SettingsRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
    }
}

extension View {
    func settingsRow() -> some View {
        modifier(SettingsRowStyle())
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
