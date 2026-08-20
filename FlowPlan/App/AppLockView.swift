import SwiftUI

struct AppLockView: View {
    @Bindable var gate: BiometricGate

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
                    .foregroundStyle(.red)
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
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(gate.isAuthenticating)

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
        .foregroundStyle(Palette.ink)
    }
}
