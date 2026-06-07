import CoreGraphics
import Dispatch

// Drives smooth scrolling: absorbs discrete wheel deltas and emits a series
// of small synthesized continuous scroll events on a 60 Hz timer.
//
// Loop-prevention contract:
//   Every event we synthesize carries `Self.sourceUserData` in its
//   `eventSourceUserData` field (inherited from our private CGEventSource).
//   MouseEventMonitor checks this field on every incoming event and lets
//   our own events pass through untouched. Without this check, posting an
//   event would re-enter our tap and create an infinite loop.
//
// Decay model:
//   Each frame we emit `pending / decayFrames` and subtract it from the
//   pending pool. This is exponential decay with a time constant of
//   `decayFrames × frameInterval` (~130ms). New incoming deltas simply add
//   to the pool — bursts of scroll combine naturally without restarting the
//   animation.
final class SmoothScrollEngine {

    /// Magic value stamped on every synthesized event. Chosen as the ASCII
    /// for "MSScroll" — the exact value doesn't matter, it just needs to be
    /// improbable for any other source to use.
    static let sourceUserData: Int64 = 0x4D53_5363_726F_6C6C  // "MSScroll"

    private let queue: DispatchQueue
    private let source: CGEventSource
    private var pendingY: Double = 0
    private var pendingX: Double = 0
    private var lastFlags: CGEventFlags = []
    private var timer: DispatchSourceTimer?

    // 60 Hz emission cadence.
    private let frameInterval: DispatchTimeInterval = .milliseconds(16)
    // Higher = slower / smoother. 8 frames ≈ 130ms time constant.
    private let decayFrames: Double = 8.0
    // When the pool is smaller than this, flush remaining and stop.
    private let flushThreshold: Double = 1.0

    init(queue: DispatchQueue = .main) {
        self.queue = queue
        guard let src = CGEventSource(stateID: .privateState) else {
            fatalError("Could not create CGEventSource for smooth scrolling")
        }
        // The user-data on a source is copied into every event created from
        // it — this is the documented way to tag events for later identification.
        // Swift exposes the underlying CGEventSourceSetUserData as a property.
        src.userData = Self.sourceUserData
        self.source = src
    }

    /// Add to the pending pool. `flags` (modifier state) is captured so the
    /// synthesized events behave correctly inside apps that use ⌘/⌃+scroll
    /// for zoom etc. Most recent flags win — fine for typical input cadence.
    func absorb(yDelta: Double, xDelta: Double, flags: CGEventFlags) {
        pendingY += yDelta
        pendingX += xDelta
        lastFlags = flags
        startIfNeeded()
    }

    /// Drop all pending motion and stop the timer.
    func cancel() {
        timer?.cancel()
        timer = nil
        pendingY = 0
        pendingX = 0
    }

    // MARK: - Timer

    private func startIfNeeded() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + frameInterval, repeating: frameInterval)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        var emitY = pendingY / decayFrames
        var emitX = pendingX / decayFrames
        pendingY -= emitY
        pendingX -= emitX

        if abs(pendingY) < flushThreshold && abs(pendingX) < flushThreshold {
            // Tail of the animation — drain the rest in this final emission.
            emitY += pendingY
            emitX += pendingX
            pendingY = 0
            pendingX = 0
            timer?.cancel()
            timer = nil
        }

        emit(y: emitY, x: emitX)
    }

    private func emit(y: Double, x: Double) {
        let iy = Int32(y.rounded())
        let ix = Int32(x.rounded())
        // Skip 0-delta events — they're noise to receiving apps.
        if iy == 0 && ix == 0 { return }

        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: iy,
            wheel2: ix,
            wheel3: 0
        ) else { return }

        event.flags = lastFlags

        // Post into the session tap chain. Our own tap will see it and
        // forward it unchanged because of the sourceUserData stamp.
        event.post(tap: .cgSessionEventTap)
    }
}
