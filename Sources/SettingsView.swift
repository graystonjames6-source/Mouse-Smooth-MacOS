import SwiftUI

// Settings window UI. All state lives in SettingsStore + AccessibilityPermission.
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var permission: AccessibilityPermission

    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            statusSection

            if !permission.isGranted {
                permissionSection
            }

            Section("Mouse Scrolling") {
                Toggle("Reverse scroll direction (mouse only)",
                       isOn: $settings.reverseScrollForMouse)
                    .disabled(!permission.isGranted)

                HStack {
                    Text("Scroll speed")
                    Slider(value: $settings.scrollSpeedMultiplier,
                           in: 0.1...5.0,
                           step: 0.1)
                    Text(String(format: "%.1f×", settings.scrollSpeedMultiplier))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                .disabled(!permission.isGranted)

                Toggle("Mouse acceleration", isOn: $settings.accelerationEnabled)
                    .disabled(!permission.isGranted)

                Toggle("Smooth scrolling", isOn: $settings.smoothScrollingEnabled)
                    .disabled(!permission.isGranted)
            }

            Section("General") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                if let err = launchAtLoginError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Trackpad") {
                Text("Trackpad scrolling is never modified by Mouse Smooth.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Restore Defaults") {
                        settings.resetToDefaults()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Mouse Smooth Settings")
    }

    // MARK: - Status

    private var statusSection: some View {
        Section("Status") {
            HStack(spacing: 8) {
                Image(systemName: permission.isGranted
                      ? "checkmark.circle.fill"
                      : "exclamationmark.triangle.fill")
                    .foregroundStyle(permission.isGranted ? .green : .orange)
                Text(permission.isGranted
                     ? "Active — Mouse Smooth is modifying mouse scroll events."
                     : "Inactive — Accessibility permission required.")
                    .font(.callout)
            }
        }
    }

    // MARK: - Permission banner

    private var permissionSection: some View {
        Section("Accessibility Permission") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mouse Smooth needs Accessibility access to observe and modify scroll events from your external mouse. Trackpad scrolling is untouched.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button("Request Access…") {
                        permission.requestAccess()
                    }
                    Button("Open System Settings") {
                        permission.openSystemSettings()
                    }
                    Button("I've granted access") {
                        permission.recheck()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Launch at login binding

    /// Wraps SMAppService side-effects: writes to the OS first, only updates
    /// our store if the OS call succeeds; on failure, surfaces the error and
    /// leaves the toggle in its previous state.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLoginEnabled },
            set: { newValue in
                do {
                    try LaunchAtLoginManager.setEnabled(newValue)
                    settings.launchAtLoginEnabled = newValue
                    launchAtLoginError = nil
                } catch {
                    launchAtLoginError = "Could not \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)"
                }
            }
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsStore())
        .environmentObject(AccessibilityPermission())
        .frame(width: 440, height: 500)
}
