import SwiftData
import SwiftUI

struct AccountsSettingsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(FinanceRepository.self) private var repository

    @Query(sort: \AccountEntity.name) private var accountEntities: [AccountEntity]
    @Query private var transactions: [TransactionEntity]

    @State private var newAccountName = ""
    @State private var pendingDeletion: AccountDeletion?
    @State private var presentedError: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Accounts")

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionHeading(
                        title: "Accounts",
                        trailing: AnyView(
                            Text(accountCountLabel)
                                .rowDetailTypography()
                                .foregroundStyle(Palette.inkSecondary)
                        )
                    )
                    GroupedList(
                        accounts,
                        footer: AnyView(addAccountRow),
                        rowContent: accountRow
                    )
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
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog(
            pendingDeletion.map { "Delete \($0.account.name)?" } ?? "Delete account?",
            isPresented: deletionConfirmationPresented,
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { deletion in
            Button("Delete Account", role: .destructive) {
                delete(deletion.account)
            }
            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
        } message: { deletion in
            Text(
                "\(deletion.account.name) is used by \(deletion.transactionCount) "
                    + "transaction\(deletion.transactionCount == 1 ? "" : "s"). "
                    + "Deleting it clears the account label but keeps every transaction."
            )
        }
        .alert("Unable to update accounts", isPresented: errorPresented) {
            Button("OK", role: .cancel) {
                presentedError = nil
            }
        } message: {
            Text(presentedError ?? "The account change could not be saved.")
        }
    }

    private var addAccountRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    accountNameField
                    addAccountButton
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    accountNameField
                    addAccountButton
                }
            }
        }
        .settingsRow()
    }

    private var accountNameField: some View {
        TextField("Add an account", text: $newAccountName)
            .textContentType(.organizationName)
            .submitLabel(.done)
            .onSubmit(addAccount)
    }

    private var addAccountButton: some View {
        Button("Add", action: addAccount)
            .foregroundStyle(Palette.onAccentFill)
            .buttonStyle(.borderedProminent)
            .tint(Palette.accentFill)
            .disabled(!canAddAccount)
    }

    private func accountRow(_ account: Account) -> some View {
        ListRow(
            leading: .monogram(monogram(for: account.name)),
            title: account.name,
            subtitle: activityLabel(for: account),
            trailingAccessory: AnyView(
                Button(role: .destructive) {
                    requestDeletion(of: account)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete \(account.name)")
            ),
            contentInsets: EdgeInsets(
                top: Spacing.xxs,
                leading: Spacing.none,
                bottom: Spacing.xxs,
                trailing: Spacing.none
            ),
            combinesAccessibilityChildren: false
        )
    }

    private var accounts: [Account] {
        accountEntities
            .map { $0.toValue() }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private var accountCountLabel: String {
        "\(accounts.count) account\(accounts.count == 1 ? "" : "s")"
    }

    private var transactionCounts: [String: Int] {
        Dictionary(grouping: transactions) { transaction in
            AccountName.identity(transaction.account)
        }
        .mapValues(\.count)
    }

    private func transactionCount(for account: Account) -> Int {
        transactionCounts[AccountName.identity(account.name), default: 0]
    }

    private func activityLabel(for account: Account) -> String {
        let count = transactionCount(for: account)
        return count == 0 ? "No activity yet" : "\(count) transaction\(count == 1 ? "" : "s")"
    }

    private func monogram(for name: String) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2)).uppercased()
    }

    private var trimmedNewAccountName: String {
        newAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAddAccount: Bool {
        let identity = AccountName.identity(trimmedNewAccountName)
        return !identity.isEmpty
            && !accounts.contains { AccountName.identity($0.name) == identity }
    }

    private func addAccount() {
        guard canAddAccount else {
            return
        }

        do {
            try repository.addAccount(named: trimmedNewAccountName)
            newAccountName = ""
        } catch {
            presentedError = "The account could not be added. Please try again."
        }
    }

    private func requestDeletion(of account: Account) {
        let count = transactionCount(for: account)

        // Used accounts require a visible warning because deletion clears their transaction tags.
        if count > 0 {
            pendingDeletion = AccountDeletion(account: account, transactionCount: count)
        } else {
            delete(account)
        }
    }

    private func delete(_ account: Account) {
        do {
            try repository.deleteAccount(account)
            pendingDeletion = nil
        } catch {
            pendingDeletion = nil
            presentedError = "The account could not be deleted. Please try again."
        }
    }

    private var deletionConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { presentedError != nil },
            set: { if !$0 { presentedError = nil } }
        )
    }
}

private struct AccountDeletion: Identifiable {
    let account: Account
    let transactionCount: Int

    var id: UUID { account.id }
}

#if DEBUG
#Preview("Accounts — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            AccountsSettingsView()
        }
    }
}

#Preview("Accounts — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            AccountsSettingsView()
        }
    }
}
#endif
