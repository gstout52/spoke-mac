import AppKit
import CoreGraphics

/// Listens system-wide for the trigger (a mouse button or a modifier key) using a
/// Quartz event tap. Needs the Accessibility permission. The trigger mouse button is
/// swallowed so it doesn't also do its usual job (like "Back" in a browser).
final class TriggerMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    /// Called on Escape; return true to swallow the key (i.e. while dictating).
    var onEscape: (() -> Bool)?
    /// When set, the next extra mouse button press is reported here instead of triggering.
    var captureMouseButton: ((Int) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var modifierDown = false
    private var otherKeyWhileModifierDown = false

    var isRunning: Bool { tap != nil }

    /// Returns false if the Accessibility permission hasn't been granted yet.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.otherMouseDown, .otherMouseUp, .flagsChanged, .keyDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let monitor = Unmanaged<TriggerMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        tap = newTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let settings = Settings.shared
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)

        case .otherMouseDown, .otherMouseUp:
            let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            if type == .otherMouseDown, let capture = captureMouseButton {
                captureMouseButton = nil
                capture(button)
                return nil
            }
            guard settings.triggerKind == .mouseButton, button == settings.mouseButton else {
                return Unmanaged.passUnretained(event)
            }
            if type == .otherMouseDown { onPress?() } else { onRelease?() }
            return nil

        case .flagsChanged:
            handleModifier(event, settings: settings)
            return Unmanaged.passUnretained(event)

        case .keyDown:
            if modifierDown { otherKeyWhileModifierDown = true }
            if event.getIntegerValueField(.keyboardEventKeycode) == 53, onEscape?() == true {
                return nil
            }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    /// Modifier keys trigger on a clean tap (toggle mode) or press/release (hold mode),
    /// but never when used as part of a shortcut like Right-Command+C.
    private func handleModifier(_ event: CGEvent, settings: Settings) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let (expectedKey, flag): (Int64, CGEventFlags)
        switch settings.triggerKind {
        case .rightOption: (expectedKey, flag) = (61, .maskAlternate)
        case .rightCommand: (expectedKey, flag) = (54, .maskCommand)
        case .fn: (expectedKey, flag) = (63, .maskSecondaryFn)
        case .mouseButton: return
        }
        guard keyCode == expectedKey else {
            if modifierDown { otherKeyWhileModifierDown = true }
            return
        }

        let isDown = flags.contains(flag)
        if isDown && !modifierDown {
            modifierDown = true
            otherKeyWhileModifierDown = false
            if settings.triggerMode == .hold { onPress?() }
        } else if !isDown && modifierDown {
            modifierDown = false
            switch settings.triggerMode {
            case .hold: onRelease?()
            case .toggle: if !otherKeyWhileModifierDown { onPress?() }
            }
        }
    }
}
