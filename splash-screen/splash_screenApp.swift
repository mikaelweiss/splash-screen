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
struct splash_screenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var overlayWindows: [NSWindow] = []

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

        // Create overlay windows directly — one per screen
        createOverlayWindows()

        // Recreate overlays when monitors change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func createOverlayWindows() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = true
            window.canHide = false
            window.contentView = NSHostingView(rootView: ContentView())
            window.orderFrontRegardless()

            overlayWindows.append(window)
        }
    }

    @objc func screensChanged() {
        createOverlayWindows()
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
