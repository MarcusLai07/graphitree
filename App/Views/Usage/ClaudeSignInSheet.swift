import AppKit
import SwiftUI

/// Signs Graphitree in to Claude: open Anthropic's sign-in page in the browser, sign in there,
/// paste back the code it shows. Graphitree then keeps its own sign-in and renews it itself, so the
/// plan's limits stay current without Claude Code (`ClaudeOAuth`).
struct ClaudeSignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var refresher = UsageRefresher.shared

    /// A new one each time the page is opened, so a code only works with the page it came from.
    @State private var pkce = ClaudeOAuth.PKCE()
    @State private var openedPage = false
    @State private var pasted = ""
    @State private var problem: String?
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in to Claude")
                        .font(.system(size: 15, weight: .semibold))
                    Text("So Graphitree reads your plan's limits on its own, whether or not Claude Code runs.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(SoftButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }
            .padding(18)
            Rectangle().fill(Palette.hairline).frame(height: 1)
            VStack(alignment: .leading, spacing: 18) {
                step(1, "Sign in on Anthropic's page", detail: "It opens in your browser. Sign in with the account your plan is on, then choose Authorize.") {
                    if openedPage {
                        Button("Open Again", action: openPage).buttonStyle(SoftButtonStyle())
                    } else {
                        Button("Open Sign-in Page", action: openPage).buttonStyle(GoldButtonStyle())
                    }
                }
                step(2, "Paste the code it shows", detail: nil) {
                    EmptyView()
                }
                HStack(spacing: 8) {
                    TextField("Code from the sign-in page", text: $pasted)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12.5, design: .monospaced))
                        .onSubmit(signIn)
                    Button("Sign In", action: signIn)
                        .buttonStyle(GoldButtonStyle())
                        .disabled(pasted.trimmingCharacters(in: .whitespaces).isEmpty || isSigningIn)
                        .keyboardShortcut(.defaultAction)
                    if isSigningIn { ProgressView().controlSize(.small) }
                }
                .padding(.leading, 30)
                if let problem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 30)
                }
                Text("Graphitree keeps this sign-in in your Keychain and uses it only to read your plan's limits and which plan it is. It's separate from Claude Code's sign-in, so it never signs Claude Code out. Sign out from Menu Bar & Alerts.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
        .frame(width: 500)
        .background(Palette.panel)
        .preferredColorScheme(.dark)
        .tint(Palette.gold)
    }

    private func step<Control: View>(_ number: Int, _ title: String, detail: String?, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Palette.gold.opacity(0.18)))
                .foregroundStyle(Palette.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12.5, weight: .medium))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control()
        }
    }

    private func openPage() {
        pkce = ClaudeOAuth.PKCE()
        problem = nil
        openedPage = true
        NSWorkspace.shared.open(ClaudeOAuth.authorizeURL(pkce: pkce))
    }

    private func signIn() {
        guard !isSigningIn, !pasted.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard openedPage else {
            problem = "Open the sign-in page first: a code only works with the page Graphitree opened."
            return
        }
        isSigningIn = true
        problem = nil
        Task {
            defer { isSigningIn = false }
            do {
                try await refresher.signIn(pasted: pasted, pkce: pkce)
                dismiss()
            } catch let failure as ClaudeOAuth.Failure {
                problem = failure.errorDescription
            } catch let failure as AIKeychain.KeychainError {
                problem = "Signed in, but the Keychain wouldn't keep it: \(failure.errorDescription ?? "unknown error")."
            } catch {
                problem = UsageAPIError.from(error).errorDescription.map { $0 + "." } ?? "Signing in failed. Try again."
            }
        }
    }
}
