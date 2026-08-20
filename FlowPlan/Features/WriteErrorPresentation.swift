import Foundation

enum WriteOperation: String {
    case add
    case deactivate
    case delete
    case reactivate
    case reset
    case save
    case update
}

struct WriteErrorPresentation: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    var inlineMessage: String {
        "\(title)\n\(message)"
    }

    init(
        operation: WriteOperation,
        subject: String,
        error: Error,
        guidance: String = "Please try again."
    ) {
        title = "Couldn't \(operation.rawValue) this \(subject)"
        message = "\(guidance)\n\nDetails: \(error.localizedDescription)"
    }
}
