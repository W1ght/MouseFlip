import XCTest
import CoreGraphics
@testable import ScrollCore

final class ScrollReverserTests: XCTestCase {
    private func event(continuous: Bool = false) -> CGEvent {
        let result = CGEvent(scrollWheelEvent2Source: nil, units: continuous ? .pixel : .line,
                             wheelCount: 2, wheel1: 3, wheel2: -2, wheel3: 0)!
        result.setIntegerValueField(.scrollWheelEventIsContinuous, value: continuous ? 1 : 0)
        result.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 30)
        result.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -20)
        result.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 3.25)
        result.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -2.5)
        return result
    }
    private let fields: [CGEventField] = [
        .scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2,
        .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis2,
        .scrollWheelEventPointDeltaAxis1, .scrollWheelEventPointDeltaAxis2
    ]
    private func snapshot(_ event: CGEvent) -> [Int64] { fields.map { event.getIntegerValueField($0) } }

    func testOrdinaryWheelReversesAllRepresentationsWithoutChangingModifiers() {
        let wheel = event()
        wheel.flags = [.maskShift, .maskControl]
        let before = snapshot(wheel)
        XCTAssertTrue(ScrollReverser.apply(to: wheel, enabled: true, vertical: true, horizontal: true))
        XCTAssertEqual(snapshot(wheel), before.map { -$0 })
        XCTAssertEqual(wheel.flags, [.maskShift, .maskControl])
        XCTAssertEqual(wheel.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1), -3.25)
    }
    func testContinuousTrackpadEventsAreByteForBytePreserved() {
        let trackpad = event(continuous: true)
        let before = trackpad.data! as Data
        XCTAssertFalse(ScrollReverser.apply(to: trackpad, enabled: true, vertical: true, horizontal: true))
        XCTAssertEqual(trackpad.data! as Data, before)
    }
    func testGestureAndMomentumArePreservedEvenIfContinuousFlagIsMissing() {
        for field in [CGEventField.scrollWheelEventScrollPhase, .scrollWheelEventMomentumPhase] {
            let gesture = event()
            gesture.setIntegerValueField(field, value: 1)
            let before = snapshot(gesture)
            XCTAssertFalse(ScrollReverser.apply(to: gesture, enabled: true, vertical: true, horizontal: true))
            XCTAssertEqual(snapshot(gesture), before)
        }
    }
    func testPauseAndNoAxesLeaveWheelUntouched() {
        for config in [(false, true, true), (true, false, false)] {
            let wheel = event()
            let before = snapshot(wheel)
            XCTAssertFalse(ScrollReverser.apply(to: wheel, enabled: config.0, vertical: config.1, horizontal: config.2))
            XCTAssertEqual(snapshot(wheel), before)
        }
    }
    func testVerticalOnlyDoesNotChangeHorizontal() {
        let wheel = event()
        let before = snapshot(wheel)
        XCTAssertTrue(ScrollReverser.apply(to: wheel, enabled: true, vertical: true, horizontal: false))
        XCTAssertEqual(snapshot(wheel), before.enumerated().map { $0.offset % 2 == 0 ? -$0.element : $0.element })
    }
    func testHorizontalOnlyDoesNotChangeVertical() {
        let wheel = event()
        let before = snapshot(wheel)
        XCTAssertTrue(ScrollReverser.apply(to: wheel, enabled: true, vertical: false, horizontal: true))
        XCTAssertEqual(snapshot(wheel), before.enumerated().map { $0.offset % 2 == 1 ? -$0.element : $0.element })
    }
    func testMouseMovementIsUntouched() {
        let movement = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                               mouseCursorPosition: CGPoint(x: 10, y: 20), mouseButton: .left)!
        let before = movement.data! as Data
        XCTAssertFalse(ScrollReverser.apply(to: movement, enabled: true, vertical: true, horizontal: true))
        XCTAssertEqual(movement.data! as Data, before)
    }
    func testZeroAndMalformedEventsDoNotOverflow() {
        let zero = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 0, wheel2: 0, wheel3: 0)!
        XCTAssertFalse(ScrollReverser.apply(to: zero, enabled: true, vertical: true, horizontal: true))
        let malformed = event()
        malformed.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(Int32.min))
        let before = snapshot(malformed)
        XCTAssertFalse(ScrollReverser.apply(to: malformed, enabled: true, vertical: true, horizontal: true))
        XCTAssertEqual(snapshot(malformed), before)
    }
}
