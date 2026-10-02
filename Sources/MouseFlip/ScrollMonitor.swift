import ApplicationServices
import ScrollCore

final class ScrollMonitor {
    var enabled = true
    var vertical = true
    var horizontal = false
    private(set) var reversedCount = 0
    private(set) var preservedCount = 0
    private(set) var failure: String?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var running: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func refresh() {
        guard AXIsProcessTrusted() else {
            stop()
            failure = "等待辅助功能权限"
            return
        }
        if let tap {
            if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask,
            callback: { _, type, event, pointer in
                guard let pointer else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<ScrollMonitor>.fromOpaque(pointer).takeUnretainedValue()
                if type == .tapDisabledByTimeout {
                    if let tap = monitor.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }
                if ScrollReverser.apply(to: event, enabled: monitor.enabled,
                                        vertical: monitor.vertical, horizontal: monitor.horizontal) {
                    monitor.reversedCount += 1
                } else {
                    monitor.preservedCount += 1
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            failure = "无法监听滚动，请重新授权或重启应用"
            return
        }
        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0) else {
            CFMachPortInvalidate(created)
            failure = "无法创建事件监听"
            return
        }
        tap = created
        source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        failure = nil
    }

    func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
    }
}
