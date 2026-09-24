//
//  FeedingMonitor.swift
//  splash-screen
//

import AppKit
import Combine

/// The event tap swallows the click so no context menu opens underneath.
/// Without Accessibility access a passive monitor takes over and the click passes through.
final class FeedingMonitor: ObservableObject {
    static let shared = FeedingMonitor()

    @Published private(set) var capturesClicks = false

    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var accessTimer: Timer?
    private var swallowingClick = false

    func setEnabled(_ enabled: Bool) {
        stop()
        guard enabled else { return }
        if !installTap() {
            installEventMonitors()
        }
        accessTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.followAccessChanges() }
        }
    }

    func requestAccess() {
        if !CGRequestPostEventAccess(),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func stop() {
        accessTimer?.invalidate()
        accessTimer = nil
        removeTap()
        removeEventMonitors()
    }

    /// A live tap blocks clicks system-wide once access is revoked, and AXIsProcessTrusted still says yes.
    private func followAccessChanges() {
        if tap != nil {
            if !canCreateTap() {
                removeTap()
                installEventMonitors()
            }
        } else if installTap() {
            removeEventMonitors()
        }
    }

    private func canCreateTap() -> Bool {
        guard let probe = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.mouseMoved.rawValue),
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) else { return false }
        CFMachPortInvalidate(probe)
        return true
    }

    private func dropFood() {
        FoodSystem.shared.drop(atScreenPoint: NSEvent.mouseLocation)
    }

    // MARK: - Event tap

    private func installTap() -> Bool {
        let mask = (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<FeedingMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return MainActor.assumeIsolated { monitor.handleTapEvent(type: type, event: event) }
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        tapSource = source
        capturesClicks = true
        return true
    }

    private func removeTap() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let tapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes)
        }
        tap = nil
        tapSource = nil
        capturesClicks = false
        swallowingClick = false
    }

    private func handleTapEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .rightMouseDown where event.flags.contains(.maskCommand):
            swallowingClick = true
            dropFood()
            return nil
        case .rightMouseDragged where swallowingClick:
            return nil
        case .rightMouseUp where swallowingClick:
            swallowingClick = false
            return nil
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Passive monitors

    private func installEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            if event.modifierFlags.contains(.command) { self?.dropFood() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            if event.modifierFlags.contains(.command) { self?.dropFood() }
            return event
        }
    }

    private func removeEventMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }
}
