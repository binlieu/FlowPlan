import SwiftUI

struct AppLockView: View {
    @Bindable var gate: BiometricGate
    @AccessibilityFocusState private var isUnlockFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("FlowPlan is locked")
                    .font(.title.bold())

                Text("Authenticate to view the financial data stored on this device.")
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            if let error = gate.lastError {
                Text(error.message)
                    .font(.footnote)
                    .foregroundStyle(Palette.negative)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Authentication error: \(error.message)")
            }

            Button {
                Task {
                    await gate.authenticate()
                }
            } label: {
                if gate.isAuthenticating {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Unlock", systemImage: "faceid")
                        .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(Palette.onAccentFill)
            .buttonStyle(.borderedProminent)
            .tint(Palette.accentFill)
            .controlSize(.large)
            .disabled(gate.isAuthenticating)
            .accessibilityFocused($isUnlockFocused)

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            isUnlockFocused = true
        }
    }
}
