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
    @Published var intensity: CGFloat = 0.5
}

@main
struct splash_screenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cloud.rain.fill", accessibilityDescription: "Rain")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Popover with intensity slider
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 100)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
        self.popover = popover

        // Configure overlay window
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first,
                  let screen = NSScreen.main else { return }

            window.styleMask = [.borderless]
            window.setFrame(screen.frame, display: true)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.ignoresMouseEvents = true
        }
    }

    @objc func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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
    }
}
