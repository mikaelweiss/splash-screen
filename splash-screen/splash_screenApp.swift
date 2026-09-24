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
    @Published var fishInFront: Bool {
        didSet { UserDefaults.standard.set(fishInFront, forKey: "fishInFront") }
    }
    @Published var feedingEnabled: Bool {
        didSet { UserDefaults.standard.set(feedingEnabled, forKey: "feedingEnabled") }
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
        self.fishInFront = defaults.bool(forKey: "fishInFront")
        self.feedingEnabled = defaults.bool(forKey: "feedingEnabled")
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
    var fishWindows: [NSWindow] = []
    private var fishVisibilityCancellable: AnyCancellable?
    private var feedingSubscription: AnyCancellable?

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
        popover.contentSize = NSSize(width: 280, height: 128)
        popover.behavior = .transient
        popover.delegate = self
        let menuController = NSHostingController(rootView: MenuBarView())
        menuController.sizingOptions = .preferredContentSize
        popover.contentViewController = menuController
        self.popover = popover

        // Create overlay windows directly — one per screen
        createOverlayWindows()

        feedingSubscription = RainSettings.shared.$feedingEnabled
            .combineLatest(RainSettings.shared.$fishEnabled)
            .map { feeding, fish in feeding && fish }
            .removeDuplicates()
            .sink { enabled in
                FeedingMonitor.shared.setEnabled(enabled)
            }

        // Recreate overlays when monitors change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        let settings = RainSettings.shared
        fishVisibilityCancellable = settings.$fishEnabled
            .combineLatest(settings.$fishInFront)
            .sink { [weak self] enabled, inFront in
                self?.updateFishWindowVisibility(visible: enabled && !inFront)
            }
    }

    func createOverlayWindows() {
        closeOverlayWindows()

        let fishLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        for screen in NSScreen.screens {
            let screenID = screen.displayID ?? 0
            let rain = RainSystem(food: FoodSystem.shared.tank(for: screenID))
            fishWindows.append(makeOverlayWindow(screen: screen, level: fishLevel, rain: rain, layer: .fish, screenID: screenID))
            overlayWindows.append(makeOverlayWindow(screen: screen, level: .screenSaver, rain: rain, layer: .water, screenID: screenID))
        }

        let settings = RainSettings.shared
        updateFishWindowVisibility(visible: settings.fishEnabled && !settings.fishInFront)
        overlayWindows.forEach { $0.orderFrontRegardless() }
    }

    private func closeOverlayWindows() {
        for window in overlayWindows + fishWindows {
            window.contentView = nil
            window.close()
        }
        overlayWindows.removeAll()
        fishWindows.removeAll()
    }

    private func makeOverlayWindow(
        screen: NSScreen,
        level: NSWindow.Level,
        rain: RainSystem,
        layer: OverlayLayer,
        screenID: CGDirectDisplayID
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = level
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.canHide = false
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ContentView(rain: rain, layer: layer, screenID: screenID))
        return window
    }

    private func updateFishWindowVisibility(visible: Bool) {
        for window in fishWindows {
            if visible {
                window.orderFrontRegardless()
            } else {
                window.orderOut(nil)
            }
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
    @ObservedObject private var feedingMonitor = FeedingMonitor.shared

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

            HStack {
                Toggle("Fish in front of windows", isOn: $settings.fishInFront)
                    .toggleStyle(.checkbox)
                    .controlSize(.mini)
                    .font(.system(size: 11))
                    .disabled(!settings.fishEnabled)

                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $settings.feedingEnabled) {
                    Text("Feed the Fish")
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(!settings.fishEnabled)

                Text("Hold Command and right-click to drop food")
                    .font(.system(size: 10))
                    .foregroundStyle(settings.fishEnabled ? .secondary : .tertiary)

                if settings.feedingEnabled && settings.fishEnabled && !feedingMonitor.capturesClicks {
                    Text("The app under the cursor also gets the click. Allow Accessibility access to keep it for the fish.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Open Accessibility Settings") {
                        feedingMonitor.requestAccess()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .font(.system(size: 10))
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
