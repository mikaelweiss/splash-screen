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
    var width: CGFloat          // thick near impact, thin at tips
    var controlOffset: CGPoint  // perpendicular offset for bezier curve
    var distFromCenter: CGFloat // normalized distance from impact point
}

struct DrainParticle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var size: CGFloat
}

struct DebrisParticle {
    var x: CGFloat  // normalized
    var y: CGFloat  // normalized
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var size: CGFloat
    var rotation: CGFloat
    var rotationSpeed: CGFloat
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
    var debrisParticles: [DebrisParticle] = []
    var impactFlash: CGFloat = 0
    var impactPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var crackProgress: CGFloat = 0      // 0-1, animates crack extension
    var screenShakeX: CGFloat = 0
    var screenShakeY: CGFloat = 0
    var screenShakeIntensity: CGFloat = 0

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
            crackProgress = 0
            screenShakeIntensity = 1.0
            generateCracks(size: size)
            generateShards(size: size)
            generateDebris()
        }
    }

    private func updateImpact(dt: CGFloat, size: CGSize) {
        impactFlash -= dt * 3.0
        if impactFlash < 0 { impactFlash = 0 }

        // Animate crack propagation
        crackProgress = min(1.0, crackProgress + dt * 7.0)

        // Screen shake
        if screenShakeIntensity > 0 {
            screenShakeIntensity -= dt * 4.0
            if screenShakeIntensity < 0 { screenShakeIntensity = 0 }
            screenShakeX = CGFloat.random(in: -4...4) * screenShakeIntensity
            screenShakeY = CGFloat.random(in: -4...4) * screenShakeIntensity
        }

        // Update debris
        updateDebris(dt: dt)

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

        // Spawn drain particles along crack lines (water flows through cracks)
        if waterLevel > 0.01 && !cracks.isEmpty {
            for _ in 0..<5 {
                guard let crack = cracks.randomElement() else { continue }

                // Position along crack, biased toward endpoint
                let t = CGFloat.random(in: 0.3...1.0)
                let spawnNormX = crack.start.x + (crack.end.x - crack.start.x) * t
                let spawnNormY = crack.start.y + (crack.end.y - crack.start.y) * t

                // Lower cracks get more water flow (gravity)
                let verticalWeight = max(0.1, spawnNormY - 0.3)
                if CGFloat.random(in: 0...1) > verticalWeight * 2.5 { continue }

                // Direction follows crack outward from impact
                let dx = crack.end.x - crack.start.x
                let dy = crack.end.y - crack.start.y
                let len = sqrt(dx * dx + dy * dy)
                let dirX = len > 0.001 ? dx / len : 0
                let dirY = len > 0.001 ? dy / len : 0

                let screenX = spawnNormX * size.width
                let screenY = spawnNormY * size.height

                drainParticles.append(DrainParticle(
                    x: screenX + CGFloat.random(in: -2...2),
                    y: screenY + CGFloat.random(in: -2...2),
                    vx: dirX * CGFloat.random(in: 15...50) + CGFloat.random(in: -8...8),
                    vy: max(dirY * 20, 0) + CGFloat.random(in: 40...120),
                    life: 1.0,
                    size: CGFloat.random(in: 1...3)
                ))
            }

            // Drip formation at lowest crack endpoints
            for crack in cracks {
                if crack.end.y > 0.5 && crack.width > 1.0 && CGFloat.random(in: 0...1) < 0.015 {
                    drainParticles.append(DrainParticle(
                        x: crack.end.x * size.width,
                        y: crack.end.y * size.height,
                        vx: CGFloat.random(in: -2...2),
                        vy: CGFloat.random(in: 5...15),
                        life: 1.5,
                        size: CGFloat.random(in: 2.5...4.5)
                    ))
                }
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

        // Update remaining debris
        updateDebris(dt: dt)

        // Screen shake decay (should be nearly zero by now)
        if screenShakeIntensity > 0 {
            screenShakeIntensity -= dt * 4.0
            if screenShakeIntensity < 0 { screenShakeIntensity = 0 }
            screenShakeX = CGFloat.random(in: -4...4) * screenShakeIntensity
            screenShakeY = CGFloat.random(in: -4...4) * screenShakeIntensity
        }

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
            debrisParticles.removeAll()
            crackProgress = 0
            screenShakeIntensity = 0
            // Allow restarting
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [self] in
                drainPhase = .idle
            }
        }
    }

    private func generateCracks(size: CGSize) {
        cracks.removeAll()
        let center = impactPoint
        let numRays = Int.random(in: 14...20)

        var rayAngles: [CGFloat] = []

        // Radial cracks
        for i in 0..<numRays {
            let baseAngle = (CGFloat(i) / CGFloat(numRays)) * .pi * 2.0
            let angle = baseAngle + CGFloat.random(in: -0.15...0.15)
            rayAngles.append(angle)
            let length = CGFloat.random(in: 0.18...0.5)

            var current = center
            let segments = Int.random(in: 3...5)
            let segLength = length / CGFloat(segments)

            for _ in 0..<segments {
                let jitter = CGFloat.random(in: -0.12...0.12)
                let segAngle = angle + jitter
                let next = CGPoint(
                    x: current.x + cos(segAngle) * segLength,
                    y: current.y + sin(segAngle) * segLength
                )

                let dist = sqrt(pow(current.x - center.x, 2) + pow(current.y - center.y, 2))
                let tipDist = sqrt(pow(next.x - center.x, 2) + pow(next.y - center.y, 2))
                let avgDist = (dist + tipDist) / 2.0

                // Width tapers: thick near impact, thin at tips
                let widthFactor = max(0, 1.0 - avgDist / length)
                let width: CGFloat = 0.5 + 3.0 * widthFactor

                // Bezier control offset (perpendicular to segment direction)
                let dx = next.x - current.x
                let dy = next.y - current.y
                let segLen = sqrt(dx * dx + dy * dy)
                let perpX = segLen > 0.001 ? -dy / segLen : 0
                let perpY = segLen > 0.001 ? dx / segLen : 0
                let offsetMag = CGFloat.random(in: -0.008...0.008)

                cracks.append(CrackLine(
                    start: current,
                    end: next,
                    width: width,
                    controlOffset: CGPoint(x: perpX * offsetMag, y: perpY * offsetMag),
                    distFromCenter: avgDist
                ))

                // Branch with 30% chance
                if CGFloat.random(in: 0...1) < 0.3 {
                    let branchAngle = segAngle + CGFloat.random(in: -0.8...0.8)
                    let branchLen = segLength * CGFloat.random(in: 0.3...0.6)
                    let branchEnd = CGPoint(
                        x: current.x + cos(branchAngle) * branchLen,
                        y: current.y + sin(branchAngle) * branchLen
                    )
                    let bDist = sqrt(pow(branchEnd.x - center.x, 2) + pow(branchEnd.y - center.y, 2))
                    let bOffsetMag = CGFloat.random(in: -0.005...0.005)
                    cracks.append(CrackLine(
                        start: current,
                        end: branchEnd,
                        width: max(0.4, width * 0.6),
                        controlOffset: CGPoint(x: perpX * bOffsetMag, y: perpY * bOffsetMag),
                        distFromCenter: bDist
                    ))
                }

                current = next
            }
        }

        // Concentric ring cracks (spider-web effect)
        let ringRadii: [CGFloat] = [0.08, 0.18, 0.32]
        let sortedAngles = rayAngles.sorted()
        for radius in ringRadii {
            for idx in 0..<sortedAngles.count {
                let nextIdx = (idx + 1) % sortedAngles.count
                let angle1 = sortedAngles[idx]
                var angle2 = sortedAngles[nextIdx]
                if angle2 <= angle1 { angle2 += .pi * 2 }

                let angleDiff = angle2 - angle1
                if angleDiff < 0.15 || angleDiff > .pi { continue }

                // Skip some arcs randomly for organic feel
                if CGFloat.random(in: 0...1) < 0.25 { continue }

                let p1 = CGPoint(
                    x: center.x + cos(angle1) * radius + CGFloat.random(in: -0.008...0.008),
                    y: center.y + sin(angle1) * radius + CGFloat.random(in: -0.008...0.008)
                )
                let p2 = CGPoint(
                    x: center.x + cos(angle2) * radius + CGFloat.random(in: -0.008...0.008),
                    y: center.y + sin(angle2) * radius + CGFloat.random(in: -0.008...0.008)
                )

                // Control point pushes outward for arc shape
                let midAngle = (angle1 + angle2) / 2.0
                let controlRadius = radius / cos(angleDiff / 2.0)
                let controlX = center.x + cos(midAngle) * controlRadius
                let controlY = center.y + sin(midAngle) * controlRadius
                let chordMidX = (p1.x + p2.x) / 2.0
                let chordMidY = (p1.y + p2.y) / 2.0

                let arcWidth: CGFloat = max(0.3, 1.8 - radius * 3.5)
                cracks.append(CrackLine(
                    start: p1,
                    end: p2,
                    width: arcWidth,
                    controlOffset: CGPoint(
                        x: controlX - chordMidX + CGFloat.random(in: -0.003...0.003),
                        y: controlY - chordMidY + CGFloat.random(in: -0.003...0.003)
                    ),
                    distFromCenter: radius
                ))
            }
        }

        // Micro-fractures near impact center
        let numMicro = Int.random(in: 15...25)
        for _ in 0..<numMicro {
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist = CGFloat.random(in: 0.01...0.12)
            let microStart = CGPoint(
                x: center.x + cos(angle) * dist,
                y: center.y + sin(angle) * dist
            )
            let microAngle = angle + CGFloat.random(in: -1.0...1.0)
            let microLen = CGFloat.random(in: 0.01...0.04)
            let microEnd = CGPoint(
                x: microStart.x + cos(microAngle) * microLen,
                y: microStart.y + sin(microAngle) * microLen
            )
            cracks.append(CrackLine(
                start: microStart,
                end: microEnd,
                width: CGFloat.random(in: 0.3...0.8),
                controlOffset: .zero,
                distFromCenter: dist
            ))
        }
    }

    private func generateShards(size: CGSize) {
        shards.removeAll()
        let center = impactPoint
        let numShards = Int.random(in: 10...16)
        for i in 0..<numShards {
            let baseAngle = (CGFloat(i) / CGFloat(numShards)) * .pi * 2.0
            let dist = CGFloat.random(in: 0.05...0.22)

            let shardCenter = CGPoint(
                x: center.x + cos(baseAngle) * dist,
                y: center.y + sin(baseAngle) * dist
            )
            // Size varies: smaller near impact, larger further out
            let sizeMultiplier = 0.6 + dist * 2.0
            let vertCount = Int.random(in: 4...6)
            var pts: [CGPoint] = []
            for v in 0..<vertCount {
                let a = (CGFloat(v) / CGFloat(vertCount)) * .pi * 2.0
                let r = CGFloat.random(in: 0.012...0.045) * sizeMultiplier
                pts.append(CGPoint(
                    x: shardCenter.x + cos(a) * r,
                    y: shardCenter.y + sin(a) * r
                ))
            }

            let awayAngle = atan2(shardCenter.y - center.y, shardCenter.x - center.x)
            shards.append(GlassShard(
                points: pts,
                angle: 0,
                angularVel: CGFloat.random(in: -5...5),
                vx: cos(awayAngle) * CGFloat.random(in: 30...100),
                vy: sin(awayAngle) * CGFloat.random(in: -50...50),
                y: 0,
                x: 0,
                delay: CGFloat(i) * 0.04,
                fallen: false
            ))
        }
    }

    private func generateDebris() {
        debrisParticles.removeAll()
        let center = impactPoint
        for _ in 0..<35 {
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let speed = CGFloat.random(in: 0.2...0.8)
            debrisParticles.append(DebrisParticle(
                x: center.x + CGFloat.random(in: -0.02...0.02),
                y: center.y + CGFloat.random(in: -0.02...0.02),
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                life: 1.0,
                size: CGFloat.random(in: 1.5...4),
                rotation: CGFloat.random(in: 0...(.pi * 2)),
                rotationSpeed: CGFloat.random(in: -12...12)
            ))
        }
    }

    private func updateDebris(dt: CGFloat) {
        var w = 0
        for i in debrisParticles.indices {
            var p = debrisParticles[i]
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.vy += 0.5 * dt // gravity
            p.life -= dt * 2.5
            p.rotation += p.rotationSpeed * dt
            if p.life > 0 {
                debrisParticles[w] = p
                w += 1
            }
        }
        debrisParticles.removeSubrange(w...)
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

                // Apply screen shake
                if rain.screenShakeIntensity > 0.01 {
                    context.translateBy(x: rain.screenShakeX, y: rain.screenShakeY)
                }

                drawRainDrops(in: &context, size: size)
                drawSubmarine(in: &context, size: size)
                drawWater(in: &context, size: size)
                drawTorpedo(in: &context, size: size)
                drawRipples(in: &context, size: size)
                drawSplashes(in: &context)
                drawCracks(in: &context, size: size)
                drawShards(in: &context, size: size)
                drawDrainParticles(in: &context)
                drawDebris(in: &context, size: size)
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

        let hullW: CGFloat = 120 * scale
        let hullH: CGFloat = 35 * scale

        // Shadow underneath submarine
        var shadowPath = Path()
        shadowPath.addEllipse(in: CGRect(x: cx - hullW / 2 + 3, y: cy + 3, width: hullW, height: hullH * 0.4))
        var shadowCtx = context
        shadowCtx.opacity = 0.12
        shadowCtx.addFilter(.blur(radius: 5))
        shadowCtx.fill(shadowPath, with: .color(Color(red: 0, green: 0, blue: 0.08)))

        // Hull with vertical gradient (3D cylindrical look)
        var hullPath = Path()
        hullPath.addEllipse(in: CGRect(x: cx - hullW / 2, y: cy - hullH / 2, width: hullW, height: hullH))

        let hullGradient = Gradient(stops: [
            .init(color: Color(red: 0.28, green: 0.35, blue: 0.46), location: 0.0),
            .init(color: Color(red: 0.20, green: 0.26, blue: 0.36), location: 0.3),
            .init(color: Color(red: 0.14, green: 0.18, blue: 0.28), location: 0.6),
            .init(color: Color(red: 0.08, green: 0.10, blue: 0.18), location: 1.0),
        ])

        var hullCtx = context
        hullCtx.opacity = 0.7
        hullCtx.fill(hullPath, with: .linearGradient(
            hullGradient,
            startPoint: CGPoint(x: cx, y: cy - hullH / 2),
            endPoint: CGPoint(x: cx, y: cy + hullH / 2)
        ))

        // Specular highlight on upper hull
        var highlightPath = Path()
        highlightPath.addEllipse(in: CGRect(
            x: cx - hullW * 0.35,
            y: cy - hullH / 2 + hullH * 0.12,
            width: hullW * 0.7,
            height: hullH * 0.2
        ))
        var hlCtx = context
        hlCtx.opacity = 0.15
        hlCtx.fill(highlightPath, with: .color(Color(red: 0.6, green: 0.75, blue: 0.9)))

        // Hull outline
        var outlineCtx = context
        outlineCtx.opacity = 0.35
        outlineCtx.stroke(hullPath, with: .color(Color(red: 0.35, green: 0.45, blue: 0.6)), style: StrokeStyle(lineWidth: 1.2))

        // Panel seam lines
        for offset in [-0.2, 0.0, 0.25] as [CGFloat] {
            var seamPath = Path()
            let seamX = cx + hullW * offset
            seamPath.move(to: CGPoint(x: seamX, y: cy - hullH * 0.35))
            seamPath.addLine(to: CGPoint(x: seamX, y: cy + hullH * 0.35))
            var seamCtx = context
            seamCtx.opacity = 0.12
            seamCtx.stroke(seamPath, with: .color(Color(red: 0.2, green: 0.3, blue: 0.4)), style: StrokeStyle(lineWidth: 0.6))
        }

        // Portholes
        for px in [-0.15, 0.05, 0.20] as [CGFloat] {
            let portX = cx + hullW * px
            let portR: CGFloat = 3.5 * scale
            var portPath = Path()
            portPath.addEllipse(in: CGRect(x: portX - portR, y: cy - portR, width: portR * 2, height: portR * 2))
            var pCtx = context
            pCtx.opacity = 0.3
            pCtx.fill(portPath, with: .color(Color(red: 0.3, green: 0.5, blue: 0.65)))
            pCtx.opacity = 0.4
            pCtx.stroke(portPath, with: .color(Color(red: 0.4, green: 0.55, blue: 0.7)), style: StrokeStyle(lineWidth: 1.0))
            // Porthole glint
            var glintPath = Path()
            let glintR: CGFloat = 1.5 * scale
            glintPath.addEllipse(in: CGRect(x: portX - portR * 0.3 - glintR / 2, y: cy - portR * 0.3 - glintR / 2, width: glintR, height: glintR))
            pCtx.opacity = 0.2
            pCtx.fill(glintPath, with: .color(.white))
        }

        // Conning tower with gradient
        let towerW: CGFloat = 25 * scale
        let towerH: CGFloat = 18 * scale
        let towerRect = CGRect(x: cx - towerW / 2 + 5, y: cy - hullH / 2 - towerH + 4, width: towerW, height: towerH)
        var towerPath = Path()
        towerPath.addRoundedRect(in: towerRect, cornerSize: CGSize(width: 4, height: 4))

        let towerGradient = Gradient(stops: [
            .init(color: Color(red: 0.24, green: 0.30, blue: 0.40), location: 0.0),
            .init(color: Color(red: 0.14, green: 0.18, blue: 0.27), location: 1.0),
        ])
        var towerCtx = context
        towerCtx.opacity = 0.65
        towerCtx.fill(towerPath, with: .linearGradient(
            towerGradient,
            startPoint: CGPoint(x: towerRect.minX, y: towerRect.minY),
            endPoint: CGPoint(x: towerRect.maxX, y: towerRect.maxY)
        ))
        towerCtx.opacity = 0.3
        towerCtx.stroke(towerPath, with: .color(Color(red: 0.35, green: 0.45, blue: 0.6)), style: StrokeStyle(lineWidth: 1.0))

        // Periscope (rounded rect instead of bare lines)
        let periBottom = cy - hullH / 2 - towerH + 4
        let periTop = periBottom - 10
        var periscopePath = Path()
        periscopePath.addRoundedRect(
            in: CGRect(x: cx + 7, y: periTop, width: 2.5, height: periBottom - periTop),
            cornerSize: CGSize(width: 1, height: 1)
        )
        periscopePath.addRoundedRect(
            in: CGRect(x: cx + 7, y: periTop - 1, width: 8, height: 3),
            cornerSize: CGSize(width: 1, height: 1)
        )
        var periCtx = context
        periCtx.opacity = 0.45
        periCtx.fill(periscopePath, with: .color(Color(red: 0.2, green: 0.25, blue: 0.35)))
        periCtx.stroke(periscopePath, with: .color(Color(red: 0.3, green: 0.4, blue: 0.5)), style: StrokeStyle(lineWidth: 0.8))

        // Propeller hub
        let propX = cx - hullW / 2 - 5
        var hubPath = Path()
        let hubR: CGFloat = 3.5 * scale
        hubPath.addEllipse(in: CGRect(x: propX - hubR, y: cy - hubR, width: hubR * 2, height: hubR * 2))
        var hubCtx = context
        hubCtx.opacity = 0.35
        hubCtx.fill(hubPath, with: .color(Color(red: 0.3, green: 0.35, blue: 0.45)))
        hubCtx.stroke(hubPath, with: .color(Color(red: 0.4, green: 0.5, blue: 0.6)), style: StrokeStyle(lineWidth: 0.8))

        // Propeller blades (elongated ellipses)
        for angle in [CGFloat.pi / 4, -.pi / 4, .pi * 3 / 4, -.pi * 3 / 4] {
            let rotAngle = angle + rain.elapsedTime * 8
            let bladeLen: CGFloat = 12 * scale
            let bladeW: CGFloat = 3.5 * scale
            let bladeCX = propX + cos(rotAngle) * bladeLen * 0.5
            let bladeCY = cy + sin(rotAngle) * bladeLen * 0.5

            var bladePath = Path()
            bladePath.addEllipse(in: CGRect(
                x: bladeCX - bladeW / 2,
                y: bladeCY - bladeLen / 2,
                width: bladeW,
                height: bladeLen
            ))

            var bladeCtx = context
            bladeCtx.translateBy(x: bladeCX, y: bladeCY)
            bladeCtx.rotate(by: .radians(rotAngle))
            bladeCtx.translateBy(x: -bladeCX, y: -bladeCY)
            bladeCtx.opacity = 0.25
            bladeCtx.fill(bladePath, with: .color(Color(red: 0.4, green: 0.5, blue: 0.6)))
        }

        // Bubbles trailing behind sub
        for i in 0..<8 {
            let bubbleX = cx - hullW / 2 - CGFloat(i) * 14 - CGFloat.random(in: 0...10)
            let bubbleY = cy + CGFloat.random(in: -12...12) - CGFloat(i) * 2
            let bubbleR = CGFloat.random(in: 2...6)
            var bCtx = context
            bCtx.opacity = 0.15 - Double(i) * 0.015
            bCtx.fill(
                Path(ellipseIn: CGRect(x: bubbleX - bubbleR, y: bubbleY - bubbleR, width: bubbleR * 2, height: bubbleR * 2)),
                with: .color(Color(red: 0.5, green: 0.7, blue: 0.85, opacity: 0.3))
            )
            bCtx.stroke(
                Path(ellipseIn: CGRect(x: bubbleX - bubbleR, y: bubbleY - bubbleR, width: bubbleR * 2, height: bubbleR * 2)),
                with: .color(Color(red: 0.5, green: 0.7, blue: 0.85)),
                style: StrokeStyle(lineWidth: 0.6)
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

        // Torpedo gradient (metallic look)
        let torpGradient = Gradient(stops: [
            .init(color: Color(red: 0.38, green: 0.42, blue: 0.48), location: 0.0),
            .init(color: Color(red: 0.25, green: 0.30, blue: 0.35), location: 0.4),
            .init(color: Color(red: 0.18, green: 0.22, blue: 0.28), location: 1.0),
        ])

        var ctx = context
        ctx.opacity = min(Double(s), 1.0)
        ctx.fill(path, with: .linearGradient(
            torpGradient,
            startPoint: CGPoint(x: cx, y: cy - bodyH / 2),
            endPoint: CGPoint(x: cx, y: cy + bodyH / 2)
        ))
        ctx.stroke(path, with: .color(Color(red: 0.4, green: 0.45, blue: 0.5)), style: StrokeStyle(lineWidth: max(1, s)))

        // Specular highlight on torpedo
        var torpHlPath = Path()
        torpHlPath.addRoundedRect(
            in: CGRect(x: cx - bodyW * 0.35, y: cy - bodyH / 2 + bodyH * 0.1, width: bodyW * 0.7, height: bodyH * 0.2),
            cornerSize: CGSize(width: bodyH * 0.1, height: bodyH * 0.1)
        )
        var hlCtx = context
        hlCtx.opacity = min(Double(s), 1.0) * 0.2
        hlCtx.fill(torpHlPath, with: .color(Color(red: 0.7, green: 0.8, blue: 0.9)))

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

        let progress = rain.crackProgress

        for crack in rain.cracks {
            // Animate crack extension from start toward end
            let drawEnd: CGPoint
            if progress < 1.0 {
                drawEnd = CGPoint(
                    x: crack.start.x + (crack.end.x - crack.start.x) * progress,
                    y: crack.start.y + (crack.end.y - crack.start.y) * progress
                )
            } else {
                drawEnd = crack.end
            }

            let sx = crack.start.x * size.width
            let sy = crack.start.y * size.height
            let ex = drawEnd.x * size.width
            let ey = drawEnd.y * size.height

            // Bezier control point
            let midX = (sx + ex) / 2 + crack.controlOffset.x * size.width
            let midY = (sy + ey) / 2 + crack.controlOffset.y * size.height
            let ctrl = CGPoint(x: midX, y: midY)

            // Layer 1: Dark shadow (depth illusion)
            var shadowPath = Path()
            shadowPath.move(to: CGPoint(x: sx + 1.5, y: sy + 1.5))
            shadowPath.addQuadCurve(
                to: CGPoint(x: ex + 1.5, y: ey + 1.5),
                control: CGPoint(x: ctrl.x + 1.5, y: ctrl.y + 1.5)
            )
            var shadowCtx = context
            shadowCtx.opacity = 0.35
            shadowCtx.stroke(shadowPath,
                with: .color(Color(red: 0, green: 0, blue: 0.05)),
                style: StrokeStyle(lineWidth: crack.width * 2.5, lineCap: .round))

            // Layer 2: Main dark crack
            var mainPath = Path()
            mainPath.move(to: CGPoint(x: sx, y: sy))
            mainPath.addQuadCurve(to: CGPoint(x: ex, y: ey), control: ctrl)
            var mainCtx = context
            mainCtx.opacity = 0.8
            mainCtx.stroke(mainPath,
                with: .color(Color(red: 0.08, green: 0.08, blue: 0.12)),
                style: StrokeStyle(lineWidth: crack.width * 1.2, lineCap: .round))

            // Layer 3: Edge highlight (light catching crack edge)
            var hlPath = Path()
            hlPath.move(to: CGPoint(x: sx - 0.7, y: sy - 0.7))
            hlPath.addQuadCurve(
                to: CGPoint(x: ex - 0.7, y: ey - 0.7),
                control: CGPoint(x: ctrl.x - 0.7, y: ctrl.y - 0.7)
            )
            var hlCtx = context
            hlCtx.opacity = 0.35
            hlCtx.stroke(hlPath,
                with: .color(.white),
                style: StrokeStyle(lineWidth: max(0.5, crack.width * 0.3), lineCap: .round))

            // Layer 4: Inner specular (only on wider cracks)
            if crack.width > 1.2 {
                var specPath = Path()
                specPath.move(to: CGPoint(x: sx, y: sy))
                specPath.addQuadCurve(to: CGPoint(x: ex, y: ey), control: ctrl)
                var specCtx = context
                specCtx.opacity = 0.5
                specCtx.stroke(specPath,
                    with: .color(Color(red: 0.9, green: 0.95, blue: 1.0)),
                    style: StrokeStyle(lineWidth: 0.4, lineCap: .round))
            }
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

            // Inner dark edge for depth
            ctx.opacity = 0.2
            ctx.stroke(path, with: .color(Color(red: 0, green: 0, blue: 0.1)), style: StrokeStyle(lineWidth: 2.5))

            // Glass-like gradient fill
            let gradientStart = CGPoint(x: screenCenter.x - 10, y: screenCenter.y - 10)
            let gradientEnd = CGPoint(x: screenCenter.x + 10, y: screenCenter.y + 10)
            let shardGradient = Gradient(stops: [
                .init(color: Color(red: 0.8, green: 0.9, blue: 1.0, opacity: 0.25), location: 0.0),
                .init(color: Color(red: 0.6, green: 0.75, blue: 0.95, opacity: 0.15), location: 0.5),
                .init(color: Color(red: 0.7, green: 0.85, blue: 1.0, opacity: 0.3), location: 1.0),
            ])
            ctx.fill(path, with: .linearGradient(shardGradient, startPoint: gradientStart, endPoint: gradientEnd))

            // Bright edge glint
            ctx.opacity = 0.6
            ctx.stroke(path, with: .color(Color(red: 0.9, green: 0.95, blue: 1.0)), style: StrokeStyle(lineWidth: 0.8))
        }
    }

    private func drawDrainParticles(in context: inout GraphicsContext) {
        guard rain.drainPhase == .draining || rain.drainPhase == .impact else { return }

        for p in rain.drainParticles {
            let alpha = Double(p.life) * 0.5
            var ctx = context
            ctx.opacity = alpha

            // Elongated streak in direction of velocity
            let speed = sqrt(p.vx * p.vx + p.vy * p.vy)
            let streakLen = min(speed * 0.03, 8.0)
            let dirX = speed > 0.1 ? p.vx / speed : 0
            let dirY = speed > 0.1 ? p.vy / speed : 0

            var streakPath = Path()
            streakPath.move(to: CGPoint(x: p.x - dirX * streakLen, y: p.y - dirY * streakLen))
            streakPath.addLine(to: CGPoint(x: p.x + dirX * streakLen, y: p.y + dirY * streakLen))

            ctx.stroke(streakPath,
                with: .color(Color(red: 0.4, green: 0.6, blue: 0.85)),
                style: StrokeStyle(lineWidth: p.size, lineCap: .round))

            // Bright dot at head
            ctx.opacity = alpha * 0.5
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - p.size * 0.5, y: p.y - p.size * 0.5, width: p.size, height: p.size)),
                with: .color(Color(red: 0.6, green: 0.8, blue: 1.0))
            )
        }
    }

    private func drawDebris(in context: inout GraphicsContext, size: CGSize) {
        guard !rain.debrisParticles.isEmpty else { return }

        for p in rain.debrisParticles {
            let alpha = Double(p.life) * 0.6
            let screenX = p.x * size.width
            let screenY = p.y * size.height

            var ctx = context
            ctx.opacity = alpha
            ctx.translateBy(x: screenX, y: screenY)
            ctx.rotate(by: .radians(p.rotation))
            ctx.translateBy(x: -screenX, y: -screenY)

            // Small glass fragment (triangle)
            let s = p.size
            var fragPath = Path()
            fragPath.move(to: CGPoint(x: screenX - s, y: screenY))
            fragPath.addLine(to: CGPoint(x: screenX, y: screenY - s * 1.2))
            fragPath.addLine(to: CGPoint(x: screenX + s * 0.8, y: screenY + s * 0.3))
            fragPath.closeSubpath()

            ctx.fill(fragPath, with: .color(Color(red: 0.8, green: 0.9, blue: 1.0)))
            ctx.opacity = alpha * 0.8
            ctx.stroke(fragPath, with: .color(.white), style: StrokeStyle(lineWidth: 0.5))
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
