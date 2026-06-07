import AppKit
import CoreGraphics

// Owns the CGEventTap that intercepts scroll wheel events.
//
// Why a CGEventTap (and not NSEvent.addGlobalMonitorForEvents)?
//   - Global monitors are read-only. They cannot modify events.
//   - We need to *change* scroll direction / speed, so the tap is required.
//
// Why .cgSessionEventTap (and not .cghidEventTap)?
//   - Session taps run inside the logged-in user's GUI session, which is
//     exactly where scroll events are routed. HID taps see raw HID device
//     output and miss some preprocessed fields we care about.
//
// Threading: the runloop source is added to the main runloop, so the C
// callback runs on the main thread. We deliberately keep this class
// non-isolated to avoid the @convention(c) <-> @MainActor friction.
final class MouseEventMonitor {

    private let settings: SettingsStore
    private let smoothEngine: SmoothScrollEngine
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(settings: SettingsStore) {
        self.settings = settings
        self.smoothEngine = SmoothScrollEngine()
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    var isRunning: Bool { eventTap != nil }

    /// Installs the event tap. Returns `false` if installation failed — the
    /// almost-universal reason is that Accessibility permission is missing.
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)

        // @convention(c) closure — must capture nothing, hence the refcon dance.
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<MouseEventMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.process(event: event, type: type)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,      // we see events first
            options: .defaultTap,            // we can modify them
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        smoothEngine.cancel()
        eventTap = nil
        runLoopSource = nil
    }

    /// Called from the C tap callback on the main thread.
    private func process(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        // macOS disables our tap if a callback blocks too long, or after
        // certain user actions. The canonical fix is to re-enable it on
        // receipt of the synthetic "disabled" event.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        // 1. Pass through events we synthesized ourselves (smooth scrolling
        //    engine output). Without this check, posting an event would
        //    re-enter this callback forever.
        if event.getIntegerValueField(.eventSourceUserData) == SmoothScrollEngine.sourceUserData {
            return Unmanaged.passUnretained(event)
        }

        // 2. Trackpad / Magic Mouse — never touched. v1 promise.
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        if isContinuous {
            return Unmanaged.passUnretained(event)
        }

        // 3. Mouse wheel event. Two paths:
        //    - Smooth ON: compute final pixel delta, consume the original,
        //      feed the engine which will emit a series of small events.
        //    - Smooth OFF: mutate in place and forward.
        if settings.smoothScrollingEnabled {
            let delta = ScrollTransformer.computeFinalPixelDelta(from: event, using: settings)
            smoothEngine.absorb(yDelta: delta.y, xDelta: delta.x, flags: event.flags)
            return nil   // consume the original; engine will emit replacements
        } else {
            ScrollTransformer.transform(event: event, using: settings)
            return Unmanaged.passUnretained(event)
        }
    }
}
