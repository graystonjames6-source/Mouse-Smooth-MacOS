import Foundation
import ServiceManagement

// Tiny wrapper around SMAppService.mainApp, which is the macOS 13+ way to
// register a regular app as a login item without needing a helper bundle.
//
// On first registration the user may be prompted by macOS to approve the
// login item in System Settings → General → Login Items. We can't bypass
// that — it's a privacy guardrail.
enum LaunchAtLoginManager {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Throws if SMAppService rejects the request (e.g. unsigned build, denied
    /// by the user). Callers should surface the error to the user and revert
    /// their UI toggle.
    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        switch (enabled, service.status) {
        case (true, .enabled):
            return
        case (true, _):
            try service.register()
        case (false, .notRegistered), (false, .notFound):
            return
        case (false, _):
            try service.unregister()
        }
    }
}
