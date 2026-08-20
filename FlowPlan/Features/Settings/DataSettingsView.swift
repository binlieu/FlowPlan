import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import FlowPlanDomain

struct DataSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(ProjectionStore.self) private var projectionStore

    @Query private var transactions: [TransactionEntity]
    @Query private var incomeSources: [IncomeSourceEntity]
    @Query private var bills: [RecurringBillEntity]
    @Query private var debts: [DebtEntity]
    @Query private var autoRecordExclusions: [AutoRecordExclusionEntity]
    @Query private var budgets: [BudgetEntity]
    @Query private var savingsGoals: [SavingsGoalEntity]
    @Query private var monthSettings: [MonthSettingsEntity]

    @State private var exportURL: URL?
    @State private var isPickingImport = false
    @State private var pendingImport: PendingImport?
    @State private var isShowingEraseConfirmation = false
    @State private var eraseConfirmation = ""
    @State private var presentedError: String?

    var body: some View {
        Form {
            Section {
                if let exportURL {
                    ShareLink(
                        item: exportURL,
                        preview: SharePreview(
                            "FlowPlan Data",
                            image: Image(systemName: "doc.text")
                        )
                    ) {
                        Label("Export all data as JSON", systemImage: "square.and.arrow.up")
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text("Preparing export…")
                    }
                }

                Button {
                    isPickingImport = true
                } label: {
                    Label("Import JSON file", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Transfer")
            } footer: {
                Text("Money values are exported as decimal strings so no precision is lost.")
            }

            Section {
                Toggle("Load sample data", isOn: sampleDataBinding)
            } header: {
                Text("Development Data")
            } footer: {
                Text("Turning this on adds the built-in sample records once. Turning it off does not delete records.")
            }

            Section {
                Button("Erase all data", role: .destructive) {
                    eraseConfirmation = ""
                    isShowingEraseConfirmation = true
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("This permanently removes every financial record from this device.")
            }
        }
        .navigationTitle("Data")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            prepareExport()
        }
        .fileImporter(
            isPresented: $isPickingImport,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handlePickedFile(result)
        }
        .alert("Import data?", isPresented: importConfirmationPresented) {
            Button("Cancel", role: .cancel) {
                pendingImport = nil
            }
            Button("Import") {
                importPendingData()
            }
        } message: {
            let count = pendingImport?.recordCount ?? 0
            Text("\(count) new record\(count == 1 ? "" : "s") will be added. Existing records with matching IDs will be left unchanged.")
        }
        .alert("Erase all data?", isPresented: $isShowingEraseConfirmation) {
            TextField("Type ERASE", text: $eraseConfirmation)
                .textInputAutocapitalization(.characters)
            Button("Cancel", role: .cancel) {
                eraseConfirmation = ""
            }
            Button("Erase", role: .destructive) {
                eraseAllData()
            }
            .disabled(eraseConfirmation != "ERASE")
        } message: {
            Text("Type ERASE to permanently remove all financial records from this device.")
        }
        .alert("Data operation failed", isPresented: errorPresented) {
            Button("OK", role: .cancel) {
                presentedError = nil
            }
        } message: {
            Text(presentedError ?? "The data operation could not be completed.")
        }
    }

    private var sampleDataBinding: Binding<Bool> {
        Binding(
            get: { appState.isSampleDataEnabled },
            set: { enabled in
                appState.isSampleDataEnabled = enabled
                if enabled {
                    loadSampleData()
                }
            }
        )
    }

    private func prepareExport() {
        do {
            let payload = FlowPlanExport(
                transactions: transactions.map(TransactionRecord.init),
                incomeSources: incomeSources.map(IncomeSourceRecord.init),
                bills: bills.map(BillRecord.init),
                debts: debts.map(DebtRecord.init),
                autoRecordExclusions: autoRecordExclusions.map(AutoRecordExclusionRecord.init),
                budgets: budgets.map(BudgetRecord.init),
                savingsGoals: savingsGoals.map(SavingsGoalRecord.init),
                monthSettings: monthSettings.map(MonthSettingsRecord.init)
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("FlowPlan-Export-\(UUID().uuidString)")
                .appendingPathExtension("json")
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            exportURL = nil
            presentedError = "The export file could not be prepared."
        }
    }

    private func handlePickedFile(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else {
                throw DataSettingsError.missingFile
            }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(FlowPlanExport.self, from: data)
            try payload.validate()
            pendingImport = PendingImport(
                payload: payload,
                recordCount: numberOfNewRecords(in: payload)
            )
        } catch {
            presentedError = "Choose a FlowPlan JSON export with valid records and decimal values."
        }
    }

    private func numberOfNewRecords(in payload: FlowPlanExport) -> Int {
        var transactionIDs = Set(transactions.map(\.id))
        var incomeIDs = Set(incomeSources.map(\.id))
        var billIDs = Set(bills.map(\.id))
        var debtIDs = Set(debts.map(\.id))
        var exclusionIDs = Set(autoRecordExclusions.map(\.id))
        var budgetIDs = Set(budgets.map(\.id))
        var savingsIDs = Set(savingsGoals.map(\.id))
        var settingIDs = Set(monthSettings.map(\.id))
        var months = Set(monthSettings.map { MonthIdentifier(year: $0.year, month: $0.month) })
        var count = 0

        count += payload.transactions.count { transactionIDs.insert($0.id).inserted }
        count += payload.incomeSources.count { incomeIDs.insert($0.id).inserted }
        count += payload.bills.count { billIDs.insert($0.id).inserted }
        count += payload.debts.count { debtIDs.insert($0.id).inserted }
        count += payload.autoRecordExclusions.count { exclusionIDs.insert($0.id).inserted }
        count += payload.budgets.count { budgetIDs.insert($0.id).inserted }
        count += payload.savingsGoals.count { savingsIDs.insert($0.id).inserted }
        count += payload.monthSettings.count { record in
            let isNewID = settingIDs.insert(record.id).inserted
            let isNewMonth = months.insert(MonthIdentifier(year: record.year, month: record.month)).inserted
            return isNewID && isNewMonth
        }
        return count
    }

    private func importPendingData() {
        guard let payload = pendingImport?.payload else {
            return
        }

        do {
            var transactionIDs = Set(transactions.map(\.id))
            var incomeIDs = Set(incomeSources.map(\.id))
            var billIDs = Set(bills.map(\.id))
            var debtIDs = Set(debts.map(\.id))
            var exclusionIDs = Set(autoRecordExclusions.map(\.id))
            var budgetIDs = Set(budgets.map(\.id))
            var savingsIDs = Set(savingsGoals.map(\.id))
            var settingIDs = Set(monthSettings.map(\.id))
            var months = Set(monthSettings.map { MonthIdentifier(year: $0.year, month: $0.month) })
            var importedEntities: [any PersistentModel] = []

            for record in payload.transactions where transactionIDs.insert(record.id).inserted {
                importedEntities.append(try record.entity())
            }
            for record in payload.incomeSources where incomeIDs.insert(record.id).inserted {
                importedEntities.append(try record.entity())
            }
            for record in payload.bills where billIDs.insert(record.id).inserted {
                importedEntities.append(try record.entity())
            }
            for record in payload.debts where debtIDs.insert(record.id).inserted {
                importedEntities.append(try record.entity())
            }
            for record in payload.autoRecordExclusions
                where exclusionIDs.insert(record.id).inserted {
                importedEntities.append(try record.entity())
            }
            for record in payload.budgets where budgetIDs.insert(record.id).inserted {
                importedEntities.append(try record.entity())
            }
            for record in payload.savingsGoals where savingsIDs.insert(record.id).inserted {
                importedEntities.append(try record.entity())
            }
            for record in payload.monthSettings where settingIDs.insert(record.id).inserted {
                let identifier = MonthIdentifier(year: record.year, month: record.month)
                guard months.insert(identifier).inserted else {
                    continue
                }
                importedEntities.append(try record.entity())
            }
            for entity in importedEntities {
                modelContext.insert(entity)
            }

            try modelContext.save()
            pendingImport = nil
            projectionStore.refresh()
            prepareExport()
        } catch {
            modelContext.rollback()
            presentedError = "No data was imported because one or more records were invalid."
        }
    }

    private func loadSampleData() {
        do {
            try SampleData.seed(into: modelContext, calendar: .current)
            if appState.userName.isEmpty { appState.userName = SampleData.personaName }
            projectionStore.refresh()
            prepareExport()
        } catch {
            modelContext.rollback()
            appState.isSampleDataEnabled = false
            presentedError = "Sample data could not be loaded."
        }
    }

    private func eraseAllData() {
        guard eraseConfirmation == "ERASE" else {
            return
        }

        do {
            transactions.forEach(modelContext.delete)
            incomeSources.forEach(modelContext.delete)
            bills.forEach(modelContext.delete)
            debts.forEach(modelContext.delete)
            autoRecordExclusions.forEach(modelContext.delete)
            budgets.forEach(modelContext.delete)
            savingsGoals.forEach(modelContext.delete)
            monthSettings.forEach(modelContext.delete)
            try modelContext.save()
            eraseConfirmation = ""
            appState.isSampleDataEnabled = false
            if appState.userName == SampleData.personaName { appState.userName = "" }
            projectionStore.refresh()
            prepareExport()
        } catch {
            modelContext.rollback()
            presentedError = "The records could not be erased."
        }
    }

    private var importConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingImport != nil },
            set: { if !$0 { pendingImport = nil } }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { presentedError != nil },
            set: { if !$0 { presentedError = nil } }
        )
    }
}

private struct PendingImport {
    let payload: FlowPlanExport
    let recordCount: Int
}

private struct MonthIdentifier: Hashable {
    let year: Int
    let month: Int
}

private enum DataSettingsError: Error {
    case invalidDecimal
    case invalidEnum
    case missingFile
}

private struct FlowPlanExport: Codable {
    let schemaVersion: Int
    let transactions: [TransactionRecord]
    let incomeSources: [IncomeSourceRecord]
    let bills: [BillRecord]
    let debts: [DebtRecord]
    let autoRecordExclusions: [AutoRecordExclusionRecord]
    let budgets: [BudgetRecord]
    let savingsGoals: [SavingsGoalRecord]
    let monthSettings: [MonthSettingsRecord]

    init(
        transactions: [TransactionRecord],
        incomeSources: [IncomeSourceRecord],
        bills: [BillRecord],
        debts: [DebtRecord],
        autoRecordExclusions: [AutoRecordExclusionRecord],
        budgets: [BudgetRecord],
        savingsGoals: [SavingsGoalRecord],
        monthSettings: [MonthSettingsRecord]
    ) {
        schemaVersion = 1
        self.transactions = transactions
        self.incomeSources = incomeSources
        self.bills = bills
        self.debts = debts
        self.autoRecordExclusions = autoRecordExclusions
        self.budgets = budgets
        self.savingsGoals = savingsGoals
        self.monthSettings = monthSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        transactions = try container.decode([TransactionRecord].self, forKey: .transactions)
        incomeSources = try container.decode([IncomeSourceRecord].self, forKey: .incomeSources)
        bills = try container.decode([BillRecord].self, forKey: .bills)
        debts = try container.decodeIfPresent([DebtRecord].self, forKey: .debts) ?? []
        autoRecordExclusions = try container.decodeIfPresent(
            [AutoRecordExclusionRecord].self,
            forKey: .autoRecordExclusions
        ) ?? []
        budgets = try container.decode([BudgetRecord].self, forKey: .budgets)
        savingsGoals = try container.decode([SavingsGoalRecord].self, forKey: .savingsGoals)
        monthSettings = try container.decode([MonthSettingsRecord].self, forKey: .monthSettings)
    }

    func validate() throws {
        guard schemaVersion == 1 else {
            throw DataSettingsError.invalidEnum
        }

        let values = transactions.map(\.amount)
            + incomeSources.map(\.expectedAmount)
            + bills.map(\.amount)
            + debts.flatMap {
                [$0.currentBalance, $0.originalBalance, $0.annualInterestRate, $0.monthlyPayment]
            }
            + budgets.map(\.monthlyLimit)
            + savingsGoals.flatMap { [$0.targetAmount, $0.monthlyTarget, $0.currentAmount] }
            + monthSettings.map(\.startingBalance)
        guard values.allSatisfy({ $0.decimal != nil }) else {
            throw DataSettingsError.invalidDecimal
        }

        _ = try transactions.map { try $0.entity() }
        _ = try incomeSources.map { try $0.entity() }
        _ = try bills.map { try $0.entity() }
        _ = try debts.map { try $0.entity() }
        _ = try autoRecordExclusions.map { try $0.entity() }
        _ = try budgets.map { try $0.entity() }
        _ = try savingsGoals.map { try $0.entity() }
        _ = try monthSettings.map { try $0.entity() }
    }
}

// Decimal values deliberately encode through this wrapper as JSON strings, never binary floats.
private struct DecimalValue: Codable {
    let value: String

    init(_ decimal: Decimal) {
        value = NSDecimalNumber(decimal: decimal).stringValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    var decimal: Decimal? {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }
}

private struct TransactionRecord: Codable {
    let id: UUID
    let date: Date
    let amount: DecimalValue
    let type: String
    let category: String
    let detail: String
    let note: String
    let account: String
    let settlesBillID: UUID?
    let settlesDebtID: UUID?
    let settlesIncomeID: UUID?
    let isAutoRecorded: Bool?
    let createdAt: Date
    let updatedAt: Date

    init(_ entity: TransactionEntity) {
        id = entity.id
        date = entity.date
        amount = DecimalValue(entity.amount)
        type = entity.typeRaw
        category = entity.category
        detail = entity.detail
        note = entity.note
        account = entity.account
        settlesBillID = entity.settlesBillID
        settlesDebtID = entity.settlesDebtID
        settlesIncomeID = entity.settlesIncomeID
        isAutoRecorded = entity.isAutoRecorded
        createdAt = entity.createdAt
        updatedAt = entity.updatedAt
    }

    func entity() throws -> TransactionEntity {
        guard let amount = amount.decimal, let type = TransactionType(rawValue: type) else {
            throw DataSettingsError.invalidEnum
        }
        return TransactionEntity(
            id: id,
            date: date,
            amount: amount,
            type: type,
            category: category,
            detail: detail,
            note: note,
            account: account,
            settlesBillID: settlesBillID,
            settlesDebtID: settlesDebtID,
            settlesIncomeID: settlesIncomeID,
            isAutoRecorded: isAutoRecorded ?? false,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct DebtRecord: Codable {
    let id: UUID
    let name: String
    let currentBalance: DecimalValue
    let originalBalance: DecimalValue
    let annualInterestRate: DecimalValue
    let monthlyPayment: DecimalValue
    let category: String
    let firstPaymentYear: Int?
    let firstPaymentMonthNumber: Int?
    let dueDay: Int?
    let isAutoPay: Bool?
    let isPaidThroughBills: Bool
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    init(_ entity: DebtEntity) {
        id = entity.id
        name = entity.name
        currentBalance = DecimalValue(entity.currentBalance)
        originalBalance = DecimalValue(entity.originalBalance)
        annualInterestRate = DecimalValue(entity.annualInterestRate)
        monthlyPayment = DecimalValue(entity.monthlyPayment)
        category = entity.category
        firstPaymentYear = entity.firstPaymentYear
        firstPaymentMonthNumber = entity.firstPaymentMonthNumber
        dueDay = entity.dueDay
        isAutoPay = entity.isAutoPay
        isPaidThroughBills = entity.isPaidThroughBills
        isActive = entity.isActive
        createdAt = entity.createdAt
        updatedAt = entity.updatedAt
    }

    func entity() throws -> DebtEntity {
        guard
            let currentBalance = currentBalance.decimal,
            let originalBalance = originalBalance.decimal,
            let annualInterestRate = annualInterestRate.decimal,
            let monthlyPayment = monthlyPayment.decimal
        else {
            throw DataSettingsError.invalidDecimal
        }

        return DebtEntity(
            id: id,
            name: name,
            currentBalance: currentBalance,
            originalBalance: originalBalance,
            annualInterestRate: annualInterestRate,
            monthlyPayment: monthlyPayment,
            category: category,
            firstPaymentMonth: firstPaymentMonth,
            dueDay: dueDay ?? 1,
            isAutoPay: isAutoPay ?? false,
            isPaidThroughBills: isPaidThroughBills,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private var firstPaymentMonth: MonthKey? {
        guard let firstPaymentYear, let firstPaymentMonthNumber else {
            return nil
        }

        return MonthKey(year: firstPaymentYear, month: firstPaymentMonthNumber)
    }
}

private struct AutoRecordExclusionRecord: Codable {
    let id: UUID
    let kind: String
    let sourceID: UUID
    let occurrenceDate: Date
    let createdAt: Date

    init(_ entity: AutoRecordExclusionEntity) {
        id = entity.id
        kind = entity.kindRaw
        sourceID = entity.sourceID
        occurrenceDate = entity.occurrenceDate
        createdAt = entity.createdAt
    }

    func entity() throws -> AutoRecordExclusionEntity {
        guard let kind = AutoRecordExclusionKind(rawValue: kind) else {
            throw DataSettingsError.invalidEnum
        }

        return AutoRecordExclusionEntity(
            id: id,
            kind: kind,
            sourceID: sourceID,
            occurrenceDate: occurrenceDate,
            createdAt: createdAt
        )
    }
}

private struct IncomeSourceRecord: Codable {
    let id: UUID
    let name: String
    let expectedAmount: DecimalValue
    let frequency: String
    let anchorDate: Date
    let endDate: Date?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    init(_ entity: IncomeSourceEntity) {
        id = entity.id
        name = entity.name
        expectedAmount = DecimalValue(entity.expectedAmount)
        frequency = entity.frequencyRaw
        anchorDate = entity.anchorDate
        endDate = entity.endDate
        isActive = entity.isActive
        createdAt = entity.createdAt
        updatedAt = entity.updatedAt
    }

    func entity() throws -> IncomeSourceEntity {
        guard
            let expectedAmount = expectedAmount.decimal,
            let frequency = RecurrenceFrequency(rawValue: frequency)
        else {
            throw DataSettingsError.invalidEnum
        }
        return IncomeSourceEntity(
            id: id,
            name: name,
            expectedAmount: expectedAmount,
            frequency: frequency,
            anchorDate: anchorDate,
            endDate: endDate,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct BillRecord: Codable {
    let id: UUID
    let name: String
    let amount: DecimalValue
    let amountType: String
    let category: String
    let frequency: String
    let anchorDate: Date
    let endDate: Date?
    let isAutoPay: Bool
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    init(_ entity: RecurringBillEntity) {
        id = entity.id
        name = entity.name
        amount = DecimalValue(entity.amount)
        amountType = entity.amountTypeRaw
        category = entity.category
        frequency = entity.frequencyRaw
        anchorDate = entity.anchorDate
        endDate = entity.endDate
        isAutoPay = entity.isAutoPay
        isActive = entity.isActive
        createdAt = entity.createdAt
        updatedAt = entity.updatedAt
    }

    func entity() throws -> RecurringBillEntity {
        guard
            let amount = amount.decimal,
            let amountType = BillAmountType(rawValue: amountType),
            let frequency = RecurrenceFrequency(rawValue: frequency)
        else {
            throw DataSettingsError.invalidEnum
        }
        return RecurringBillEntity(
            id: id,
            name: name,
            amount: amount,
            amountType: amountType,
            category: category,
            frequency: frequency,
            anchorDate: anchorDate,
            endDate: endDate,
            isAutoPay: isAutoPay,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct BudgetRecord: Codable {
    let id: UUID
    let category: String
    let monthlyLimit: DecimalValue
    let scopeYear: Int?
    let scopeMonth: Int?
    let createdAt: Date
    let updatedAt: Date

    init(_ entity: BudgetEntity) {
        id = entity.id
        category = entity.category
        monthlyLimit = DecimalValue(entity.monthlyLimit)
        scopeYear = entity.scopeYear
        scopeMonth = entity.scopeMonth
        createdAt = entity.createdAt
        updatedAt = entity.updatedAt
    }

    func entity() throws -> BudgetEntity {
        guard let monthlyLimit = monthlyLimit.decimal else {
            throw DataSettingsError.invalidDecimal
        }
        guard (scopeYear == nil) == (scopeMonth == nil) else {
            throw DataSettingsError.invalidEnum
        }
        if let scopeYear, let scopeMonth {
            let normalized = MonthKey(year: scopeYear, month: scopeMonth)
            guard normalized.year == scopeYear, normalized.month == scopeMonth else {
                throw DataSettingsError.invalidEnum
            }
        }
        return BudgetEntity(
            id: id,
            category: category,
            monthlyLimit: monthlyLimit,
            scopeYear: scopeYear,
            scopeMonth: scopeMonth,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct SavingsGoalRecord: Codable {
    let id: UUID
    let name: String
    let targetAmount: DecimalValue
    let monthlyTarget: DecimalValue
    let currentAmount: DecimalValue
    let targetDate: Date?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    init(_ entity: SavingsGoalEntity) {
        id = entity.id
        name = entity.name
        targetAmount = DecimalValue(entity.targetAmount)
        monthlyTarget = DecimalValue(entity.monthlyTarget)
        currentAmount = DecimalValue(entity.currentAmount)
        targetDate = entity.targetDate
        isActive = entity.isActive
        createdAt = entity.createdAt
        updatedAt = entity.updatedAt
    }

    func entity() throws -> SavingsGoalEntity {
        guard
            let targetAmount = targetAmount.decimal,
            let monthlyTarget = monthlyTarget.decimal,
            let currentAmount = currentAmount.decimal
        else {
            throw DataSettingsError.invalidDecimal
        }
        return SavingsGoalEntity(
            id: id,
            name: name,
            targetAmount: targetAmount,
            monthlyTarget: monthlyTarget,
            currentAmount: currentAmount,
            targetDate: targetDate,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct MonthSettingsRecord: Codable {
    let id: UUID
    let year: Int
    let month: Int
    let startingBalance: DecimalValue
    let createdAt: Date
    let updatedAt: Date

    init(_ entity: MonthSettingsEntity) {
        id = entity.id
        year = entity.year
        month = entity.month
        startingBalance = DecimalValue(entity.startingBalance)
        createdAt = entity.createdAt
        updatedAt = entity.updatedAt
    }

    func entity() throws -> MonthSettingsEntity {
        guard let startingBalance = startingBalance.decimal, (1...12).contains(month) else {
            throw DataSettingsError.invalidDecimal
        }
        return MonthSettingsEntity(
            id: id,
            year: year,
            month: month,
            startingBalance: startingBalance,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
