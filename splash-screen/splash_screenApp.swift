//
//  splash_screenApp.swift
//  splash-screen
//
//  Created by Mikael Weiss on 3/7/26.
//

import Combine
import SwiftUI

/// Shared intensity value accessible from both the menu bar popover and the rain overlay
class RainSettings: ObservableObject {
    static let shared = RainSettings()

    @Published var intensity: CGFloat {
        didSet { UserDefaults.standard.set(Double(intensity), forKey: "rainIntensity") }
    }
    @Published var drainGeneration: Int = 0
    @Published var fishEnabled: Bool {
        didSet { UserDefaults.standard.set(fishEnabled, forKey: "fishEnabled") }
    }
    @Published var waterLevelEnabled: Bool {
        didSet { UserDefaults.standard.set(waterLevelEnabled, forKey: "waterLevelEnabled") }
    }

    private init() {
        let defaults = UserDefaults.standard
        // Use object(forKey:) to distinguish "not set" from "explicitly set to 0"
        self.intensity = defaults.object(forKey: "rainIntensity") != nil
            ? CGFloat(defaults.double(forKey: "rainIntensity"))
            : 0.5
        self.fishEnabled = defaults.bool(forKey: "fishEnabled")
        self.waterLevelEnabled = defaults.object(forKey: "waterLevelEnabled") != nil
            ? defaults.bool(forKey: "waterLevelEnabled")
            : true
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var overlayWindows: [NSScreen: NSWindow] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cloud.rain.fill", accessibilityDescription: "Rain")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Popover with controls
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 100)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
        self.popover = popover

        // Create one overlay window per screen
        for screen in NSScreen.screens {
            createOverlayWindow(for: screen)
        }

        startScreenshotMonitoring()
        startScreenChangeMonitoring()
    }

    private func createOverlayWindow(for screen: NSScreen) {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: ContentView())
        window.setFrame(screen.frame, display: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.sharingType = .none
        window.orderFrontRegardless()
        overlayWindows[screen] = window
    }

    // MARK: - Screenshot Detection

    private var screenshotPollTimer: Timer?
    private var wasHiddenForScreenshot = false

    private func startScreenshotMonitoring() {
        screenshotPollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            let screenshotActive = self.isScreenshotUIRunning()
            if screenshotActive && !self.wasHiddenForScreenshot {
                self.wasHiddenForScreenshot = true
                for window in self.overlayWindows.values {
                    window.orderOut(nil)
                }
            } else if !screenshotActive && self.wasHiddenForScreenshot {
                self.wasHiddenForScreenshot = false
                for window in self.overlayWindows.values {
                    window.orderFrontRegardless()
                }
            }
        }
    }

    // MARK: - Screen Change Detection

    private func startScreenChangeMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        let currentScreens = Set(NSScreen.screens)

        // Remove windows for disconnected screens
        for screen in overlayWindows.keys where !currentScreens.contains(screen) {
            overlayWindows[screen]?.orderOut(nil)
            overlayWindows.removeValue(forKey: screen)
        }

        // Add windows for new screens, resize existing ones
        for screen in currentScreens {
            if let window = overlayWindows[screen] {
                window.setFrame(screen.frame, display: true)
            } else {
                createOverlayWindow(for: screen)
            }
        }
    }

    private func isScreenshotUIRunning() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return windowList.contains { info in
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""
            return owner == "screencaptureui" || owner == "Screenshot"
        }
    }

    @objc func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

struct MenuBarView: View {
    @ObservedObject private var settings = RainSettings.shared

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "cloud")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Slider(value: $settings.intensity, in: 0...1)

                Image(systemName: "cloud.bolt.rain.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Drain") {
                    settings.drainGeneration += 1
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .font(.system(size: 11))

                Spacer()

                Toggle(isOn: $settings.waterLevelEnabled) {
                    Image(systemName: "water.waves")
                        .font(.system(size: 10))
                }
                .toggleStyle(.switch)
                .controlSize(.mini)

                Spacer()

                Toggle(isOn: $settings.fishEnabled) {
                    Image(systemName: "fish.fill")
                        .font(.system(size: 10))
                }
                .toggleStyle(.switch)
                .controlSize(.mini)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
