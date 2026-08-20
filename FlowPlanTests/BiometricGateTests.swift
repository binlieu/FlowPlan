import Foundation
import Testing
@testable import FlowPlan

@Test
@MainActor
func biometricGateStartsLockedWhenEnabled() {
    let gate = BiometricGate(
        isEnabled: true,
        autoLockInterval: .immediately,
        authenticator: FakeBiometricAuthenticator(result: .success(()))
    )

    #expect(gate.isLocked)
}

@Test
@MainActor
func biometricGateStartsUnlockedWhenDisabled() {
    let gate = BiometricGate(
        isEnabled: false,
        autoLockInterval: .immediately,
        authenticator: FakeBiometricAuthenticator(result: .success(()))
    )

    #expect(!gate.isLocked)
}

@Test
@MainActor
func biometricGateUnlocksAfterSuccessfulAuthentication() async {
    let authenticator = FakeBiometricAuthenticator(result: .success(()))
    let gate = BiometricGate(
        isEnabled: true,
        autoLockInterval: .immediately,
        authenticator: authenticator
    )

    await gate.authenticate()

    #expect(!gate.isLocked)
    #expect(authenticator.reasons == [BiometricGate.authenticationReason])
}

@Test
@MainActor
func biometricGateStaysLockedAfterFailedAuthentication() async {
    let gate = BiometricGate(
        isEnabled: true,
        autoLockInterval: .immediately,
        authenticator: FakeBiometricAuthenticator(result: .failure(.authenticationFailed))
    )

    await gate.authenticate()

    #expect(gate.isLocked)
    #expect(gate.lastError == .authenticationFailed)
}

@Test
@MainActor
func biometricGateRelocksAfterConfiguredInterval() async {
    var currentDate = Date(timeIntervalSinceReferenceDate: 1_000)
    let gate = BiometricGate(
        isEnabled: true,
        autoLockInterval: .oneMinute,
        authenticator: FakeBiometricAuthenticator(result: .success(())),
        now: { currentDate }
    )
    await gate.authenticate()

    gate.sceneBecameInactive()
    currentDate = currentDate.addingTimeInterval(61)
    gate.sceneBecameActive()

    #expect(gate.isLocked)
}

@Test
@MainActor
func biometricGateDoesNotRelockBeforeConfiguredInterval() async {
    var currentDate = Date(timeIntervalSinceReferenceDate: 2_000)
    let gate = BiometricGate(
        isEnabled: true,
        autoLockInterval: .fiveMinutes,
        authenticator: FakeBiometricAuthenticator(result: .success(())),
        now: { currentDate }
    )
    await gate.authenticate()

    gate.sceneBecameInactive()
    currentDate = currentDate.addingTimeInterval(299)
    gate.sceneBecameActive()

    #expect(!gate.isLocked)
}

@MainActor
private final class FakeBiometricAuthenticator: BiometricAuthenticating {
    let availability = BiometricAvailability(isAvailable: true, biometry: .faceID)
    let result: Result<Void, BiometricError>
    private(set) var reasons: [String] = []

    init(result: Result<Void, BiometricError>) {
        self.result = result
    }

    func canEvaluate() -> BiometricAvailability {
        availability
    }

    func authenticate(reason: String) async -> Result<Void, BiometricError> {
        reasons.append(reason)
        return result
    }
}
