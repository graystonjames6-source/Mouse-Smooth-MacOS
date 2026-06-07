import Foundation
import Combine

// Single source of truth for user preferences.
//
// Backed by UserDefaults. Use `.shared` everywhere — having one instance keeps
// SwiftUI views and the (future) event tap reading the same values.
//
// Pattern: each setting is a `@Published` property with a `didSet` that writes
// through to UserDefaults. We register defaults in `init` so the very first
// launch has sensible values without nil-checks anywhere downstream.
final class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    // MARK: - Settings

    @Published var reverseScrollForMouse: Bool {
        didSet { defaults.set(reverseScrollForMouse, forKey: Keys.reverseScrollForMouse) }
    }

    /// 0.1 ... 5.0, where 1.0 means "no change".
    @Published var scrollSpeedMultiplier: Double {
        didSet { defaults.set(scrollSpeedMultiplier, forKey: Keys.scrollSpeedMultiplier) }
    }

    @Published var smoothScrollingEnabled: Bool {
        didSet { defaults.set(smoothScrollingEnabled, forKey: Keys.smoothScrollingEnabled) }
    }

    @Published var accelerationEnabled: Bool {
        didSet { defaults.set(accelerationEnabled, forKey: Keys.accelerationEnabled) }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet { defaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled) }
    }

    // MARK: - Storage

    private let defaults: UserDefaults

    private enum Keys {
        static let reverseScrollForMouse = "reverseScrollForMouse"
        static let scrollSpeedMultiplier = "scrollSpeedMultiplier"
        static let smoothScrollingEnabled = "smoothScrollingEnabled"
        static let accelerationEnabled = "accelerationEnabled"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // First-launch defaults. `register` does NOT overwrite existing values.
        defaults.register(defaults: [
            // Reversing the mouse scroll is the whole point of the app, so default ON.
            Keys.reverseScrollForMouse: true,
            Keys.scrollSpeedMultiplier: 1.0,
            Keys.smoothScrollingEnabled: false,
            Keys.accelerationEnabled: true,
            Keys.launchAtLoginEnabled: false,
        ])

        self.reverseScrollForMouse = defaults.bool(forKey: Keys.reverseScrollForMouse)
        self.scrollSpeedMultiplier = defaults.double(forKey: Keys.scrollSpeedMultiplier)
        self.smoothScrollingEnabled = defaults.bool(forKey: Keys.smoothScrollingEnabled)
        self.accelerationEnabled = defaults.bool(forKey: Keys.accelerationEnabled)
        self.launchAtLoginEnabled = defaults.bool(forKey: Keys.launchAtLoginEnabled)
    }

    /// Reset all settings to their registered defaults. Used by the "Restore Defaults" button.
    func resetToDefaults() {
        for key in [
            Keys.reverseScrollForMouse,
            Keys.scrollSpeedMultiplier,
            Keys.smoothScrollingEnabled,
            Keys.accelerationEnabled,
            Keys.launchAtLoginEnabled,
        ] {
            defaults.removeObject(forKey: key)
        }
        reverseScrollForMouse = defaults.bool(forKey: Keys.reverseScrollForMouse)
        scrollSpeedMultiplier = defaults.double(forKey: Keys.scrollSpeedMultiplier)
        smoothScrollingEnabled = defaults.bool(forKey: Keys.smoothScrollingEnabled)
        accelerationEnabled = defaults.bool(forKey: Keys.accelerationEnabled)
        launchAtLoginEnabled = defaults.bool(forKey: Keys.launchAtLoginEnabled)
    }
}
