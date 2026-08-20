import SwiftData
import SwiftUI

struct AccountsSettingsView: View {
    @Environment(FinanceRepository.self) private var repository

    @Query(sort: \AccountEntity.name) private var accountEntities: [AccountEntity]
    @Query private var transactions: [TransactionEntity]

    @State private var newAccountName = ""
    @State private var pendingDeletion: AccountDeletion?
    @State private var presentedError: String?

    var body: some View {
        List {
            Section {
                ForEach(accounts) { account in
                    accountRow(account)
                }

                HStack(spacing: 12) {
                    TextField("Add an account", text: $newAccountName)
                        .textContentType(.organizationName)
                        .submitLabel(.done)
                        .onSubmit(addAccount)

                    Button("Add", action: addAccount)
                        .foregroundStyle(Palette.onAccentFill)
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.accentFill)
                        .disabled(!canAddAccount)
                }
            } header: {
                HStack {
                    Text("ACCOUNTS")
                    Spacer()
                    Text(accountCountLabel)
                        .textCase(nil)
                }
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
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

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 14) {
            Text(monogram(for: account.name))
                .smallCapsTypography()
                .foregroundStyle(Palette.accent)
                .frame(width: 54, height: 54)
                .overlay {
                    Rectangle().stroke(Palette.hairline, lineWidth: 1)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(account.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.ink)

                Text(activityLabel(for: account))
                    .font(Typography.supporting)
                    .foregroundStyle(Palette.inkSecondary)
            }

            Spacer(minLength: 8)

            Button(role: .destructive) {
                requestDeletion(of: account)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete \(account.name)")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
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
#Preview("Accounts") {
    FlowPlanPreviewHost {
        NavigationStack {
            AccountsSettingsView()
        }
    }
}
#endif
