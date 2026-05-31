import SwiftUI

struct CatView: View {
    var isStretching: Bool = false
    @State private var bounce = false

    var body: some View {
        Canvas { ctx, size in
            drawCat(in: ctx, size: size, isStretching: isStretching)
        }
        .scaleEffect(bounce ? 1.04 : 0.97)
        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bounce)
        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isStretching)
        .onAppear { bounce = true }
    }

    // swiftlint:disable:next function_body_length
    private func drawCat(in ctx: GraphicsContext, size: CGSize, isStretching: Bool) {
        let scale = min(size.width / 100, size.height / 130)
        let ox = (size.width - 100 * scale) / 2
        let oy = (size.height - 130 * scale) / 2

        func px(_ v: CGFloat) -> CGFloat { ox + v * scale }
        func py(_ v: CGFloat) -> CGFloat { oy + v * scale }
        func ps(_ v: CGFloat) -> CGFloat { v * scale }

        let cream = Color(red: 1.0, green: 0.97, blue: 0.88)
        let ink = Color(red: 0.12, green: 0.08, blue: 0.04)
        let thick = StrokeStyle(lineWidth: ps(2.5), lineCap: .round, lineJoin: .round)
        let thin  = StrokeStyle(lineWidth: ps(1.5), lineCap: .round, lineJoin: .round)

        // ── Body ──────────────────────────────────────────────────
        let bodyRect = CGRect(x: px(28), y: py(54), width: ps(44), height: ps(44))
        ctx.fill(Path(roundedRect: bodyRect, cornerRadius: ps(13)), with: .color(cream))
        ctx.stroke(Path(roundedRect: bodyRect, cornerRadius: ps(13)), with: .color(ink), style: thick)

        // ── Head ──────────────────────────────────────────────────
        let headRect = CGRect(x: px(22), y: py(8), width: ps(56), height: ps(52))
        ctx.fill(Path(ellipseIn: headRect), with: .color(cream))
        ctx.stroke(Path(ellipseIn: headRect), with: .color(ink), style: thick)

        // ── Ears ──────────────────────────────────────────────────
        for (a, b, c) in [
            (CGPoint(x: px(28), y: py(24)), CGPoint(x: px(32), y: py(6)),  CGPoint(x: px(42), y: py(18))),
            (CGPoint(x: px(72), y: py(24)), CGPoint(x: px(68), y: py(6)),  CGPoint(x: px(58), y: py(18)))
        ] {
            ctx.fill(Path { p in p.move(to: a); p.addLine(to: b); p.addLine(to: c); p.closeSubpath() }, with: .color(cream))
            ctx.stroke(Path { p in p.move(to: a); p.addLine(to: b); p.addLine(to: c); p.closeSubpath() }, with: .color(ink), style: thick)
        }

        // ── Eyes ──────────────────────────────────────────────────
        ctx.fill(Path(ellipseIn: CGRect(x: px(36), y: py(29), width: ps(6), height: ps(6))), with: .color(ink))
        ctx.fill(Path(ellipseIn: CGRect(x: px(58), y: py(29), width: ps(6), height: ps(6))), with: .color(ink))

        // ── Nose ──────────────────────────────────────────────────
        ctx.fill(Path(ellipseIn: CGRect(x: px(47), y: py(38), width: ps(6), height: ps(4))), with: .color(.pink))

        // ── Smile ─────────────────────────────────────────────────
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: px(43), y: py(44)))
            p.addQuadCurve(to: CGPoint(x: px(57), y: py(44)), control: CGPoint(x: px(50), y: py(50)))
        }, with: .color(ink), style: StrokeStyle(lineWidth: ps(2.2), lineCap: .round))

        // ── Whiskers ──────────────────────────────────────────────
        let whiskers: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (42, 33, 5,  31), (42, 37, 3,  36), (42, 42, 6,  43),
            (58, 33, 95, 31), (58, 37, 97, 36), (58, 42, 94, 43)
        ]
        for (fx, fy, tx, ty) in whiskers {
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: px(fx), y: py(fy)))
                p.addLine(to: CGPoint(x: px(tx), y: py(ty)))
            }, with: .color(ink), style: thin)
        }

        // ── Arms ──────────────────────────────────────────────────
        let leftEnd  = isStretching ? CGPoint(x: px(6),  y: py(40)) : CGPoint(x: px(12), y: py(80))
        let rightEnd = isStretching ? CGPoint(x: px(94), y: py(40)) : CGPoint(x: px(88), y: py(80))
        let pawR = ps(7)

        for (shoulder, end) in [(CGPoint(x: px(30), y: py(64)), leftEnd),
                                (CGPoint(x: px(70), y: py(64)), rightEnd)] {
            let pawRect = CGRect(x: end.x - pawR, y: end.y - pawR, width: pawR * 2, height: pawR * 2)
            ctx.fill(Path(ellipseIn: pawRect), with: .color(cream))
            ctx.stroke(Path { p in p.move(to: shoulder); p.addLine(to: end) }, with: .color(ink), style: thick)
            ctx.stroke(Path(ellipseIn: pawRect), with: .color(ink), style: StrokeStyle(lineWidth: ps(2.2), lineCap: .round))
        }

        // ── Legs & Feet ────────────────────────────────────────────
        for (hip, foot) in [(CGPoint(x: px(38), y: py(96)), CGPoint(x: px(34), y: py(120))),
                            (CGPoint(x: px(62), y: py(96)), CGPoint(x: px(66), y: py(120)))] {
            let footRect = CGRect(x: foot.x - ps(8), y: foot.y - ps(6), width: ps(16), height: ps(11))
            ctx.fill(Path(ellipseIn: footRect), with: .color(cream))
            ctx.stroke(Path { p in p.move(to: hip); p.addLine(to: foot) }, with: .color(ink), style: thick)
            ctx.stroke(Path(ellipseIn: footRect), with: .color(ink), style: StrokeStyle(lineWidth: ps(2.2)))
        }

        // ── Tail ──────────────────────────────────────────────────
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: px(70), y: py(88)))
            p.addCurve(
                to: CGPoint(x: px(86), y: py(60)),
                control1: CGPoint(x: px(92), y: py(90)),
                control2: CGPoint(x: px(96), y: py(72))
            )
        }, with: .color(ink), style: StrokeStyle(lineWidth: ps(3.5), lineCap: .round))
    }
}
