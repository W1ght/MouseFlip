import CoreGraphics

/// Conservative classification: continuous or gesture-phase events are never changed.
/// This protects trackpads, but also deliberately excludes Magic Mouse and smooth-scroll drivers.
public enum ScrollReverser {
    public static func isWheelEvent(_ event: CGEvent) -> Bool {
        event.type == .scrollWheel
            && event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0
            && event.getIntegerValueField(.scrollWheelEventScrollPhase) == 0
            && event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0
    }

    @discardableResult
    public static func apply(to event: CGEvent, enabled: Bool, vertical: Bool, horizontal: Bool) -> Bool {
        guard enabled, isWheelEvent(event), vertical || horizontal else { return false }
        // Snapshot before setting: related fields can be normalized by Core Graphics.
        let fields: [CGEventField] = (vertical ? [
            .scrollWheelEventDeltaAxis1, .scrollWheelEventPointDeltaAxis1,
            .scrollWheelEventFixedPtDeltaAxis1
        ] : []) + (horizontal ? [
            .scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis2,
            .scrollWheelEventFixedPtDeltaAxis2
        ] : [])
        let values = fields.map { event.getIntegerValueField($0) }
        guard values.contains(where: { $0 != 0 }) else { return false }
        // CGEvent stores these fields as signed 32-bit values. Their minimum
        // cannot be negated within that representation; leave the event untouched.
        guard values.allSatisfy({ $0 > Int64(Int32.min) && $0 <= Int64(Int32.max) }) else { return false }
        for (field, value) in zip(fields, values) {
            event.setIntegerValueField(field, value: -value)
        }
        return true
    }
}
