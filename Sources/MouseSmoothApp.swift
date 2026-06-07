import SwiftUI

// Mouse Smooth — macOS menu bar utility for customizing external mouse scrolling.

@main
struct MouseSmoothApp: App {
    // Owns settings, monitor, and permission watcher. Lives for the whole app.
    @StateObject private var controller = MouseSmoothController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(controller.settings)
                .environmentObject(controller.permission)
        } label: {
            // Hollow mouse when inactive (no AX permission), filled when active.
            Image(systemName: controller.permission.isGranted
                  ? "computermouse.fill"
                  : "computermouse")
        }
        .menuBarExtraStyle(.menu)

        // The single settings window. Opened on demand by the menu item.
        Window("Mouse Smooth Settings", id: "settings") {
            SettingsView()
                .environmentObject(controller.settings)
                .environmentObject(controller.permission)
                .frame(minWidth: 440, minHeight: 460)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject private var permission: AccessibilityPermission
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Mouse Smooth")
        Text("v\(Bundle.main.appVersion)")
            .font(.caption)

        Divider()

        if !permission.isGranted {
            Text("⚠ Accessibility permission needed")
        }

        Button("Settings…") {
            // LSUIElement apps start as .accessory and must explicitly activate
            // to bring a window forward and accept keyboard input.
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
        .keyboardShortcut(",")

        Button("About Mouse Smooth") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(nil)
        }

        Divider()

        Button("Quit Mouse Smooth") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

private extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
