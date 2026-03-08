//
//  ContentView.swift
//  splash-screen
//
//  Created by Mikael Weiss on 3/7/26.
//

import SwiftUI

// MARK: - Data Models

struct RainDrop {
    var x: CGFloat
    var y: CGFloat
    var length: CGFloat
    var speed: CGFloat
    var baseOpacity: Double
    var thickness: CGFloat
    var depth: CGFloat // 0 = far, 1 = near
}

struct SplashParticle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var size: CGFloat
}

struct Ripple {
    var x: CGFloat
    var y: CGFloat
    var life: CGFloat // 1 -> 0
    var maxRadius: CGFloat
}

// MARK: - Rain System

final class RainSystem {
    var drops: [RainDrop] = []
    var splashes: [SplashParticle] = []
    var ripples: [Ripple] = []

    // Intensity: 0 = clear, 1 = thunderstorm
    var intensity: CGFloat = 0.5

    // Lightning
    var lightningFlash: CGFloat = 0
    private var lightningTimer: CGFloat = 6.0

    // Light source position (normalized 0-1), upper center area
    let lightX: CGFloat = 0.5
    let lightY: CGFloat = 0.15
    let lightRadius: CGFloat = 0.45

    private var lastUpdate: Date?
    private let maxDropCount = 700

    /// How many drops are currently active based on intensity
    var activeDropCount: Int {
        Int(CGFloat(maxDropCount) * intensity)
    }

    /// Speed multiplier based on intensity (drizzle = slow, storm = fast)
    var speedMultiplier: CGFloat {
        0.5 + intensity * 1.0
    }

    /// Streak length multiplier: short dots at low intensity, long streaks at high
    var streakMultiplier: CGFloat {
        0.3 + intensity * 0.7
    }

    init() {
        drops.reserveCapacity(maxDropCount)
        splashes.reserveCapacity(400)
        ripples.reserveCapacity(100)
        for _ in 0..<maxDropCount {
            drops.append(makeDrop(fullRangeY: true))
        }
    }

    private func makeDrop(fullRangeY: Bool) -> RainDrop {
        let depth = pow(CGFloat.random(in: 0...1), 0.55)
        return RainDrop(
            x: CGFloat.random(in: -0.25...1.25),
            y: fullRangeY ? CGFloat.random(in: -0.6...1.0) : CGFloat.random(in: -0.7 ... -0.02),
            length: 8 + depth * 35,
            speed: 350 + depth * 1200,
            baseOpacity: 0.02 + depth * 0.25,
            thickness: 0.2 + depth * 2.2,
            depth: depth
        )
    }

    func update(date: Date, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard let last = lastUpdate else {
            lastUpdate = date
            return
        }

        let dt = CGFloat(min(date.timeIntervalSince(last), 1.0 / 20.0))
        lastUpdate = date

        updateLightning(dt: dt)
        updateDrops(dt: dt, size: size)
        updateSplashes(dt: dt)
        updateRipples(dt: dt)
    }

    private func updateLightning(dt: CGFloat) {
        // Decay flash
        if lightningFlash > 0 {
            lightningFlash -= dt * 3.0
            if lightningFlash < 0 { lightningFlash = 0 }
        }

        // Lightning only triggers above 0.6 intensity
        guard intensity > 0.6 else {
            lightningTimer = 2.0
            return
        }

        lightningTimer -= dt
        if lightningTimer <= 0 {
            // Flash strength scales with intensity
            let stormFactor = (intensity - 0.6) / 0.4 // 0-1 within storm range
            lightningFlash = CGFloat.random(in: 0.4...0.6) + stormFactor * 0.4

            // More frequent at higher intensity: 12s at 0.6 → 3s at 1.0
            let maxInterval = 14.0 - stormFactor * 11.0
            let minInterval = 6.0 - stormFactor * 4.5
            lightningTimer = CGFloat.random(in: minInterval...maxInterval)
        }
    }

    private func updateDrops(dt: CGFloat, size: CGSize) {
        let active = activeDropCount
        let speed = speedMultiplier

        for i in 0..<min(active, drops.count) {
            drops[i].y += (drops[i].speed * speed * dt) / size.height

            if drops[i].y > 1.03 {
                let screenX = drops[i].x * size.width
                if screenX > -10 && screenX < size.width + 10 {
                    // Splash particles — more at higher intensity
                    let baseCount = drops[i].thickness > 1.5 ? 3 : 1
                    let splashCount = Int(CGFloat(baseCount) * (0.5 + intensity * 0.8))
                    for _ in 0..<splashCount {
                        splashes.append(SplashParticle(
                            x: screenX + CGFloat.random(in: -3...3),
                            y: size.height,
                            vx: CGFloat.random(in: -45...45),
                            vy: CGFloat.random(in: -80 ... -10),
                            life: 1.0,
                            size: CGFloat.random(in: 0.6...2.2)
                        ))
                    }

                    // Ripple on ground
                    if drops[i].depth > 0.3 && ripples.count < Int(80 * intensity + 10) {
                        ripples.append(Ripple(
                            x: screenX,
                            y: size.height - CGFloat.random(in: 0...8),
                            life: 1.0,
                            maxRadius: 3 + drops[i].depth * 12
                        ))
                    }
                }
                drops[i] = makeDrop(fullRangeY: false)
            }
        }
    }

    private func updateSplashes(dt: CGFloat) {
        var w = 0
        for i in splashes.indices {
            var s = splashes[i]
            s.x += s.vx * dt
            s.y += s.vy * dt
            s.vy += 350 * dt
            s.life -= dt * 3.5
            if s.life > 0 {
                splashes[w] = s
                w += 1
            }
        }
        splashes.removeSubrange(w...)
    }

    private func updateRipples(dt: CGFloat) {
        var w = 0
        for i in ripples.indices {
            var r = ripples[i]
            r.life -= dt * 2.5
            if r.life > 0 {
                ripples[w] = r
                w += 1
            }
        }
        ripples.removeSubrange(w...)
    }

    func lightIntensity(nx: CGFloat, ny: CGFloat) -> CGFloat {
        let dx = nx - lightX
        let dy = ny - lightY
        let dist = sqrt(dx * dx + dy * dy)
        let falloff = max(0, 1.0 - dist / lightRadius)
        return falloff * falloff
    }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Views

struct ContentView: View {
    @State private var intensity: CGFloat = 0.5

    var body: some View {
        ZStack(alignment: .bottom) {
            RainView(intensity: $intensity)
                .ignoresSafeArea()

            // Intensity slider
            HStack(spacing: 12) {
                Image(systemName: "cloud")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                Slider(value: $intensity, in: 0...1)
                    .tint(Color(red: 0.5, green: 0.6, blue: 0.8))

                Image(systemName: "cloud.bolt.rain.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .preferredColorScheme(.dark)
    }
}

struct RainView: View {
    @Binding var intensity: CGFloat
    @State private var rain = RainSystem()

    // Cinematic blue-teal rain color
    private let rainColor = Color(red: 0.7, green: 0.8, blue: 0.95)
    private let splashColor = Color(red: 0.65, green: 0.75, blue: 0.9)

    var body: some View {
        ZStack {
            VisualEffectBackground()
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    rain.intensity = intensity
                    rain.update(date: timeline.date, size: size)
                    drawDarkOverlay(in: &context, size: size)
                    drawLightGlow(in: &context, size: size)
                    drawRipples(in: &context, size: size)
                    drawRainDrops(in: &context, size: size)
                    drawSplashes(in: &context)
                    drawAtmosphere(in: &context, size: size)
                    drawLightningOverlay(in: &context, size: size)
                }
            }
        }
    }

    // MARK: - Drawing

    private func drawDarkOverlay(in context: inout GraphicsContext, size: CGSize) {
        // Darker at higher intensity (stormier sky), lighter when clear
        let alpha = 0.15 + Double(intensity) * 0.35
        var ctx = context
        ctx.opacity = alpha
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(red: 0.01, green: 0.02, blue: 0.06))
        )
    }

    private func drawLightGlow(in context: inout GraphicsContext, size: CGSize) {
        guard intensity > 0.05 else { return }

        let centerX = rain.lightX * size.width
        let centerY = rain.lightY * size.height
        let glowRadius = rain.lightRadius * max(size.width, size.height)

        let glowOpacity = 0.08 + Double(intensity) * 0.12
        let gradient = Gradient(stops: [
            .init(color: Color(red: 0.15, green: 0.18, blue: 0.25, opacity: glowOpacity), location: 0),
            .init(color: Color(red: 0.08, green: 0.10, blue: 0.15, opacity: glowOpacity * 0.5), location: 0.4),
            .init(color: .clear, location: 1.0),
        ])

        context.fill(
            Path(ellipseIn: CGRect(
                x: centerX - glowRadius,
                y: centerY - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            )),
            with: .radialGradient(
                gradient,
                center: CGPoint(x: centerX, y: centerY),
                startRadius: 0,
                endRadius: glowRadius
            )
        )
    }

    private func drawRainDrops(in context: inout GraphicsContext, size: CGSize) {
        let active = rain.activeDropCount
        for i in 0..<min(active, rain.drops.count) {
            let drop = rain.drops[i]
            let x = drop.x * size.width
            let bottomY = drop.y * size.height
            let streakLength = drop.length * rain.streakMultiplier
            let topY = bottomY - streakLength

            guard bottomY > -drop.length, topY < size.height + drop.length else { continue }
            guard x > -30, x < size.width + 30 else { continue }

            let lightBoost = rain.lightIntensity(nx: drop.x, ny: drop.y)
            let litOpacity = drop.baseOpacity + Double(lightBoost) * 0.45
            let flashBoost = Double(rain.lightningFlash) * 0.3
            let finalOpacity = min(litOpacity + flashBoost, 0.85)

            var path = Path()
            path.move(to: CGPoint(x: x, y: topY))
            path.addLine(to: CGPoint(x: x, y: bottomY))

            var dropCtx = context
            dropCtx.opacity = finalOpacity
            dropCtx.stroke(
                path,
                with: .color(rainColor),
                style: StrokeStyle(lineWidth: drop.thickness, lineCap: .round)
            )
        }
    }

    private func drawSplashes(in context: inout GraphicsContext) {
        for splash in rain.splashes {
            let alpha = Double(splash.life * splash.life) * 0.45
            let radius = splash.size * max(splash.life, 0.15)

            var ctx = context
            ctx.opacity = alpha
            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: splash.x - radius,
                    y: splash.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .color(splashColor)
            )
        }
    }

    private func drawRipples(in context: inout GraphicsContext, size: CGSize) {
        for ripple in rain.ripples {
            let progress = 1.0 - ripple.life
            let radius = ripple.maxRadius * progress
            let alpha = Double(ripple.life * ripple.life) * 0.3

            let ellipseW = radius * 2
            let ellipseH = radius * 0.6

            var ctx = context
            ctx.opacity = alpha
            ctx.stroke(
                Path(ellipseIn: CGRect(
                    x: ripple.x - ellipseW / 2,
                    y: ripple.y - ellipseH / 2,
                    width: ellipseW,
                    height: ellipseH
                )),
                with: .color(Color(red: 0.5, green: 0.6, blue: 0.75)),
                style: StrokeStyle(lineWidth: 0.8)
            )
        }
    }

    private func drawAtmosphere(in context: inout GraphicsContext, size: CGSize) {
        // Mist scales with intensity
        let mistAlpha = Double(intensity) * 0.1
        let mistGradient = Gradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: Color(red: 0.08, green: 0.10, blue: 0.16, opacity: mistAlpha * 0.6), location: 0.5),
            .init(color: Color(red: 0.10, green: 0.13, blue: 0.20, opacity: mistAlpha), location: 1.0),
        ])
        let mistTop = size.height * 0.68
        context.fill(
            Path(CGRect(x: 0, y: mistTop, width: size.width, height: size.height - mistTop)),
            with: .linearGradient(
                mistGradient,
                startPoint: CGPoint(x: 0, y: mistTop),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    private func drawLightningOverlay(in context: inout GraphicsContext, size: CGSize) {
        guard rain.lightningFlash > 0.01 else { return }

        let alpha = Double(rain.lightningFlash * rain.lightningFlash) * 0.15
        var ctx = context
        ctx.opacity = alpha
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(red: 0.7, green: 0.75, blue: 0.9))
        )
    }
}

#Preview {
    ContentView()
}
