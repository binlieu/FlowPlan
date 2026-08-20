import Foundation
import Testing
@testable import FlowPlan

@Test
@MainActor
func biometricGateStartsLockedWhenEnabled() {
    let gate = BiometricGate(
        isEnabled: true,
        autoLockInterval: .oneMinute,
        authenticator: FakeBiometricAuthenticator(result: .success(()))
    )

    #expect(gate.isLocked)
}

@Test
@MainActor
func biometricGateStartsUnlockedWhenDisabled() {
    let gate = BiometricGate(
        isEnabled: false,
        autoLockInterval: .oneMinute,
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
        autoLockInterval: .oneMinute,
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
        autoLockInterval: .oneMinute,
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

    gate.appDidEnterBackground()
    currentDate = currentDate.addingTimeInterval(61)
    gate.appDidBecomeActive()

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

    gate.appDidEnterBackground()
    currentDate = currentDate.addingTimeInterval(299)
    gate.appDidBecomeActive()

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

// MARK: - Regression: the prompt must not lock you out of answering it
//
// Found on a physical iPhone, not in the simulator: Face ID asked to unlock over and over.
// Presenting the system biometric prompt drives the app to .inactive. The prompt must not leave
// an inactivity timestamp that could re-lock the app after authentication succeeds.

@Test
@MainActor
func successfulUnlockSurvivesThePromptsOwnSceneTransitions() async {
    let gate = BiometricGate(
        isEnabled: true,
        autoLockInterval: .oneMinute,
        authenticator: FakeBiometricAuthenticator(result: .success(()))
    )
    #expect(gate.isLocked)

    // The real sequence: the prompt appears (app goes inactive), the user authenticates,
    // then the prompt dismisses (app returns to active).
    gate.appDidEnterBackground()
    await gate.authenticate()
    gate.appDidBecomeActive()

    #expect(!gate.isLocked, "A successful Face ID unlock must not be undone by the prompt's own scene transitions")
}

@Test
@MainActor
func genuinelyLeavingTheAppStartsTheAutoLockInterval() async {
    var currentDate = Date(timeIntervalSinceReferenceDate: 3_000)
    let gate = BiometricGate(
        isEnabled: true,
        autoLockInterval: .oneMinute,
        authenticator: FakeBiometricAuthenticator(result: .success(())),
        now: { currentDate }
    )
    await gate.authenticate()
    #expect(!gate.isLocked)

    // No authentication in flight — this is the user actually backgrounding the app.
    gate.appDidEnterBackground()
    #expect(!gate.isLocked, "Backgrounding must not lock before the configured interval")

    currentDate = currentDate.addingTimeInterval(60)
    gate.appDidBecomeActive()

    #expect(gate.isLocked, "Returning after the configured interval must lock the app")
}

@Test
@MainActor
func aFailedUnlockLeavesTheAppLocked() async {
    let gate = BiometricGate(
        isEnabled: true,
        autoLockInterval: .oneMinute,
        authenticator: FakeBiometricAuthenticator(result: .failure(.authenticationFailed))
    )

    gate.appDidEnterBackground()
    await gate.authenticate()
    gate.appDidBecomeActive()

    #expect(gate.isLocked)
    #expect(gate.lastError != nil)
}

@Test
func immediatelyStoredAutoLockIntervalMigratesToOneMinute() throws {
    let defaults = try isolatedTestUserDefaults()
    defaults.set("immediately", forKey: AutoLockInterval.storageKey)

    #expect(AutoLockInterval.storedValue(in: defaults) == .oneMinute)
}

@Test
func neverStoredAutoLockIntervalMigratesToOneMinute() throws {
    let defaults = try isolatedTestUserDefaults()
    defaults.set("never", forKey: AutoLockInterval.storageKey)

    #expect(AutoLockInterval.storedValue(in: defaults) == .oneMinute)
}

@Test
func unsetAutoLockIntervalDefaultsToOneMinute() throws {
    let defaults = try isolatedTestUserDefaults()

    #expect(AutoLockInterval.storedValue(in: defaults) == .oneMinute)
}

@Test
func autoLockIntervalOffersOnlyOneAndFiveMinutes() {
    #expect(AutoLockInterval.allCases == [.oneMinute, .fiveMinutes])
}
