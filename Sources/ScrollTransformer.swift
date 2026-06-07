import CoreGraphics

// Minimum pixels of motion per notch of the physical wheel.
//
// Why: macOS applies a steep velocity curve to scroll events. Spin the wheel
// slowly and the OS delivers ~5 px per tick; spin fast and you get 80–150.
// At low wheel speeds the result feels sluggish — especially with smooth
// scrolling on, because tiny inputs get divided across N animation frames
// and emit fractional pixels.
//
// Applying a floor (scaled by the speed multiplier) lifts the slow end
// without affecting fast scrolls (those already exceed the floor).
private let minPixelsPerTick: Double = 30.0

// Pure logic for modifying a scroll event.
//
// Two consumers:
//   - `transform(event:using:)` — mutates the event in place. Used when
//     smooth scrolling is OFF.
//   - `computeFinalPixelDelta(from:using:)` — returns the resulting pixel
//     delta without touching the event. Used when smooth scrolling is ON,
//     because the engine consumes the original event and synthesizes new ones.
//
// Reading and writing scroll event fields is finicky — there are *three*
// parallel delta representations (integer ticks, pixel, fixed-point 16.16)
// and different apps consume different ones. `transform` writes all three so
// the result is consistent across apps.
enum ScrollTransformer {

    static func transform(event: CGEvent, using settings: SettingsStore) {
        guard !isContinuous(event) else { return }
        let d = computeDeltas(from: event, using: settings)
        writeBack(d, to: event)
    }

    /// Returns the final pixel delta this event would produce after all
    /// user settings are applied. Used to drive smooth scrolling.
    static func computeFinalPixelDelta(from event: CGEvent,
                                       using settings: SettingsStore) -> (y: Double, x: Double) {
        guard !isContinuous(event) else {
            return (event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1),
                    event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2))
        }
        let d = computeDeltas(from: event, using: settings)
        return (d.pixelY, d.pixelX)
    }

    // MARK: - Internals

    /// `scrollWheelEventIsContinuous` is the only reliable way to tell a
    /// notch-wheel mouse (== 0) from a trackpad / Magic Mouse (!= 0).
    /// We never modify trackpad scrolling — that's a v1 promise.
    private static func isContinuous(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
    }

    private struct Deltas {
        var integerY: Int64, integerX: Int64
        var pixelY: Double,  pixelX: Double
        var fixedY: Double,  fixedX: Double
    }

    private static func computeDeltas(from event: CGEvent, using settings: SettingsStore) -> Deltas {
        var iY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        var iX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        var pY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        var pX = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
        var fY = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        var fX = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)

        // 1. Reverse — flip the sign on every delta representation.
        if settings.reverseScrollForMouse {
            iY = -iY; iX = -iX
            pY = -pY; pX = -pX
            fY = -fY; fX = -fX
        }

        // 2. Acceleration — when OFF, replace the OS-provided pixel deltas
        //    with a flat multiple of the integer tick count. This strips the
        //    velocity curve macOS applies. Cursor acceleration is untouched.
        if !settings.accelerationEnabled {
            pY = Double(iY) * minPixelsPerTick
            pX = Double(iX) * minPixelsPerTick
            fY = pY
            fX = pX
        }

        // 2.5 Slow-wheel floor — see the doc comment on `minPixelsPerTick`.
        //     Only meaningful when acceleration is ON; the OFF branch above
        //     already produces values exactly at the floor, so this is a no-op
        //     there. The floor scales with the number of batched ticks so
        //     fast bursts stay proportional.
        if iY != 0 {
            let floor = minPixelsPerTick * Double(abs(iY))
            if abs(pY) < floor {
                let direction: Double = iY > 0 ? 1.0 : -1.0
                pY = direction * floor
                fY = pY
            }
        }
        if iX != 0 {
            let floor = minPixelsPerTick * Double(abs(iX))
            if abs(pX) < floor {
                let direction: Double = iX > 0 ? 1.0 : -1.0
                pX = direction * floor
                fX = pX
            }
        }

        // 3. Speed multiplier — applied last so it scales the final shape.
        //    Because the floor is applied *before* this, the user's speed
        //    setting still scales it: speed=0.1 + 1 tick = 3 px, speed=2 = 60 px.
        let m = settings.scrollSpeedMultiplier
        iY = Int64((Double(iY) * m).rounded())
        iX = Int64((Double(iX) * m).rounded())
        pY *= m; pX *= m
        fY *= m; fX *= m

        return Deltas(integerY: iY, integerX: iX,
                      pixelY: pY,   pixelX: pX,
                      fixedY: fY,   fixedX: fX)
    }

    private static func writeBack(_ d: Deltas, to event: CGEvent) {
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: d.integerY)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: d.integerX)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: d.pixelY)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: d.pixelX)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: d.fixedY)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: d.fixedX)
    }
}
