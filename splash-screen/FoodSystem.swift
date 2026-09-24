//
//  FoodSystem.swift
//  splash-screen
//

import AppKit
import Combine
import SwiftUI

enum FoodPhase {
    case airborne
    case floating
    case sinking
}

struct FoodFlake {
    let id: Int
    var x: CGFloat           // normalized position within its screen
    var y: CGFloat
    var vx: CGFloat          // points per second
    var vy: CGFloat
    var phase: FoodPhase
    var age: CGFloat
    var floatTime: CGFloat
    var sinkSpeed: CGFloat
    var driftPhase: CGFloat
    var rotation: CGFloat
    var spin: CGFloat
    var size: CGFloat
    var hue: CGFloat
    var brightness: CGFloat
    var fade: CGFloat        // 1 = solid, 0 = gone
    var dying: Bool

    var isEdible: Bool {
        phase != .airborne && !dying
    }
}

struct FoodNibble {
    var x: CGFloat
    var y: CGFloat
    var life: CGFloat // 1 -> 0
}

/// Food on one screen. Any window covering that screen can step, read, and draw it.
final class FoodTank {
    private(set) var flakes: [FoodFlake] = []
    private(set) var nibbles: [FoodNibble] = []

    private var nextID = 0
    private var lastUpdate: Date?
    private let maxFlakeCount = 150
    private let maxAge: CGFloat = 40
    private let bottomY: CGFloat = 0.985

    func dropCluster(atNormalized point: CGPoint, screenSize: CGSize) {
        guard screenSize.width > 0, screenSize.height > 0 else { return }
        for _ in 0..<Int.random(in: 4...7) {
            let offsetX = CGFloat.random(in: -10...10) / screenSize.width
            let offsetY = CGFloat.random(in: -6...6) / screenSize.height
            flakes.append(FoodFlake(
                id: nextID,
                x: point.x + offsetX,
                y: point.y + offsetY,
                vx: CGFloat.random(in: -25...25),
                vy: CGFloat.random(in: -40...10),
                phase: .airborne,
                age: 0,
                floatTime: CGFloat.random(in: 1.5...3.5),
                sinkSpeed: CGFloat.random(in: 8...16),
                driftPhase: CGFloat.random(in: 0...(.pi * 2)),
                rotation: CGFloat.random(in: 0...(.pi * 2)),
                spin: CGFloat.random(in: -4...4),
                size: CGFloat.random(in: 2.5...4.5),
                hue: CGFloat.random(in: 0.03...0.10),
                brightness: CGFloat.random(in: 0.55...0.85),
                fade: 1,
                dying: false
            ))
            nextID += 1
        }
        if flakes.count > maxFlakeCount {
            flakes.removeFirst(flakes.count - maxFlakeCount)
        }
    }

    func flake(id: Int) -> FoodFlake? {
        flakes.first { $0.id == id }
    }

    func eat(id: Int) {
        guard let index = flakes.firstIndex(where: { $0.id == id }) else { return }
        let flake = flakes.remove(at: index)
        nibbles.append(FoodNibble(x: flake.x, y: flake.y, life: 1))
    }

    /// Safe to call from several windows per frame: time advances on the tank's own clock.
    /// `surfaceY` maps a normalized x to the normalized water surface y.
    func update(date: Date, size: CGSize, surfaceY: (CGFloat) -> CGFloat) {
        guard size.width > 0, size.height > 0 else { return }
        guard let last = lastUpdate else {
            lastUpdate = date
            return
        }
        let dt = CGFloat(min(date.timeIntervalSince(last), 1.0 / 20.0))
        guard dt > 0 else { return }
        lastUpdate = date

        updateFlakes(dt: dt, size: size, surfaceY: surfaceY)
        updateNibbles(dt: dt)
    }

    private func updateFlakes(dt: CGFloat, size: CGSize, surfaceY: (CGFloat) -> CGFloat) {
        var w = 0
        for i in flakes.indices {
            var f = flakes[i]
            let surface = surfaceY(f.x)
            let hasWater = surface < bottomY

            if f.phase == .airborne && f.age == 0 && hasWater && f.y > surface {
                f.phase = .sinking
                f.vx *= 0.3
                f.vy = 0
            }
            f.age += dt

            switch f.phase {
            case .airborne:
                f.vy = min(f.vy + 700 * dt, 380)
                f.vx *= max(0, 1 - 1.5 * dt)
                f.x += (f.vx + sin(f.age * 6 + f.driftPhase) * 12) * dt / size.width
                f.y += f.vy * dt / size.height
                f.rotation += f.spin * dt
                if f.y >= min(surface, bottomY) {
                    f.y = min(surface, bottomY)
                    f.vy = 0
                    f.phase = hasWater ? .floating : .sinking
                }

            case .floating:
                if !hasWater {
                    f.phase = .sinking
                    break
                }
                f.vx *= max(0, 1 - 2 * dt)
                f.x += (f.vx + sin(f.age * 1.1 + f.driftPhase) * 3) * dt / size.width
                f.y = surface
                f.rotation += f.spin * 0.1 * dt
                f.floatTime -= dt
                if f.floatTime <= 0 {
                    f.phase = .sinking
                }

            case .sinking:
                if hasWater && f.y < surface - 2 / size.height {
                    f.phase = .airborne
                    break
                }
                f.vx *= max(0, 1 - 2 * dt)
                f.vy += (f.sinkSpeed - f.vy) * min(1, 1.5 * dt)
                f.x += (f.vx + sin(f.age * 1.3 + f.driftPhase) * 5) * dt / size.width
                f.y += f.vy * dt / size.height
                f.rotation += f.spin * 0.3 * dt
            }

            if f.y >= bottomY {
                f.y = bottomY
                f.dying = true
            }
            if f.age > maxAge {
                f.dying = true
            }
            if f.dying {
                f.fade -= dt * 0.5
            }

            if f.fade > 0 {
                flakes[w] = f
                w += 1
            }
        }
        flakes.removeSubrange(w...)
    }

    private func updateNibbles(dt: CGFloat) {
        var w = 0
        for i in nibbles.indices {
            var n = nibbles[i]
            n.life -= dt * 2.2
            if n.life > 0 {
                nibbles[w] = n
                w += 1
            }
        }
        nibbles.removeSubrange(w...)
    }

    // MARK: - Drawing

    func drawFlakes(in context: inout GraphicsContext, size: CGSize) {
        for flake in flakes {
            let px = flake.x * size.width
            let py = flake.y * size.height
            let squash: CGFloat = flake.phase == .floating ? 0.45 : 0.7

            var ctx = context
            ctx.opacity = Double(flake.fade) * 0.9
            ctx.translateBy(x: px, y: py)
            ctx.rotate(by: .radians(Double(flake.rotation)))

            let w = flake.size
            let h = flake.size * squash
            let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
            ctx.fill(
                Path(roundedRect: rect, cornerRadius: h * 0.4),
                with: .color(Color(hue: Double(flake.hue), saturation: 0.7, brightness: Double(flake.brightness)))
            )
        }
    }

    func drawNibbles(in context: inout GraphicsContext, size: CGSize) {
        for nibble in nibbles {
            let px = nibble.x * size.width
            let py = nibble.y * size.height
            let progress = 1 - nibble.life
            let radius = 2 + progress * 6

            var ctx = context
            ctx.opacity = Double(nibble.life * nibble.life) * 0.5
            ctx.stroke(
                Path(ellipseIn: CGRect(x: px - radius, y: py - radius, width: radius * 2, height: radius * 2)),
                with: .color(Color(red: 0.75, green: 0.85, blue: 0.95)),
                style: StrokeStyle(lineWidth: 0.7)
            )

            for k in 0..<3 {
                let angle = CGFloat(k) * 2.1 + 0.4
                let bx = px + cos(angle) * progress * 5
                let by = py - progress * (6 + CGFloat(k) * 3)
                let r: CGFloat = 0.9
                ctx.fill(
                    Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)),
                    with: .color(Color(white: 0.95))
                )
            }
        }
    }
}

/// Owns one food tank per screen so food survives overlay windows being rebuilt.
final class FoodSystem {
    static let shared = FoodSystem()

    let foodDropped = PassthroughSubject<CGDirectDisplayID, Never>()

    private var tanks: [CGDirectDisplayID: FoodTank] = [:]

    func tank(for screenID: CGDirectDisplayID) -> FoodTank {
        if let tank = tanks[screenID] { return tank }
        let tank = FoodTank()
        tanks[screenID] = tank
        return tank
    }

    /// Drops food at a point in AppKit global screen coordinates.
    func drop(atScreenPoint point: CGPoint) {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }),
              let screenID = screen.displayID else { return }
        let frame = screen.frame
        let normalized = CGPoint(
            x: (point.x - frame.minX) / frame.width,
            y: (frame.maxY - point.y) / frame.height
        )
        tank(for: screenID).dropCluster(atNormalized: normalized, screenSize: frame.size)
        foodDropped.send(screenID)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
