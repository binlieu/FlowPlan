import Foundation
import LocalAuthentication
import Observation

enum BiometryKind: String, Equatable, Sendable {
    case none
    case faceID
    case touchID
    case opticID

    var displayName: String {
        switch self {
        case .none:
            return "Biometric authentication"
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        }
    }
}

struct BiometricAvailability: Equatable, Sendable {
    let isAvailable: Bool
    let biometry: BiometryKind

    var explanation: String {
        if isAvailable {
            return "\(biometry.displayName) is available on this device."
        }
        return "Face ID is not available or is not enrolled on this device."
    }
}

enum BiometricError: Error, Equatable, Sendable {
    case unavailable
    case notEnrolled
    case lockedOut
    case cancelled
    case authenticationFailed
    case systemFailure

    var message: String {
        switch self {
        case .unavailable:
            return "Face ID is unavailable on this device."
        case .notEnrolled:
            return "Face ID has not been set up on this device."
        case .lockedOut:
            return "Face ID is temporarily locked. Try again after unlocking your device."
        case .cancelled:
            return "Authentication was cancelled."
        case .authenticationFailed:
            return "Face ID could not verify your identity."
        case .systemFailure:
            return "Authentication is temporarily unavailable."
        }
    }
}

@MainActor
protocol BiometricAuthenticating {
    func canEvaluate() -> BiometricAvailability
    func authenticate(reason: String) async -> Result<Void, BiometricError>
}

struct BiometricAuthenticator: BiometricAuthenticating {
    func canEvaluate() -> BiometricAvailability {
        let context = LAContext()
        var error: NSError?
        let isAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        return BiometricAvailability(
            isAvailable: isAvailable,
            biometry: biometryKind(context.biometryType)
        )
    }

    func authenticate(reason: String) async -> Result<Void, BiometricError> {
        let context = LAContext()
        var evaluationError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &evaluationError
        ) else {
            return .failure(mapError(evaluationError))
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                if success {
                    continuation.resume(returning: .success(()))
                } else {
                    continuation.resume(returning: .failure(mapError(error as NSError?)))
                }
            }
        }
    }

    private func biometryKind(_ type: LABiometryType) -> BiometryKind {
        switch type {
        case .none:
            return .none
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        @unknown default:
            return .none
        }
    }

    nonisolated private func mapError(_ error: NSError?) -> BiometricError {
        guard let error else {
            return .systemFailure
        }

        switch LAError.Code(rawValue: error.code) {
        case .biometryNotAvailable:
            return .unavailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryLockout:
            return .lockedOut
        case .userCancel, .appCancel, .systemCancel:
            return .cancelled
        case .authenticationFailed:
            return .authenticationFailed
        default:
            return .systemFailure
        }
    }
}

enum AutoLockInterval: String, CaseIterable, Identifiable, Sendable {
    case immediately
    case oneMinute
    case fiveMinutes
    case never

    var id: String { rawValue }

    var title: String {
        switch self {
        case .immediately:
            return "Immediately"
        case .oneMinute:
            return "1 minute"
        case .fiveMinutes:
            return "5 minutes"
        case .never:
            return "Never"
        }
    }

    fileprivate var duration: TimeInterval? {
        switch self {
        case .immediately:
            return 0
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 300
        case .never:
            return nil
        }
    }
}

@Observable
@MainActor
/// This is an app access gate over local data. It does not encrypt data or store secrets.
final class BiometricGate {
    static let authenticationReason = "Unlock FlowPlan to view your finances"

    private(set) var isLocked: Bool
    private(set) var lastError: BiometricError?
    private(set) var isAuthenticating = false

    @ObservationIgnored private let authenticator: any BiometricAuthenticating
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var becameInactiveAt: Date?
    @ObservationIgnored private(set) var isEnabled: Bool
    @ObservationIgnored private var autoLockInterval: AutoLockInterval

    init(
        isEnabled: Bool,
        autoLockInterval: AutoLockInterval,
        authenticator: (any BiometricAuthenticating)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.isEnabled = isEnabled
        self.autoLockInterval = autoLockInterval
        self.authenticator = authenticator ?? BiometricAuthenticator()
        self.now = now
        isLocked = isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        lastError = nil
        becameInactiveAt = nil
        isLocked = enabled
    }

    func setAutoLockInterval(_ interval: AutoLockInterval) {
        autoLockInterval = interval
    }

    func authenticate() async {
        guard isEnabled, !isAuthenticating else {
            return
        }

        isAuthenticating = true
        lastError = nil
        let result = await authenticator.authenticate(reason: Self.authenticationReason)
        isAuthenticating = false

        switch result {
        case .success:
            isLocked = false
        case let .failure(error):
            isLocked = true
            lastError = error
        }
    }

    func sceneBecameInactive() {
        guard isEnabled, becameInactiveAt == nil else {
            return
        }

        becameInactiveAt = now()
        if autoLockInterval == .immediately {
            isLocked = true
        }
    }

    func sceneBecameActive() {
        defer { becameInactiveAt = nil }
        guard
            isEnabled,
            !isLocked,
            let inactiveDate = becameInactiveAt,
            let duration = autoLockInterval.duration
        else {
            return
        }

        if now().timeIntervalSince(inactiveDate) >= duration {
            isLocked = true
        }
    }
}
