import AppKit
import ApplicationServices
import Combine

// Observable wrapper around macOS Accessibility permission.
//
// macOS does *not* notify us when this permission flips. The established
// pattern is to re-check periodically and whenever the user reactivates the
// app (they typically come back from System Settings).
@MainActor
final class AccessibilityPermission: ObservableObject {

    @Published private(set) var isGranted: Bool

    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?

    init() {
        self.isGranted = AXIsProcessTrusted()
        startWatching()
    }

    deinit {
        timer?.invalidate()
        if let observer = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    /// Shows the system Accessibility prompt. The user must grant access via
    /// System Settings — we cannot grant it ourselves. The returned value is
    /// nearly always `false` (the user hasn't acted yet); rely on the
    /// `isGranted` publisher instead.
    @discardableResult
    func requestAccess() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [key: true] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        recheck()
        return granted
    }

    /// Deep-links into System Settings → Privacy & Security → Accessibility.
    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func recheck() {
        let granted = AXIsProcessTrusted()
        if granted != isGranted {
            isGranted = granted
        }
    }

    private func startWatching() {
        // 1Hz poll — cheap, and the only way to notice trust toggling without
        // the user re-focusing our app. macOS provides no native KVO/notification
        // for AX trust state.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.recheck() }
        }

        // Instant recheck whenever the user comes back to our app — usually
        // after granting permission in System Settings.
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.recheck() }
        }
    }
}
