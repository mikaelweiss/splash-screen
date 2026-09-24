import SwiftUI

// MARK: - Species

enum FishSpecies: CaseIterable {
    case goldfish, clownfish, blueTang, neonTetra, butterflyfish, mackerel
}

struct FishPalette {
    var back: SIMD3<Double>
    var belly: SIMD3<Double>
    var fin: SIMD3<Double>
    var finEdge: SIMD3<Double>
    var tail: SIMD3<Double>
    var accent: SIMD3<Double>
    var accent2: SIMD3<Double>
    var iris: SIMD3<Double>
}

struct FishLook {
    var species: FishSpecies
    var palette: FishPalette

    static func random() -> FishLook {
        let species = FishSpecies.allCases.randomElement()!
        var palette = species.palettes.randomElement()!
        let shade = Double.random(in: 0.9...1.06)
        palette.back = pointwiseMin(palette.back * shade, SIMD3(repeating: 1))
        palette.belly = pointwiseMin(palette.belly * (0.5 + shade * 0.5), SIMD3(repeating: 1))
        palette.fin = pointwiseMin(palette.fin * shade, SIMD3(repeating: 1))
        return FishLook(species: species, palette: palette)
    }
}

extension FishSpecies {
    var palettes: [FishPalette] {
        switch self {
        case .goldfish:
            return [
                FishPalette(back: [0.95, 0.40, 0.06], belly: [1.0, 0.80, 0.45], fin: [1.0, 0.55, 0.18], finEdge: [1.0, 0.86, 0.62],
                            tail: [1.0, 0.52, 0.16], accent: [1, 1, 1], accent2: [1, 1, 1], iris: [0.95, 0.72, 0.30]),
                FishPalette(back: [0.88, 0.20, 0.08], belly: [1.0, 0.90, 0.82], fin: [0.98, 0.42, 0.26], finEdge: [1.0, 0.93, 0.88],
                            tail: [0.97, 0.38, 0.22], accent: [1, 1, 1], accent2: [1, 1, 1], iris: [0.90, 0.60, 0.30]),
                FishPalette(back: [0.98, 0.64, 0.16], belly: [1.0, 0.93, 0.68], fin: [1.0, 0.76, 0.36], finEdge: [1.0, 0.96, 0.82],
                            tail: [1.0, 0.72, 0.30], accent: [1, 1, 1], accent2: [1, 1, 1], iris: [0.85, 0.55, 0.20]),
            ]
        case .clownfish:
            return [
                FishPalette(back: [0.98, 0.40, 0.04], belly: [1.0, 0.62, 0.24], fin: [0.98, 0.48, 0.10], finEdge: [0.08, 0.05, 0.04],
                            tail: [0.98, 0.46, 0.08], accent: [0.99, 0.98, 0.96], accent2: [0.07, 0.05, 0.05], iris: [0.92, 0.45, 0.10]),
            ]
        case .blueTang:
            return [
                FishPalette(back: [0.07, 0.26, 0.78], belly: [0.32, 0.60, 0.98], fin: [0.10, 0.30, 0.82], finEdge: [0.03, 0.05, 0.18],
                            tail: [1.0, 0.82, 0.10], accent: [0.03, 0.05, 0.16], accent2: [0.22, 0.48, 0.95], iris: [0.10, 0.10, 0.15]),
            ]
        case .neonTetra:
            return [
                FishPalette(back: [0.40, 0.44, 0.40], belly: [0.90, 0.92, 0.94], fin: [0.86, 0.90, 0.95], finEdge: [0.96, 0.98, 1.0],
                            tail: [0.82, 0.86, 0.92], accent: [0.15, 0.85, 1.0], accent2: [0.95, 0.12, 0.20], iris: [0.20, 0.55, 0.85]),
            ]
        case .butterflyfish:
            return [
                FishPalette(back: [1.0, 0.76, 0.05], belly: [1.0, 0.95, 0.60], fin: [1.0, 0.82, 0.12], finEdge: [1.0, 0.97, 0.80],
                            tail: [1.0, 0.86, 0.22], accent: [0.12, 0.09, 0.08], accent2: [1.0, 1.0, 1.0], iris: [0.12, 0.10, 0.10]),
            ]
        case .mackerel:
            return [
                FishPalette(back: [0.10, 0.38, 0.46], belly: [0.86, 0.91, 0.93], fin: [0.55, 0.66, 0.72], finEdge: [0.80, 0.88, 0.92],
                            tail: [0.32, 0.48, 0.56], accent: [0.04, 0.14, 0.20], accent2: [0.86, 0.91, 0.93], iris: [0.86, 0.80, 0.55]),
                FishPalette(back: [0.22, 0.30, 0.52], belly: [0.88, 0.90, 0.95], fin: [0.60, 0.64, 0.76], finEdge: [0.84, 0.86, 0.94],
                            tail: [0.38, 0.44, 0.62], accent: [0.08, 0.10, 0.24], accent2: [0.88, 0.90, 0.95], iris: [0.86, 0.80, 0.55]),
            ]
        }
    }

    var shape: FishShape {
        switch self {
        case .goldfish: return .goldfish
        case .clownfish: return .clownfish
        case .blueTang: return .blueTang
        case .neonTetra: return .neonTetra
        case .butterflyfish: return .butterflyfish
        case .mackerel: return .mackerel
        }
    }
}

// MARK: - Shape

struct FinSpec {
    var start: CGFloat
    var end: CGFloat
    var height: CGFloat
    var sweep: CGFloat
}

struct FishShape {
    enum Tail { case veil, fan, lunate, forked }
    enum Pattern { case none, bands, swoosh, neonStripe, eyeBand, bars }

    var scale: CGFloat
    var noseX: CGFloat
    var length: CGFloat
    var top: CGFloat
    var bottom: CGFloat
    var peak: CGFloat
    var peduncle: CGFloat
    var dorsal: FinSpec
    var anal: FinSpec
    var pelvic: FinSpec
    var pectoral: CGFloat
    var tail: Tail
    var tailLength: CGFloat
    var tailSpread: CGFloat
    var eyeT: CGFloat
    var eyeSize: CGFloat
    var wave: CGFloat
    var pattern: Pattern

    static let goldfish = FishShape(
        scale: 1.0, noseX: 0.46, length: 0.78, top: 0.25, bottom: 0.24, peak: 0.75, peduncle: 0.06,
        dorsal: FinSpec(start: 0.28, end: 0.72, height: 0.2, sweep: 0.6),
        anal: FinSpec(start: 0.70, end: 0.92, height: 0.12, sweep: 0.8),
        pelvic: FinSpec(start: 0.36, end: 0.50, height: 0.10, sweep: 1.0),
        pectoral: 0.17, tail: .veil, tailLength: 0.55, tailSpread: 0.30,
        eyeT: 0.13, eyeSize: 0.052, wave: 0.045, pattern: .none
    )

    static let clownfish = FishShape(
        scale: 0.95, noseX: 0.46, length: 0.80, top: 0.21, bottom: 0.20, peak: 0.85, peduncle: 0.07,
        dorsal: FinSpec(start: 0.26, end: 0.86, height: 0.11, sweep: 0.2),
        anal: FinSpec(start: 0.66, end: 0.90, height: 0.11, sweep: 0.3),
        pelvic: FinSpec(start: 0.32, end: 0.44, height: 0.08, sweep: 0.8),
        pectoral: 0.15, tail: .fan, tailLength: 0.27, tailSpread: 0.18,
        eyeT: 0.13, eyeSize: 0.058, wave: 0.035, pattern: .bands
    )

    static let blueTang = FishShape(
        scale: 1.05, noseX: 0.48, length: 0.80, top: 0.28, bottom: 0.27, peak: 0.6, peduncle: 0.05,
        dorsal: FinSpec(start: 0.20, end: 0.92, height: 0.08, sweep: 0.15),
        anal: FinSpec(start: 0.50, end: 0.92, height: 0.08, sweep: 0.15),
        pelvic: FinSpec(start: 0.30, end: 0.40, height: 0.07, sweep: 0.6),
        pectoral: 0.16, tail: .lunate, tailLength: 0.28, tailSpread: 0.25,
        eyeT: 0.14, eyeSize: 0.05, wave: 0.03, pattern: .swoosh
    )

    static let neonTetra = FishShape(
        scale: 0.9, noseX: 0.48, length: 0.82, top: 0.15, bottom: 0.15, peak: 1.0, peduncle: 0.05,
        dorsal: FinSpec(start: 0.42, end: 0.56, height: 0.12, sweep: 0.5),
        anal: FinSpec(start: 0.64, end: 0.88, height: 0.08, sweep: 0.5),
        pelvic: FinSpec(start: 0.40, end: 0.48, height: 0.06, sweep: 0.7),
        pectoral: 0.12, tail: .forked, tailLength: 0.30, tailSpread: 0.20,
        eyeT: 0.12, eyeSize: 0.065, wave: 0.04, pattern: .neonStripe
    )

    static let butterflyfish = FishShape(
        scale: 1.0, noseX: 0.46, length: 0.74, top: 0.31, bottom: 0.29, peak: 0.55, peduncle: 0.07,
        dorsal: FinSpec(start: 0.24, end: 0.93, height: 0.10, sweep: 0.3),
        anal: FinSpec(start: 0.52, end: 0.93, height: 0.10, sweep: 0.3),
        pelvic: FinSpec(start: 0.30, end: 0.40, height: 0.08, sweep: 0.7),
        pectoral: 0.14, tail: .fan, tailLength: 0.21, tailSpread: 0.19,
        eyeT: 0.16, eyeSize: 0.046, wave: 0.03, pattern: .eyeBand
    )

    static let mackerel = FishShape(
        scale: 1.1, noseX: 0.50, length: 0.84, top: 0.14, bottom: 0.13, peak: 1.1, peduncle: 0.03,
        dorsal: FinSpec(start: 0.30, end: 0.46, height: 0.11, sweep: 0.7),
        anal: FinSpec(start: 0.68, end: 0.80, height: 0.06, sweep: 0.6),
        pelvic: FinSpec(start: 0.32, end: 0.40, height: 0.05, sweep: 0.6),
        pectoral: 0.12, tail: .forked, tailLength: 0.34, tailSpread: 0.26,
        eyeT: 0.10, eyeSize: 0.046, wave: 0.04, pattern: .bars
    )
}

// MARK: - Body geometry

/// Nose points toward +x. Outlines, fins, and markings follow the bent spine so they flex together.
private struct FishBody {
    let shape: FishShape
    let s: CGFloat
    let phase: CGFloat
    private let norm: CGFloat
    private let amp: CGFloat
    private let waveNumber: CGFloat = 2.8

    init(shape: FishShape, size: CGFloat, phase: CGFloat) {
        self.shape = shape
        self.s = size
        self.phase = phase
        let tPeak = 0.5 / (0.5 + shape.peak)
        norm = 1 / (sqrt(tPeak) * pow(1 - tPeak, shape.peak))
        amp = shape.wave * size
    }

    private func profile(_ t: CGFloat) -> CGFloat {
        norm * sqrt(t) * pow(1 - t, shape.peak)
    }

    func top(_ t: CGFloat) -> CGFloat {
        let c = min(max(t, 0), 1)
        return s * (shape.top * profile(c) + shape.peduncle * c * c)
    }

    func bottom(_ t: CGFloat) -> CGFloat {
        let c = min(max(t, 0), 1)
        return s * (shape.bottom * profile(c) + shape.peduncle * c * c)
    }

    /// Spine point at `t` (0 nose, 1 tail base) and the unit normal pointing toward the back.
    func spine(_ t: CGFloat) -> (point: CGPoint, up: CGVector) {
        let envelope = 0.08 + t * t
        let arg = phase - t * waveNumber
        let y = amp * envelope * sin(arg)
        let dy = amp * (2 * t * sin(arg) - envelope * waveNumber * cos(arg))
        let dx = s * shape.length
        let len = sqrt(dx * dx + dy * dy)
        return (CGPoint(x: s * (shape.noseX - t * shape.length), y: y), CGVector(dx: -dy / len, dy: -dx / len))
    }

    /// Point at `t`, offset from the spine by `offset` toward the back (negative toward the belly).
    func at(_ t: CGFloat, _ offset: CGFloat) -> CGPoint {
        let (p, up) = spine(t)
        return CGPoint(x: p.x + up.dx * offset, y: p.y + up.dy * offset)
    }

    func outline() -> Path {
        let n = 12
        var pts: [CGPoint] = []
        pts.reserveCapacity(n * 2)
        for i in 0..<n {
            let t = pow(CGFloat(i) / CGFloat(n - 1), 1.2)
            pts.append(at(t, top(t)))
        }
        for i in stride(from: n - 1, through: 1, by: -1) {
            let t = pow(CGFloat(i) / CGFloat(n - 1), 1.2)
            pts.append(at(t, -bottom(t)))
        }
        return smoothClosed(pts)
    }

    func band(from t0: CGFloat, to t1: CGFloat, steps: Int = 7, upper: (CGFloat) -> CGFloat, lower: (CGFloat) -> CGFloat) -> Path {
        var pts: [CGPoint] = []
        pts.reserveCapacity(steps * 2)
        for j in 0..<steps {
            let t = t0 + (t1 - t0) * CGFloat(j) / CGFloat(steps - 1)
            pts.append(at(t, upper(t)))
        }
        for j in stride(from: steps - 1, through: 0, by: -1) {
            let t = t0 + (t1 - t0) * CGFloat(j) / CGFloat(steps - 1)
            pts.append(at(t, lower(t)))
        }
        return smoothClosed(pts)
    }

    func fin(_ fin: FinSpec, onBack: Bool, flutter: CGFloat) -> Path {
        let m = 7
        var base: [CGPoint] = []
        var edge: [CGPoint] = []
        base.reserveCapacity(m)
        edge.reserveCapacity(m)
        let side: CGFloat = onBack ? 1 : -1
        for j in 0..<m {
            let u = CGFloat(j) / CGFloat(m - 1)
            let t = fin.start + (fin.end - fin.start) * u
            let (p, up) = spine(t)
            let root = (onBack ? top(t) : bottom(t)) * 0.8
            let h = fin.height * s * sin(.pi * pow(u, 0.75)) * (1 + 0.12 * sin(phase * 0.8 - u * 4 + flutter))
            let nx = up.dx * side, ny = up.dy * side
            base.append(CGPoint(x: p.x + nx * root, y: p.y + ny * root))
            let reach = root + h
            let sweep = fin.sweep * h
            edge.append(CGPoint(x: p.x + nx * reach + up.dy * sweep, y: p.y + ny * reach - up.dx * sweep))
        }
        return smoothClosed(base + edge.reversed())
    }
}

private func smoothClosed(_ pts: [CGPoint]) -> Path {
    var path = Path()
    let n = pts.count
    guard n > 2 else { return path }
    func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
    path.move(to: mid(pts[n - 1], pts[0]))
    for i in 0..<n {
        path.addQuadCurve(to: mid(pts[i], pts[(i + 1) % n]), control: pts[i])
    }
    path.closeSubpath()
    return path
}

// MARK: - Rendering

enum FishRenderer {
    static let visualScale: CGFloat = 1.25
    private static let deepWater = SIMD3<Double>(0.05, 0.13, 0.24)

    /// Draws one fish into a context already translated and rotated to the fish's position and heading.
    /// `depth` (0 surface, 1 floor) tints the fish toward the water color.
    static func draw(_ fish: Fish, in ctx: GraphicsContext, depth: CGFloat) {
        let look = fish.look
        let shape = look.species.shape
        let pal = look.palette
        let body = FishBody(shape: shape, size: fish.size * visualScale * shape.scale, phase: fish.swimPhase)
        let s = body.s
        let phase = fish.swimPhase
        let tint = Double(min(max(depth, 0), 1)) * 0.3

        func color(_ c: SIMD3<Double>, _ opacity: Double = 1) -> Color {
            let m = c + (deepWater - c) * tint
            return Color(red: m.x, green: m.y, blue: m.z, opacity: opacity)
        }
        let outlineColor = color(pal.back * 0.35, 0.55)
        let hairline = max(0.5, s * 0.018)

        drawTail(body: body, shape: shape, phase: phase, ctx: ctx,
                 base: color(pal.tail, 0.95), tip: color(pal.finEdge, 0.7), edge: color(pal.finEdge, 0.5), hairline: hairline)

        var fins = body.fin(shape.dorsal, onBack: true, flutter: 0)
        fins.addPath(body.fin(shape.anal, onBack: false, flutter: 1.3))
        fins.addPath(body.fin(shape.pelvic, onBack: false, flutter: 2.4))
        ctx.fill(fins, with: .color(color(pal.fin, 0.85)))
        ctx.stroke(fins, with: .color(color(pal.finEdge, 0.6)), lineWidth: hairline)

        let outline = body.outline()
        let backY = -body.top(0.4)
        let bellyY = body.bottom(0.4)
        ctx.fill(outline, with: .linearGradient(
            Gradient(stops: [
                .init(color: color(pal.back), location: 0),
                .init(color: color((pal.back + pal.belly) * 0.5), location: 0.5),
                .init(color: color(pal.belly), location: 0.85),
            ]),
            startPoint: CGPoint(x: 0, y: backY),
            endPoint: CGPoint(x: 0, y: bellyY)
        ))

        if shape.pattern != .none {
            var patternCtx = ctx
            patternCtx.clip(to: outline)
            drawPattern(shape.pattern, body: body, ctx: patternCtx, pal: pal, color: color)
        }

        let sheen = body.band(from: 0.06, to: 0.7,
                              upper: { body.top($0) * 0.82 },
                              lower: { body.top($0) * (0.6 - 0.35 * sin(.pi * $0)) })
        ctx.fill(sheen, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.3), .white.opacity(0)]),
            startPoint: CGPoint(x: 0, y: backY * 0.9),
            endPoint: CGPoint(x: 0, y: backY * 0.2)
        ))

        ctx.stroke(outline, with: .color(outlineColor), lineWidth: hairline)

        let gillT = shape.eyeT + 0.1
        var gill = Path()
        gill.move(to: body.at(gillT, body.top(gillT) * 0.7))
        gill.addQuadCurve(to: body.at(gillT, -body.bottom(gillT) * 0.7), control: body.at(gillT + 0.08, 0))
        ctx.stroke(gill, with: .color(color(pal.back * 0.4, 0.35)), lineWidth: hairline)

        drawPectoral(body: body, shape: shape, phase: phase, ctx: ctx,
                     fill: color(look.species == .blueTang ? pal.tail : pal.fin, 0.8))

        drawEye(body: body, shape: shape, ctx: ctx, iris: color(pal.iris), rim: color(pal.back * 0.3))

        var mouth = Path()
        mouth.move(to: body.at(0.015, -body.bottom(0.015) * 0.6))
        mouth.addQuadCurve(to: body.at(0.06, -body.bottom(0.06) * 0.25), control: body.at(0.045, -body.bottom(0.045) * 0.6))
        ctx.stroke(mouth, with: .color(color(pal.back * 0.3, 0.6)), style: StrokeStyle(lineWidth: hairline, lineCap: .round))
    }

    private static func drawTail(body: FishBody, shape: FishShape, phase: CGFloat, ctx: GraphicsContext,
                                 base: Color, tip: Color, edge: Color, hairline: CGFloat) {
        let s = body.s
        let (root, up) = body.spine(0.97)
        let angle = atan2(up.dx, -up.dy) + .pi + 0.14 * sin(phase - 3.4)
        let beat = sin(phase - 2.8)
        let foreshorten = 1 - 0.22 * beat * beat

        var tctx = ctx
        tctx.translateBy(x: root.x, y: root.y)
        tctx.rotate(by: .radians(Double(angle)))
        tctx.scaleBy(x: foreshorten, y: 1)

        let l = shape.tailLength * s
        let w = shape.tailSpread * s
        let a = max(body.top(1), body.bottom(1)) * 1.05
        let lag = w * 0.28 * sin(phase - 4.0)

        var path = Path()
        var rays = Path()
        path.move(to: CGPoint(x: 0, y: -a))
        switch shape.tail {
        case .veil:
            path.addQuadCurve(to: CGPoint(x: l, y: -w + lag), control: CGPoint(x: l * 0.35, y: -w * 0.95 + lag * 0.3))
            path.addQuadCurve(to: CGPoint(x: l * 0.72, y: lag * 0.7), control: CGPoint(x: l * 0.98, y: -w * 0.2 + lag))
            path.addQuadCurve(to: CGPoint(x: l * 1.05, y: w * 0.95 + lag), control: CGPoint(x: l * 0.9, y: w * 0.35 + lag))
            path.addQuadCurve(to: CGPoint(x: 0, y: a), control: CGPoint(x: l * 0.35, y: w * 0.85 + lag * 0.3))
        case .fan:
            path.addQuadCurve(to: CGPoint(x: l * 0.85, y: -w + lag), control: CGPoint(x: l * 0.3, y: -w * 0.9 + lag * 0.3))
            path.addQuadCurve(to: CGPoint(x: l * 0.85, y: w + lag), control: CGPoint(x: l * 1.3, y: lag))
            path.addQuadCurve(to: CGPoint(x: 0, y: a), control: CGPoint(x: l * 0.3, y: w * 0.9 + lag * 0.3))
        case .lunate:
            path.addQuadCurve(to: CGPoint(x: l, y: -w + lag), control: CGPoint(x: l * 0.45, y: -w * 0.55 + lag * 0.3))
            path.addQuadCurve(to: CGPoint(x: l, y: w + lag), control: CGPoint(x: l * 0.55, y: lag))
            path.addQuadCurve(to: CGPoint(x: 0, y: a), control: CGPoint(x: l * 0.45, y: w * 0.55 + lag * 0.3))
        case .forked:
            path.addQuadCurve(to: CGPoint(x: l, y: -w + lag), control: CGPoint(x: l * 0.5, y: -a - w * 0.3 + lag * 0.3))
            path.addQuadCurve(to: CGPoint(x: l * 0.5, y: lag * 0.5), control: CGPoint(x: l * 0.72, y: -w * 0.3 + lag))
            path.addQuadCurve(to: CGPoint(x: l, y: w + lag), control: CGPoint(x: l * 0.72, y: w * 0.3 + lag))
            path.addQuadCurve(to: CGPoint(x: 0, y: a), control: CGPoint(x: l * 0.5, y: a + w * 0.3 + lag * 0.3))
        }
        path.closeSubpath()

        if shape.tail == .veil || shape.tail == .fan {
            for k in -2...2 {
                let f = CGFloat(k) / 2
                rays.move(to: CGPoint(x: l * 0.05, y: a * f * 0.8))
                rays.addQuadCurve(to: CGPoint(x: l * 0.8, y: w * f * 0.8 + lag),
                                  control: CGPoint(x: l * 0.45, y: w * f * 0.45 + lag * 0.4))
            }
        }

        tctx.fill(path, with: .linearGradient(
            Gradient(colors: [base, tip]),
            startPoint: .zero,
            endPoint: CGPoint(x: l, y: 0)
        ))
        if !rays.isEmpty {
            tctx.stroke(rays, with: .color(edge.opacity(0.5)), lineWidth: hairline * 0.8)
        }
        tctx.stroke(path, with: .color(edge), lineWidth: hairline)
    }

    private static func drawPectoral(body: FishBody, shape: FishShape, phase: CGFloat, ctx: GraphicsContext, fill: Color) {
        let t = shape.eyeT + 0.16
        let root = body.at(t, -body.bottom(t) * 0.3)
        let (_, up) = body.spine(t)
        let heading = atan2(up.dx, -up.dy)
        let flap = sin(phase * 0.9 + 1.0)

        var pctx = ctx
        pctx.translateBy(x: root.x, y: root.y)
        pctx.rotate(by: .radians(Double(heading + .pi - 0.55 + 0.35 * flap)))
        pctx.scaleBy(x: 0.8 + 0.2 * flap, y: 1)

        let l = shape.pectoral * body.s
        var path = Path()
        path.move(to: .zero)
        path.addQuadCurve(to: CGPoint(x: l, y: -l * 0.1), control: CGPoint(x: l * 0.45, y: -l * 0.55))
        path.addQuadCurve(to: .zero, control: CGPoint(x: l * 0.6, y: l * 0.35))
        path.closeSubpath()
        pctx.fill(path, with: .linearGradient(
            Gradient(colors: [fill, fill.opacity(0.35)]),
            startPoint: .zero,
            endPoint: CGPoint(x: l, y: 0)
        ))
    }

    private static func drawEye(body: FishBody, shape: FishShape, ctx: GraphicsContext, iris: Color, rim: Color) {
        let c = body.at(shape.eyeT, body.top(shape.eyeT) * 0.22)
        let r = shape.eyeSize * body.s
        func disc(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        }
        ctx.fill(disc(c.x, c.y, r), with: .color(rim))
        ctx.fill(disc(c.x, c.y, r * 0.84), with: .color(iris))
        ctx.fill(disc(c.x + r * 0.1, c.y, r * 0.56), with: .color(Color(white: 0.04)))
        ctx.fill(disc(c.x + r * 0.28, c.y - r * 0.3, r * 0.24), with: .color(.white.opacity(0.95)))
    }

    private static func drawPattern(_ pattern: FishShape.Pattern, body: FishBody, ctx: GraphicsContext,
                                    pal: FishPalette, color: (SIMD3<Double>, Double) -> Color) {
        let s = body.s
        switch pattern {
        case .none:
            break

        case .bands:
            var dark = Path()
            var light = Path()
            for (center, half) in [(CGFloat(0.2), CGFloat(0.05)), (0.52, 0.06), (0.86, 0.035)] {
                for (isEdge, w) in [(true, half + 0.02), (false, half)] {
                    var band = Path()
                    band.move(to: body.at(center - w, body.top(center) * 1.4))
                    band.addLine(to: body.at(center + w, body.top(center) * 1.4))
                    band.addQuadCurve(to: body.at(center + w, -body.bottom(center) * 1.4), control: body.at(center + w + 0.06, 0))
                    band.addLine(to: body.at(center - w, -body.bottom(center) * 1.4))
                    band.addQuadCurve(to: body.at(center - w, body.top(center) * 1.4), control: body.at(center - w + 0.06, 0))
                    band.closeSubpath()
                    if isEdge { dark.addPath(band) } else { light.addPath(band) }
                }
            }
            ctx.fill(dark, with: .color(color(pal.accent2, 1)))
            ctx.fill(light, with: .color(color(pal.accent, 1)))

        case .swoosh:
            let dark = body.band(from: 0.16, to: 0.98,
                                 upper: { body.top($0) * 0.74 },
                                 lower: { body.top($0) * 0.1 - body.bottom($0) * 0.35 * sin(.pi * ($0 - 0.16) / 0.82) })
            let lens = { (t: CGFloat) in 0.17 * sin(.pi * (t - 0.32) / 0.44) }
            let inner = body.band(from: 0.32, to: 0.76,
                                  upper: { body.top($0) * (0.4 + lens($0)) },
                                  lower: { body.top($0) * (0.4 - lens($0)) })
            ctx.fill(dark, with: .color(color(pal.accent, 1)))
            ctx.fill(inner, with: .color(color(pal.accent2, 1)))

        case .neonStripe:
            let red = body.band(from: 0.5, to: 1.1,
                                upper: { -body.bottom($0) * 0.05 },
                                lower: { _ in -s })
            let stripe = body.band(from: 0.14, to: 1.02,
                                   upper: { body.top($0) * 0.3 },
                                   lower: { -body.bottom($0) * 0.02 })
            ctx.fill(red, with: .color(color(pal.accent2, 0.95)))
            ctx.fill(stripe, with: .color(color(pal.accent, 1)))

        case .eyeBand:
            let e = body.shape.eyeT
            var band = Path()
            band.move(to: body.at(e - 0.045, s))
            band.addLine(to: body.at(e + 0.05, s))
            band.addLine(to: body.at(e + 0.065, -s))
            band.addLine(to: body.at(e - 0.03, -s))
            band.closeSubpath()
            ctx.fill(band, with: .color(color(pal.accent, 0.9)))

            let rear = body.band(from: 0.9, to: 1.1, upper: { _ in s }, lower: { _ in -s })
            ctx.fill(rear, with: .color(color(pal.accent, 0.25)))

        case .bars:
            var bars = Path()
            for t in stride(from: CGFloat(0.24), through: 0.9, by: 0.11) {
                bars.move(to: body.at(t, body.top(t) * 1.1))
                bars.addCurve(to: body.at(t + 0.03, body.top(t) * 0.3),
                              control1: body.at(t - 0.05, body.top(t) * 0.75),
                              control2: body.at(t + 0.07, body.top(t) * 0.55))
            }
            ctx.stroke(bars, with: .color(color(pal.accent, 0.7)), style: StrokeStyle(lineWidth: s * 0.022, lineCap: .round))
            var lateral = Path()
            lateral.move(to: body.at(0.22, 0))
            for t in stride(from: CGFloat(0.3), through: 1.0, by: 0.1) {
                lateral.addLine(to: body.at(t, 0))
            }
            ctx.stroke(lateral, with: .color(color(pal.accent, 0.35)), lineWidth: max(0.5, s * 0.012))
        }
    }
}
