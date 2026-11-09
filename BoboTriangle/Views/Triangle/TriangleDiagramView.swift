import SwiftUI

struct TriangleDrawingOptions: Equatable {
    var labels = true
    var heights = false
    var medians = false
    var bisectors = false
    var circumcircle = false
    var incircle = false
    var centroid = false
    var circumcenter = false
    var incenter = false
    var orthocenter = false
}

struct TriangleDiagramView: View {
    let solution: TriangleSolution?
    var options = TriangleDrawingOptions()
    var language: AppLanguage = .simplifiedChinese

    var body: some View {
        Canvas { context, size in
            guard let solution else {
                drawPlaceholder(in: &context, size: size)
                return
            }
            draw(solution, in: &context, size: size)
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(solution == nil ? language.text("等待输入的三角形示意图", "Triangle placeholder awaiting input") : language.text("按实际边长比例绘制的三角形", "Triangle drawn to calculated side proportions"))
    }

    private func drawPlaceholder(in context: inout GraphicsContext, size: CGSize) {
        let points = [
            CGPoint(x: size.width * 0.18, y: size.height * 0.78),
            CGPoint(x: size.width * 0.82, y: size.height * 0.78),
            CGPoint(x: size.width * 0.58, y: size.height * 0.2)
        ]
        var path = Path()
        path.move(to: points[0]); path.addLine(to: points[1]); path.addLine(to: points[2]); path.closeSubpath()
        context.fill(path, with: .color(.boboBlue.opacity(0.06)))
        context.stroke(path, with: .color(.secondary.opacity(0.25)), style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
        context.draw(Text(language.text("输入任意三项后显示图形", "Enter any three values to draw")).font(.caption).foregroundStyle(.secondary), at: CGPoint(x: size.width / 2, y: size.height * 0.9))
    }

    private func draw(_ solution: TriangleSolution, in context: inout GraphicsContext, size: CGSize) {
        let rawA = CGPoint(x: 0, y: 0)
        let rawB = CGPoint(x: CGFloat(solution.c), y: 0)
        let x = CGFloat((solution.b * solution.b + solution.c * solution.c - solution.a * solution.a) / (2 * solution.c))
        let rawC = CGPoint(x: x, y: CGFloat(sqrt(max(0, solution.b * solution.b - Double(x * x)))))
        let geometry = fitted(rawA, rawB, rawC, size: size)
        let A = geometry.transform(rawA), B = geometry.transform(rawB), C = geometry.transform(rawC)

        let circumcenterRaw = CGPoint(
            x: CGFloat(solution.c) / 2,
            y: (rawC.x * rawC.x + rawC.y * rawC.y - CGFloat(solution.c) * rawC.x) / (2 * rawC.y)
        )
        let incenterRaw = weighted(rawA, rawB, rawC, weights: (CGFloat(solution.a), CGFloat(solution.b), CGFloat(solution.c)))
        let centroidRaw = CGPoint(x: (rawA.x + rawB.x + rawC.x) / 3, y: (rawA.y + rawB.y + rawC.y) / 3)
        let orthocenterRaw = CGPoint(
            x: rawA.x + rawB.x + rawC.x - 2 * circumcenterRaw.x,
            y: rawA.y + rawB.y + rawC.y - 2 * circumcenterRaw.y
        )

        if options.circumcircle {
            let O = geometry.transform(circumcenterRaw)
            let radius = distance(circumcenterRaw, rawA) * geometry.scale
            context.stroke(Path(ellipseIn: CGRect(x: O.x - radius, y: O.y - radius, width: radius * 2, height: radius * 2)), with: .color(.orange.opacity(0.65)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
        if options.incircle {
            let I = geometry.transform(incenterRaw)
            let radius = CGFloat(solution.inradius) * geometry.scale
            context.stroke(Path(ellipseIn: CGRect(x: I.x - radius, y: I.y - radius, width: radius * 2, height: radius * 2)), with: .color(.green.opacity(0.75)), lineWidth: 1.5)
        }

        if options.heights {
            drawAuxiliary(from: rawA, to: projection(rawA, onto: rawB, rawC), geometry: geometry, color: .red, context: &context)
            drawAuxiliary(from: rawB, to: projection(rawB, onto: rawA, rawC), geometry: geometry, color: .red, context: &context)
            drawAuxiliary(from: rawC, to: projection(rawC, onto: rawA, rawB), geometry: geometry, color: .red, context: &context)
        }
        if options.medians {
            drawAuxiliary(from: rawA, to: midpoint(rawB, rawC), geometry: geometry, color: .purple, context: &context)
            drawAuxiliary(from: rawB, to: midpoint(rawA, rawC), geometry: geometry, color: .purple, context: &context)
            drawAuxiliary(from: rawC, to: midpoint(rawA, rawB), geometry: geometry, color: .purple, context: &context)
        }
        if options.bisectors {
            drawAuxiliary(from: rawA, to: divide(rawB, rawC, firstWeight: CGFloat(solution.c), secondWeight: CGFloat(solution.b)), geometry: geometry, color: .teal, context: &context)
            drawAuxiliary(from: rawB, to: divide(rawA, rawC, firstWeight: CGFloat(solution.c), secondWeight: CGFloat(solution.a)), geometry: geometry, color: .teal, context: &context)
            drawAuxiliary(from: rawC, to: divide(rawA, rawB, firstWeight: CGFloat(solution.b), secondWeight: CGFloat(solution.a)), geometry: geometry, color: .teal, context: &context)
        }

        var triangle = Path()
        triangle.move(to: A); triangle.addLine(to: B); triangle.addLine(to: C); triangle.closeSubpath()
        context.fill(triangle, with: .color(.boboBlue.opacity(0.1)))
        context.stroke(triangle, with: .color(.boboBlue), style: StrokeStyle(lineWidth: 3, lineJoin: .round))

        if options.centroid { drawPoint(geometry.transform(centroidRaw), label: "G", color: .purple, context: &context) }
        if options.circumcenter { drawPoint(geometry.transform(circumcenterRaw), label: "O", color: .orange, context: &context) }
        if options.incenter { drawPoint(geometry.transform(incenterRaw), label: "I", color: .green, context: &context) }
        if options.orthocenter { drawPoint(geometry.transform(orthocenterRaw), label: "H", color: .red, context: &context) }

        guard options.labels else { return }
        drawLabel("A  \(solution.A.formatted(maxDigits: 1))°", at: offset(A, dx: -16, dy: 14), context: &context)
        drawLabel("B  \(solution.B.formatted(maxDigits: 1))°", at: offset(B, dx: 16, dy: 14), context: &context)
        drawLabel("C  \(solution.C.formatted(maxDigits: 1))°", at: offset(C, dx: 0, dy: -15), context: &context)
        drawLabel("c = \(solution.c.formatted(maxDigits: 3))", at: offset(midpoint(A, B), dx: 0, dy: 15), context: &context)
        drawLabel("a = \(solution.a.formatted(maxDigits: 3))", at: offset(midpoint(B, C), dx: 18, dy: 0), context: &context)
        drawLabel("b = \(solution.b.formatted(maxDigits: 3))", at: offset(midpoint(A, C), dx: -18, dy: 0), context: &context)
    }

    private func fitted(_ A: CGPoint, _ B: CGPoint, _ C: CGPoint, size: CGSize) -> (transform: (CGPoint) -> CGPoint, scale: CGFloat) {
        let padding: CGFloat = 42
        let minX = min(A.x, B.x, C.x), maxX = max(A.x, B.x, C.x)
        let minY = min(A.y, B.y, C.y), maxY = max(A.y, B.y, C.y)
        let width = max(maxX - minX, 0.0001), height = max(maxY - minY, 0.0001)
        let scale = min((size.width - padding * 2) / width, (size.height - padding * 2) / height)
        let drawnWidth = width * scale, drawnHeight = height * scale
        let originX = (size.width - drawnWidth) / 2 - minX * scale
        let baselineY = (size.height + drawnHeight) / 2 + minY * scale - 4
        return ({ point in CGPoint(x: originX + point.x * scale, y: baselineY - point.y * scale) }, scale)
    }

    private func drawAuxiliary(from: CGPoint, to: CGPoint, geometry: (transform: (CGPoint) -> CGPoint, scale: CGFloat), color: Color, context: inout GraphicsContext) {
        var path = Path(); path.move(to: geometry.transform(from)); path.addLine(to: geometry.transform(to))
        context.stroke(path, with: .color(color.opacity(0.7)), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
    }

    private func drawPoint(_ point: CGPoint, label: String, color: Color, context: inout GraphicsContext) {
        context.fill(Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)), with: .color(color))
        context.draw(Text(label).font(.caption2.bold()).foregroundStyle(color), at: offset(point, dx: 10, dy: -9))
    }

    private func drawLabel(_ text: String, at point: CGPoint, context: inout GraphicsContext) {
        context.draw(Text(text).font(.caption2.monospacedDigit()).foregroundStyle(.primary), at: point)
    }

    private func midpoint(_ p: CGPoint, _ q: CGPoint) -> CGPoint { CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2) }
    private func offset(_ p: CGPoint, dx: CGFloat, dy: CGFloat) -> CGPoint { CGPoint(x: p.x + dx, y: p.y + dy) }
    private func distance(_ p: CGPoint, _ q: CGPoint) -> CGFloat { hypot(p.x - q.x, p.y - q.y) }

    private func projection(_ point: CGPoint, onto first: CGPoint, _ second: CGPoint) -> CGPoint {
        let dx = second.x - first.x, dy = second.y - first.y
        let t = ((point.x - first.x) * dx + (point.y - first.y) * dy) / (dx * dx + dy * dy)
        return CGPoint(x: first.x + t * dx, y: first.y + t * dy)
    }

    private func weighted(_ A: CGPoint, _ B: CGPoint, _ C: CGPoint, weights: (CGFloat, CGFloat, CGFloat)) -> CGPoint {
        let sum = weights.0 + weights.1 + weights.2
        return CGPoint(x: (A.x * weights.0 + B.x * weights.1 + C.x * weights.2) / sum, y: (A.y * weights.0 + B.y * weights.1 + C.y * weights.2) / sum)
    }

    private func divide(_ first: CGPoint, _ second: CGPoint, firstWeight: CGFloat, secondWeight: CGFloat) -> CGPoint {
        let total = firstWeight + secondWeight
        return CGPoint(x: (first.x * secondWeight + second.x * firstWeight) / total, y: (first.y * secondWeight + second.y * firstWeight) / total)
    }
}
