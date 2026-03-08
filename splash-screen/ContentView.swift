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

// MARK: - Drain Sequence Models

enum DrainPhase {
    case idle
    case subEntering    // submarine glides in from left
    case torpedoFiring  // torpedo travels toward camera
    case impact         // flash + cracks appear
    case draining       // water pours out through shattered glass
    case done           // everything cleared
}

struct GlassShard {
    var points: [CGPoint]   // polygon vertices (normalized 0-1)
    var angle: CGFloat      // current rotation
    var angularVel: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var y: CGFloat          // vertical offset from original position
    var x: CGFloat          // horizontal offset
    var delay: CGFloat      // seconds before this shard starts falling
    var fallen: Bool
}

struct CrackLine {
    var start: CGPoint
    var end: CGPoint
}

struct DrainParticle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var size: CGFloat
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

    // Water pooling
    var waterLevel: CGFloat = 0 // fraction of screen height filled from bottom
    var elapsedTime: CGFloat = 0
    private let maxWaterLevel: CGFloat = 0.45

    // Drain sequence
    var drainPhase: DrainPhase = .idle
    var drainPhaseTime: CGFloat = 0
    var subX: CGFloat = -0.3          // normalized x position of submarine
    var subY: CGFloat = 0.75          // normalized y position (underwater)
    var torpedoScale: CGFloat = 0.1   // grows as torpedo approaches camera
    var torpedoX: CGFloat = 0.0
    var torpedoY: CGFloat = 0.0
    var cracks: [CrackLine] = []
    var shards: [GlassShard] = []
    var drainParticles: [DrainParticle] = []
    var impactFlash: CGFloat = 0
    var impactPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)

    /// Normalized Y position of the water surface (0 = top, 1 = bottom)
    var waterSurfaceNormalized: CGFloat {
        1.0 - waterLevel
    }

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

        updateWater(dt: dt)
        updateLightning(dt: dt)
        updateDrops(dt: dt, size: size)
        updateSplashes(dt: dt, size: size)
        updateRipples(dt: dt)
        updateDrainSequence(dt: dt, size: size)
    }

    private func updateWater(dt: CGFloat) {
        elapsedTime += dt
        // Don't rise water during drain sequence
        guard drainPhase == .idle else { return }
        if intensity > 0 && waterLevel < maxWaterLevel {
            waterLevel = min(waterLevel + 0.004 * intensity * dt, maxWaterLevel)
        }
    }

    /// Returns the water surface Y in screen coordinates at a given x position, with wave motion
    func waterSurfaceY(atScreenX x: CGFloat, screenHeight: CGFloat) -> CGFloat {
        let baseY = waterSurfaceNormalized * screenHeight
        guard waterLevel > 0.005 else { return screenHeight }
        let t = Double(elapsedTime)
        let wave1 = sin(Double(x) * 0.02 + t * 1.8) * 1.5
        let wave2 = cos(Double(x) * 0.035 + t * 1.2) * 0.8
        return baseY + CGFloat(wave1 + wave2)
    }

    private func updateLightning(dt: CGFloat) {
        if lightningFlash > 0 {
            lightningFlash -= dt * 3.0
            if lightningFlash < 0 { lightningFlash = 0 }
        }

        guard intensity > 0.6 else {
            lightningTimer = 2.0
            return
        }

        lightningTimer -= dt
        if lightningTimer <= 0 {
            let stormFactor = (intensity - 0.6) / 0.4
            lightningFlash = CGFloat.random(in: 0.4...0.6) + stormFactor * 0.4
            let maxInterval = 14.0 - stormFactor * 11.0
            let minInterval = 6.0 - stormFactor * 4.5
            lightningTimer = CGFloat.random(in: minInterval...maxInterval)
        }
    }

    private func updateDrops(dt: CGFloat, size: CGSize) {
        // Stop spawning new rain during draining
        guard drainPhase == .idle || drainPhase == .subEntering || drainPhase == .torpedoFiring else { return }
        let active = activeDropCount
        let speed = speedMultiplier
        let surfaceY = waterSurfaceNormalized

        for i in 0..<min(active, drops.count) {
            drops[i].y += (drops[i].speed * speed * dt) / size.height

            let hitY = waterLevel > 0.005 ? surfaceY : 1.03
            if drops[i].y > hitY {
                let screenX = drops[i].x * size.width
                let splashScreenY = waterSurfaceY(atScreenX: screenX, screenHeight: size.height)

                if screenX > -10 && screenX < size.width + 10 {
                    let baseCount = drops[i].thickness > 1.5 ? 3 : 1
                    let waterBonus = waterLevel > 0.005 ? 1.3 : 1.0
                    let splashCount = Int(CGFloat(baseCount) * (0.5 + intensity * 0.8) * waterBonus)
                    for _ in 0..<splashCount {
                        splashes.append(SplashParticle(
                            x: screenX + CGFloat.random(in: -3...3),
                            y: splashScreenY,
                            vx: CGFloat.random(in: -45...45),
                            vy: CGFloat.random(in: -80 ... -10),
                            life: 1.0,
                            size: CGFloat.random(in: 0.6...2.2)
                        ))
                    }

                    if drops[i].depth > 0.3 && ripples.count < Int(80 * intensity + 10) {
                        ripples.append(Ripple(
                            x: screenX,
                            y: splashScreenY,
                            life: 1.0,
                            maxRadius: 3 + drops[i].depth * 12
                        ))
                    }
                }
                drops[i] = makeDrop(fullRangeY: false)
            }
        }
    }

    private func updateSplashes(dt: CGFloat, size: CGSize) {
        var w = 0
        for i in splashes.indices {
            var s = splashes[i]
            s.x += s.vx * dt
            s.y += s.vy * dt
            s.vy += 350 * dt
            s.life -= dt * 3.5

            let surfY = waterSurfaceY(atScreenX: s.x, screenHeight: size.height)
            if s.vy > 0 && s.y >= surfY {
                s.life = 0
            }

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

    // MARK: - Drain Sequence

    func startDrainSequence() {
        guard drainPhase == .idle, waterLevel > 0.01 else { return }
        drainPhase = .subEntering
        drainPhaseTime = 0
        subX = -0.3
        // Position sub underwater, vertically centered in the water pool
        subY = waterSurfaceNormalized + waterLevel * 0.5
    }

    func updateDrainSequence(dt: CGFloat, size: CGSize) {
        guard drainPhase != .idle && drainPhase != .done else { return }
        drainPhaseTime += dt

        switch drainPhase {
        case .subEntering:
            updateSubEntering(dt: dt, size: size)
        case .torpedoFiring:
            updateTorpedoFiring(dt: dt, size: size)
        case .impact:
            updateImpact(dt: dt, size: size)
        case .draining:
            updateDraining(dt: dt, size: size)
        default:
            break
        }
    }

    private func updateSubEntering(dt: CGFloat, size: CGSize) {
        // Glide sub from left to ~40% across screen
        subX += dt * 0.12
        // Gentle bobbing
        subY = waterSurfaceNormalized + waterLevel * 0.5 + sin(drainPhaseTime * 2.0) * 0.01

        if subX >= 0.38 {
            // Fire torpedo
            drainPhase = .torpedoFiring
            drainPhaseTime = 0
            torpedoX = subX + 0.06
            torpedoY = subY
            torpedoScale = 0.15
        }
    }

    private func updateTorpedoFiring(dt: CGFloat, size: CGSize) {
        // Torpedo moves toward center of screen and scales up (approaching camera)
        let targetX: CGFloat = 0.5
        let targetY: CGFloat = 0.5
        let speed: CGFloat = 0.6 + drainPhaseTime * 0.8 // accelerates

        torpedoX += (targetX - torpedoX) * speed * dt * 2.0
        torpedoY += (targetY - torpedoY) * speed * dt * 2.0
        torpedoScale += dt * (0.8 + drainPhaseTime * 2.5) // grows faster as it nears

        if torpedoScale >= 2.5 {
            // Impact!
            drainPhase = .impact
            drainPhaseTime = 0
            impactFlash = 1.0
            impactPoint = CGPoint(x: torpedoX, y: torpedoY)
            generateCracks(size: size)
            generateShards(size: size)
        }
    }

    private func updateImpact(dt: CGFloat, size: CGSize) {
        impactFlash -= dt * 3.0
        if impactFlash < 0 { impactFlash = 0 }

        if drainPhaseTime > 0.4 {
            drainPhase = .draining
            drainPhaseTime = 0
        }
    }

    private func updateDraining(dt: CGFloat, size: CGSize) {
        // Drain water
        let drainRate: CGFloat = 0.15
        waterLevel = max(0, waterLevel - drainRate * dt)

        // Update shard physics
        for i in shards.indices {
            if shards[i].delay > 0 {
                shards[i].delay -= dt
                continue
            }
            if shards[i].fallen { continue }
            shards[i].vy += 600 * dt  // gravity
            shards[i].y += shards[i].vy * dt / size.height
            shards[i].x += shards[i].vx * dt / size.width
            shards[i].angle += shards[i].angularVel * dt
            if shards[i].y > 1.5 {
                shards[i].fallen = true
            }
        }

        // Spawn drain particles at the impact point
        if waterLevel > 0.01 {
            let waterScreenY = waterSurfaceNormalized * size.height
            for _ in 0..<3 {
                drainParticles.append(DrainParticle(
                    x: impactPoint.x * size.width + CGFloat.random(in: -40...40),
                    y: waterScreenY + CGFloat.random(in: -5...5),
                    vx: CGFloat.random(in: -30...30),
                    vy: CGFloat.random(in: 50...200),
                    life: 1.0,
                    size: CGFloat.random(in: 1...3)
                ))
            }
        }

        // Update drain particles
        var w = 0
        for i in drainParticles.indices {
            var p = drainParticles[i]
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.vy += 400 * dt
            p.life -= dt * 2.0
            if p.life > 0 && p.y < size.height + 20 {
                drainParticles[w] = p
                w += 1
            }
        }
        drainParticles.removeSubrange(w...)

        // Impact flash fades
        if impactFlash > 0 {
            impactFlash -= dt * 3.0
            if impactFlash < 0 { impactFlash = 0 }
        }

        if waterLevel <= 0.001 && drainPhaseTime > 1.0 {
            waterLevel = 0
            drainPhase = .done
            // Clean up
            cracks.removeAll()
            shards.removeAll()
            drainParticles.removeAll()
            // Allow restarting
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [self] in
                drainPhase = .idle
            }
        }
    }

    private func generateCracks(size: CGSize) {
        cracks.removeAll()
        let center = impactPoint
        let numRays = Int.random(in: 12...18)
        for i in 0..<numRays {
            let baseAngle = (CGFloat(i) / CGFloat(numRays)) * .pi * 2.0
            let angle = baseAngle + CGFloat.random(in: -0.2...0.2)
            let length = CGFloat.random(in: 0.15...0.45)

            var current = center
            let segments = Int.random(in: 2...4)
            let segLength = length / CGFloat(segments)

            for _ in 0..<segments {
                let jitter = CGFloat.random(in: -0.15...0.15)
                let segAngle = angle + jitter
                let next = CGPoint(
                    x: current.x + cos(segAngle) * segLength,
                    y: current.y + sin(segAngle) * segLength
                )
                cracks.append(CrackLine(start: current, end: next))

                // Branch with 30% chance
                if CGFloat.random(in: 0...1) < 0.3 {
                    let branchAngle = segAngle + CGFloat.random(in: -0.8...0.8)
                    let branchLen = segLength * CGFloat.random(in: 0.3...0.7)
                    let branchEnd = CGPoint(
                        x: current.x + cos(branchAngle) * branchLen,
                        y: current.y + sin(branchAngle) * branchLen
                    )
                    cracks.append(CrackLine(start: current, end: branchEnd))
                }
                current = next
            }
        }
    }

    private func generateShards(size: CGSize) {
        shards.removeAll()
        let center = impactPoint
        let numShards = Int.random(in: 8...14)
        for i in 0..<numShards {
            let baseAngle = (CGFloat(i) / CGFloat(numShards)) * .pi * 2.0
            let dist = CGFloat.random(in: 0.05...0.2)

            // Create a small irregular polygon
            let shardCenter = CGPoint(
                x: center.x + cos(baseAngle) * dist,
                y: center.y + sin(baseAngle) * dist
            )
            let vertCount = Int.random(in: 4...6)
            var pts: [CGPoint] = []
            for v in 0..<vertCount {
                let a = (CGFloat(v) / CGFloat(vertCount)) * .pi * 2.0
                let r = CGFloat.random(in: 0.015...0.05)
                pts.append(CGPoint(
                    x: shardCenter.x + cos(a) * r,
                    y: shardCenter.y + sin(a) * r
                ))
            }

            let awayAngle = atan2(shardCenter.y - center.y, shardCenter.x - center.x)
            shards.append(GlassShard(
                points: pts,
                angle: 0,
                angularVel: CGFloat.random(in: -4...4),
                vx: cos(awayAngle) * CGFloat.random(in: 20...80),
                vy: sin(awayAngle) * CGFloat.random(in: -40...40),
                y: 0,
                x: 0,
                delay: CGFloat(i) * 0.05,
                fallen: false
            ))
        }
    }
}

// MARK: - Views

struct ContentView: View {
    var body: some View {
        RainView()
            .ignoresSafeArea()
    }
}

struct RainView: View {
    @State private var rain = RainSystem()

    private let rainColor = Color(red: 0.7, green: 0.8, blue: 0.95)
    private let splashColor = Color(red: 0.65, green: 0.75, blue: 0.9)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                rain.intensity = RainSettings.shared.intensity
                if RainSettings.shared.drainRequested {
                    RainSettings.shared.drainRequested = false
                    rain.startDrainSequence()
                }
                rain.update(date: timeline.date, size: size)

                drawRainDrops(in: &context, size: size)
                drawSubmarine(in: &context, size: size)
                drawWater(in: &context, size: size)
                drawTorpedo(in: &context, size: size)
                drawRipples(in: &context, size: size)
                drawSplashes(in: &context)
                drawCracks(in: &context, size: size)
                drawShards(in: &context, size: size)
                drawDrainParticles(in: &context)
                drawLightningOverlay(in: &context, size: size)
                drawImpactFlash(in: &context, size: size)
            }
        }
    }

    // MARK: - Drawing

    private func drawRainDrops(in context: inout GraphicsContext, size: CGSize) {
        let active = rain.activeDropCount
        let surfaceBaseY = rain.waterSurfaceNormalized * size.height
        for i in 0..<min(active, rain.drops.count) {
            let drop = rain.drops[i]
            let x = drop.x * size.width
            let bottomY = min(drop.y * size.height, surfaceBaseY)
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

    private func drawWater(in context: inout GraphicsContext, size: CGSize) {
        guard rain.waterLevel > 0.005 else { return }

        let t = Double(rain.elapsedTime)
        let baseY = rain.waterSurfaceNormalized * size.height
        let step: CGFloat = 3

        // Build wavy surface path
        var waterPath = Path()
        for xPos in stride(from: CGFloat(0), through: size.width, by: step) {
            let wave1 = sin(Double(xPos) * 0.02 + t * 1.8) * 1.5
            let wave2 = cos(Double(xPos) * 0.035 + t * 1.2) * 0.8
            let y = baseY + CGFloat(wave1 + wave2)
            if xPos == 0 {
                waterPath.move(to: CGPoint(x: 0, y: y))
            } else {
                waterPath.addLine(to: CGPoint(x: xPos, y: y))
            }
        }
        waterPath.addLine(to: CGPoint(x: size.width, y: size.height))
        waterPath.addLine(to: CGPoint(x: 0, y: size.height))
        waterPath.closeSubpath()

        let depthFactor = min(Double(rain.waterLevel) / 0.2, 1.0)
        let waterGradient = Gradient(stops: [
            .init(color: Color(red: 0.04, green: 0.10, blue: 0.20, opacity: 0.12 * depthFactor), location: 0),
            .init(color: Color(red: 0.03, green: 0.07, blue: 0.16, opacity: 0.20 * depthFactor), location: 0.4),
            .init(color: Color(red: 0.02, green: 0.05, blue: 0.12, opacity: 0.28 * depthFactor), location: 1.0),
        ])
        context.fill(
            waterPath,
            with: .linearGradient(
                waterGradient,
                startPoint: CGPoint(x: 0, y: baseY),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        // Surface highlight line
        var surfaceLine = Path()
        for xPos in stride(from: CGFloat(0), through: size.width, by: step) {
            let wave1 = sin(Double(xPos) * 0.02 + t * 1.8) * 1.5
            let wave2 = cos(Double(xPos) * 0.035 + t * 1.2) * 0.8
            let y = baseY + CGFloat(wave1 + wave2)
            if xPos == 0 {
                surfaceLine.move(to: CGPoint(x: 0, y: y))
            } else {
                surfaceLine.addLine(to: CGPoint(x: xPos, y: y))
            }
        }

        var lineCtx = context
        lineCtx.opacity = 0.25 * depthFactor
        lineCtx.stroke(
            surfaceLine,
            with: .color(Color(red: 0.4, green: 0.55, blue: 0.75)),
            style: StrokeStyle(lineWidth: 1.0)
        )
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

    // MARK: - Drain Sequence Drawing

    private func drawSubmarine(in context: inout GraphicsContext, size: CGSize) {
        guard rain.drainPhase == .subEntering || rain.drainPhase == .torpedoFiring else { return }

        let cx = rain.subX * size.width
        let cy = rain.subY * size.height
        let scale: CGFloat = 0.8

        var path = Path()
        // Hull - elongated ellipse
        let hullW: CGFloat = 120 * scale
        let hullH: CGFloat = 35 * scale
        path.addEllipse(in: CGRect(x: cx - hullW / 2, y: cy - hullH / 2, width: hullW, height: hullH))

        // Conning tower
        let towerW: CGFloat = 25 * scale
        let towerH: CGFloat = 18 * scale
        path.addRoundedRect(
            in: CGRect(x: cx - towerW / 2 + 5, y: cy - hullH / 2 - towerH + 4, width: towerW, height: towerH),
            cornerSize: CGSize(width: 4, height: 4)
        )

        // Periscope
        path.move(to: CGPoint(x: cx + 8, y: cy - hullH / 2 - towerH + 4))
        path.addLine(to: CGPoint(x: cx + 8, y: cy - hullH / 2 - towerH - 8))
        path.addLine(to: CGPoint(x: cx + 14, y: cy - hullH / 2 - towerH - 8))

        // Propeller at back
        let propX = cx - hullW / 2 - 5
        for angle in [CGFloat.pi / 4, -.pi / 4, .pi * 3 / 4, -.pi * 3 / 4] {
            var blade = Path()
            blade.move(to: CGPoint(x: propX, y: cy))
            blade.addLine(to: CGPoint(x: propX + cos(angle + rain.elapsedTime * 8) * 10, y: cy + sin(angle + rain.elapsedTime * 8) * 10))
            var bladeCtx = context
            bladeCtx.opacity = 0.3
            bladeCtx.stroke(blade, with: .color(Color(red: 0.5, green: 0.6, blue: 0.7)), style: StrokeStyle(lineWidth: 2))
        }

        var ctx = context
        ctx.opacity = 0.6
        ctx.fill(path, with: .color(Color(red: 0.15, green: 0.2, blue: 0.3)))
        ctx.opacity = 0.4
        ctx.stroke(path, with: .color(Color(red: 0.3, green: 0.4, blue: 0.55)), style: StrokeStyle(lineWidth: 1.5))

        // Bubbles trailing behind sub
        for i in 0..<6 {
            let bubbleX = cx - hullW / 2 - CGFloat(i) * 12 - CGFloat.random(in: 0...8)
            let bubbleY = cy + CGFloat.random(in: -10...10) - CGFloat(i) * 3
            let bubbleR = CGFloat.random(in: 2...5)
            var bCtx = context
            bCtx.opacity = 0.2 - Double(i) * 0.025
            bCtx.stroke(
                Path(ellipseIn: CGRect(x: bubbleX - bubbleR, y: bubbleY - bubbleR, width: bubbleR * 2, height: bubbleR * 2)),
                with: .color(Color(red: 0.5, green: 0.7, blue: 0.85)),
                style: StrokeStyle(lineWidth: 0.8)
            )
        }
    }

    private func drawTorpedo(in context: inout GraphicsContext, size: CGSize) {
        guard rain.drainPhase == .torpedoFiring else { return }

        let cx = rain.torpedoX * size.width
        let cy = rain.torpedoY * size.height
        let s = rain.torpedoScale

        // Torpedo body - gets bigger as it approaches
        let bodyW: CGFloat = 40 * s
        let bodyH: CGFloat = 10 * s

        var path = Path()
        // Main body
        path.addRoundedRect(
            in: CGRect(x: cx - bodyW / 2, y: cy - bodyH / 2, width: bodyW, height: bodyH),
            cornerSize: CGSize(width: bodyH / 2, height: bodyH / 2)
        )
        // Nose cone (pointed)
        path.move(to: CGPoint(x: cx + bodyW / 2, y: cy - bodyH / 2))
        path.addLine(to: CGPoint(x: cx + bodyW / 2 + bodyH * 0.6, y: cy))
        path.addLine(to: CGPoint(x: cx + bodyW / 2, y: cy + bodyH / 2))
        path.closeSubpath()

        // Tail fins
        let tailX = cx - bodyW / 2
        path.move(to: CGPoint(x: tailX, y: cy - bodyH / 2))
        path.addLine(to: CGPoint(x: tailX - bodyH * 0.4, y: cy - bodyH))
        path.addLine(to: CGPoint(x: tailX + bodyH * 0.2, y: cy - bodyH / 2))
        path.move(to: CGPoint(x: tailX, y: cy + bodyH / 2))
        path.addLine(to: CGPoint(x: tailX - bodyH * 0.4, y: cy + bodyH))
        path.addLine(to: CGPoint(x: tailX + bodyH * 0.2, y: cy + bodyH / 2))

        var ctx = context
        ctx.opacity = min(Double(s), 1.0)
        ctx.fill(path, with: .color(Color(red: 0.25, green: 0.3, blue: 0.35)))
        ctx.stroke(path, with: .color(Color(red: 0.4, green: 0.45, blue: 0.5)), style: StrokeStyle(lineWidth: max(1, s)))

        // Bubble trail behind torpedo
        let trailCount = Int(min(s * 8, 15))
        for i in 0..<trailCount {
            let offset = CGFloat(i) * 8 * s * 0.3
            let bx = cx - bodyW / 2 - offset + CGFloat.random(in: -3...3) * s
            let by = cy + CGFloat.random(in: -5...5) * s
            let br = CGFloat.random(in: 1...3) * s * 0.5
            var bCtx = context
            bCtx.opacity = 0.3 - Double(i) * 0.02
            bCtx.stroke(
                Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)),
                with: .color(Color(red: 0.6, green: 0.75, blue: 0.9)),
                style: StrokeStyle(lineWidth: 0.8)
            )
        }
    }

    private func drawCracks(in context: inout GraphicsContext, size: CGSize) {
        guard rain.drainPhase == .impact || rain.drainPhase == .draining else { return }
        guard !rain.cracks.isEmpty else { return }

        for crack in rain.cracks {
            var path = Path()
            path.move(to: CGPoint(x: crack.start.x * size.width, y: crack.start.y * size.height))
            path.addLine(to: CGPoint(x: crack.end.x * size.width, y: crack.end.y * size.height))

            // White crack line
            var ctx = context
            ctx.opacity = 0.7
            ctx.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

            // Subtle glow
            var glowCtx = context
            glowCtx.opacity = 0.2
            glowCtx.stroke(path, with: .color(Color(red: 0.8, green: 0.9, blue: 1.0)), style: StrokeStyle(lineWidth: 5.0, lineCap: .round))
        }
    }

    private func drawShards(in context: inout GraphicsContext, size: CGSize) {
        guard rain.drainPhase == .draining else { return }

        for shard in rain.shards {
            guard shard.delay <= 0, !shard.fallen else { continue }

            var path = Path()
            for (j, pt) in shard.points.enumerated() {
                let screenPt = CGPoint(
                    x: (pt.x + shard.x) * size.width,
                    y: (pt.y + shard.y) * size.height
                )
                if j == 0 { path.move(to: screenPt) }
                else { path.addLine(to: screenPt) }
            }
            path.closeSubpath()

            // Calculate center for rotation
            let centerX = shard.points.reduce(0) { $0 + $1.x } / CGFloat(shard.points.count)
            let centerY = shard.points.reduce(0) { $0 + $1.y } / CGFloat(shard.points.count)
            let screenCenter = CGPoint(
                x: (centerX + shard.x) * size.width,
                y: (centerY + shard.y) * size.height
            )

            var ctx = context
            ctx.translateBy(x: screenCenter.x, y: screenCenter.y)
            ctx.rotate(by: .radians(shard.angle))
            ctx.translateBy(x: -screenCenter.x, y: -screenCenter.y)

            ctx.opacity = 0.3
            ctx.fill(path, with: .color(Color(red: 0.7, green: 0.85, blue: 1.0)))
            ctx.opacity = 0.5
            ctx.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 1.0))
        }
    }

    private func drawDrainParticles(in context: inout GraphicsContext) {
        guard rain.drainPhase == .draining else { return }

        for p in rain.drainParticles {
            let alpha = Double(p.life) * 0.4
            var ctx = context
            ctx.opacity = alpha
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - p.size, y: p.y - p.size, width: p.size * 2, height: p.size * 2)),
                with: .color(Color(red: 0.3, green: 0.5, blue: 0.7))
            )
        }
    }

    private func drawImpactFlash(in context: inout GraphicsContext, size: CGSize) {
        guard rain.impactFlash > 0.01 else { return }

        let alpha = Double(rain.impactFlash) * 0.5
        var ctx = context
        ctx.opacity = alpha
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(.white)
        )
    }
}

#Preview {
    ContentView()
}
