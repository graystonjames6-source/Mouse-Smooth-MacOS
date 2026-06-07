import AppKit
import Combine
import ServiceManagement

// Top-level coordinator. Owns the long-lived objects (settings, monitor,
// permission watcher) and ties them together with a tiny bit of glue:
//
//   - When AX permission flips ON, start the event tap.
//   - When AX permission flips OFF, stop the event tap.
//   - At launch, reconcile our `launchAtLoginEnabled` setting with the
//     actual SMAppService state (user may have toggled it via System Settings).
@MainActor
final class MouseSmoothController: ObservableObject {

    let settings: SettingsStore
    let permission: AccessibilityPermission
    private let monitor: MouseEventMonitor

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let store = SettingsStore.shared
        let perm = AccessibilityPermission()
        self.settings = store
        self.permission = perm
        self.monitor = MouseEventMonitor(settings: store)

        // Reconcile launch-at-login: the user may have changed it outside our UI.
        let actuallyEnabled = LaunchAtLoginManager.isEnabled
        if store.launchAtLoginEnabled != actuallyEnabled {
            store.launchAtLoginEnabled = actuallyEnabled
        }

        // React to AX permission state.
        perm.$isGranted
            .sink { [weak self] granted in
                guard let self else { return }
                if granted {
                    _ = self.monitor.start()
                } else {
                    self.monitor.stop()
                }
            }
            .store(in: &cancellables)
    }

    var isTapRunning: Bool { monitor.isRunning }
}
