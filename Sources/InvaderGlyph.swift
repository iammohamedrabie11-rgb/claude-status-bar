import Cocoa

// MARK: - Invader glyph
//
// The tintable, state-aware Space-Invader that replaces the old crab sprite. Source of
// truth: assets/glyphs/invader-{idle,working,permission}.svg — every path paints via SVG
// `currentColor`, so the shapes below are filled/stroked with whatever accent the caller
// supplies (a per-session palette entry, the brand anchor color, or nil => adaptive
// template). Unlike the crab (a full-color PNG sprite that ignored the accent), this glyph
// tints to any color. The `d` strings are copied verbatim from those SVGs (viewBox 0 0 11 8).

enum InvaderState { case idle, working, permission }

// Invader body + two eye holes (evenodd). Also the working march's "frame A" pose.
private let invaderIdlePath = "M2.00 0.30Q2.00 0.00 2.30 0.00L8.70 0.00Q9.00 0.00 9.00 0.30L9.00 1.70Q9.00 2.00 9.30 2.00L10.70 2.00Q11.00 2.00 11.00 2.30L11.00 3.70Q11.00 4.00 10.70 4.00L9.30 4.00Q9.00 4.00 9.00 4.30L9.00 7.70Q9.00 8.00 8.70 8.00L8.30 8.00Q8.00 8.00 8.00 7.70L8.00 6.30Q8.00 6.00 7.70 6.00L7.30 6.00Q7.00 6.00 7.00 6.30L7.00 7.70Q7.00 8.00 6.70 8.00L6.30 8.00Q6.00 8.00 6.00 7.70L6.00 6.30Q6.00 6.00 5.70 6.00L5.30 6.00Q5.00 6.00 5.00 6.30L5.00 7.70Q5.00 8.00 4.70 8.00L4.30 8.00Q4.00 8.00 4.00 7.70L4.00 6.30Q4.00 6.00 3.70 6.00L3.30 6.00Q3.00 6.00 3.00 6.30L3.00 7.70Q3.00 8.00 2.70 8.00L2.30 8.00Q2.00 8.00 2.00 7.70L2.00 4.30Q2.00 4.00 1.70 4.00L0.30 4.00Q0.00 4.00 0.00 3.70L0.00 2.30Q0.00 2.00 0.30 2.00L1.70 2.00Q2.00 2.00 2.00 1.70ZM4.00 1.30Q4.00 1.00 3.70 1.00L3.30 1.00Q3.00 1.00 3.00 1.30L3.00 1.70Q3.00 2.00 3.30 2.00L3.70 2.00Q4.00 2.00 4.00 1.70ZM8.00 1.30Q8.00 1.00 7.70 1.00L7.30 1.00Q7.00 1.00 7.00 1.30L7.00 1.70Q7.00 2.00 7.30 2.00L7.70 2.00Q8.00 2.00 8.00 1.70Z"

// Working march "frame B" (arms/legs shifted down). Same two eye holes.
private let invaderWorkingBPath = "M2.00 0.30Q2.00 0.00 2.30 0.00L8.70 0.00Q9.00 0.00 9.00 0.30L9.00 2.70Q9.00 3.00 9.30 3.00L10.70 3.00Q11.00 3.00 11.00 3.30L11.00 4.70Q11.00 5.00 10.70 5.00L9.30 5.00Q9.00 5.00 9.00 5.30L9.00 5.70Q9.00 6.00 8.70 6.00L8.30 6.00Q8.00 6.00 8.00 6.30L8.00 7.70Q8.00 8.00 7.70 8.00L7.30 8.00Q7.00 8.00 7.00 7.70L7.00 6.30Q7.00 6.00 6.70 6.00L6.30 6.00Q6.00 6.00 6.00 6.30L6.00 7.70Q6.00 8.00 5.70 8.00L5.30 8.00Q5.00 8.00 5.00 7.70L5.00 6.30Q5.00 6.00 4.70 6.00L4.30 6.00Q4.00 6.00 4.00 6.30L4.00 7.70Q4.00 8.00 3.70 8.00L3.30 8.00Q3.00 8.00 3.00 7.70L3.00 6.30Q3.00 6.00 2.70 6.00L2.30 6.00Q2.00 6.00 2.00 5.70L2.00 5.30Q2.00 5.00 1.70 5.00L0.30 5.00Q0.00 5.00 0.00 4.70L0.00 3.30Q0.00 3.00 0.30 3.00L1.70 3.00Q2.00 3.00 2.00 2.70ZM4.00 1.30Q4.00 1.00 3.70 1.00L3.30 1.00Q3.00 1.00 3.00 1.30L3.00 1.70Q3.00 2.00 3.30 2.00L3.70 2.00Q4.00 2.00 4.00 1.70ZM8.00 1.30Q8.00 1.00 7.70 1.00L7.30 1.00Q7.00 1.00 7.00 1.30L7.00 1.70Q7.00 2.00 7.30 2.00L7.70 2.00Q8.00 2.00 8.00 1.70Z"

// Awaiting permission: hollow body outline (stroked, no eyes) + a filled corner dot.
private let invaderPermissionPath = "M2.00 0.36Q2.00 0.00 2.36 0.00L8.64 0.00Q9.00 0.00 9.00 0.36L9.00 1.64Q9.00 2.00 9.36 2.00L10.64 2.00Q11.00 2.00 11.00 2.36L11.00 3.64Q11.00 4.00 10.64 4.00L9.36 4.00Q9.00 4.00 9.00 4.36L9.00 7.64Q9.00 8.00 8.64 8.00L8.36 8.00Q8.00 8.00 8.00 7.64L8.00 6.36Q8.00 6.00 7.64 6.00L7.36 6.00Q7.00 6.00 7.00 6.36L7.00 7.64Q7.00 8.00 6.64 8.00L6.36 8.00Q6.00 8.00 6.00 7.64L6.00 6.36Q6.00 6.00 5.64 6.00L5.36 6.00Q5.00 6.00 5.00 6.36L5.00 7.64Q5.00 8.00 4.64 8.00L4.36 8.00Q4.00 8.00 4.00 7.64L4.00 6.36Q4.00 6.00 3.64 6.00L3.36 6.00Q3.00 6.00 3.00 6.36L3.00 7.64Q3.00 8.00 2.64 8.00L2.36 8.00Q2.00 8.00 2.00 7.64L2.00 4.36Q2.00 4.00 1.64 4.00L0.36 4.00Q0.00 4.00 0.00 3.64L0.00 2.36Q0.00 2.00 0.36 2.00L1.64 2.00Q2.00 2.00 2.00 1.64Z"
private let invaderPermStrokeWidth: CGFloat = 0.92                        // in grid units
private let invaderPermDot: (x: CGFloat, y: CGFloat, r: CGFloat) = (10.45, 0.55, 1.15)

// Design grid: SVG viewBox is 11 wide x 8 tall.
private let invaderGridW: CGFloat = 11, invaderGridH: CGFloat = 8

// Minimal SVG path parser: absolute M / L / Q / Z only — the complete command set these
// three glyphs use. Coordinates stay in the 11x8 SVG grid (y-down); invaderIcon flips to
// AppKit's y-up at draw time. Not a general SVG parser (no relative/cubic/arc commands).
private func invaderCGPath(_ d: String) -> CGPath {
    let path = CGMutablePath()
    var cmd: Character = " "
    var nums: [CGFloat] = []
    func emit() {   // emit greedily as soon as the current command has enough operands
        switch cmd {
        case "M" where nums.count == 2:
            path.move(to: CGPoint(x: nums[0], y: nums[1])); nums.removeAll(keepingCapacity: true)
        case "L" where nums.count == 2:
            path.addLine(to: CGPoint(x: nums[0], y: nums[1])); nums.removeAll(keepingCapacity: true)
        case "Q" where nums.count == 4:
            path.addQuadCurve(to: CGPoint(x: nums[2], y: nums[3]),
                              control: CGPoint(x: nums[0], y: nums[1])); nums.removeAll(keepingCapacity: true)
        default: break
        }
    }
    var i = d.startIndex
    while i < d.endIndex {
        let ch = d[i]
        switch ch {
        case "M", "L", "Q":
            cmd = ch; nums.removeAll(keepingCapacity: true); i = d.index(after: i)
        case "Z", "z":
            path.closeSubpath(); cmd = " "; nums.removeAll(keepingCapacity: true); i = d.index(after: i)
        case " ", ",", "\n", "\t":
            i = d.index(after: i)
        default:
            var j = i
            while j < d.endIndex, "0123456789.+-eE".contains(d[j]) { j = d.index(after: j) }
            if j > i, let v = Double(d[i..<j]) { nums.append(CGFloat(v)); emit(); i = j }
            else { i = d.index(after: i) }   // no-progress guard
        }
    }
    return path
}

extension StatusController {
    // Draw the Invader for `state`, filled/stroked with `color` (nil => adaptive template).
    // `frame` selects the 2-frame march for .working (frame % 2). Permission is always drawn
    // in the fixed amber the caller passes, so it never renders as a template.
    //
    // The 11x8 grid is mapped into the image with a small uniform inset (pad): it gives the
    // hollow permission stroke room (its outline hugs the grid edges) and keeps every state
    // the same footprint, so the menu-bar icon doesn't resize as the state changes.
    func invaderIcon(_ state: InvaderState, color: NSColor?, frame: Int = 0) -> NSImage {
        let h: CGFloat = 18, pad: CGFloat = 1
        let scale = (h - 2 * pad) / invaderGridH          // uniform grid->points scale
        let contentW = invaderGridW * scale
        let w = contentW + 2 * pad
        let ink = color ?? .black                          // template mode ignores ink; alpha carries the shape
        let img = NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            // SVG grid (y-down) -> AppKit (y-up), inset by `pad` on every side.
            ctx.translateBy(x: pad, y: h - pad)
            ctx.scaleBy(x: scale, y: -scale)
            ctx.setFillColor(ink.cgColor)
            switch state {
            case .idle:
                ctx.addPath(invaderCGPath(invaderIdlePath))
                ctx.fillPath(using: .evenOdd)
            case .working:
                ctx.addPath(invaderCGPath(frame % 2 == 0 ? invaderIdlePath : invaderWorkingBPath))
                ctx.fillPath(using: .evenOdd)
            case .permission:
                ctx.addPath(invaderCGPath(invaderPermissionPath))
                ctx.setStrokeColor(ink.cgColor)
                ctx.setLineWidth(invaderPermStrokeWidth)
                ctx.setLineJoin(.round); ctx.setLineCap(.round)
                ctx.strokePath()
                ctx.addEllipse(in: CGRect(x: invaderPermDot.x - invaderPermDot.r,
                                          y: invaderPermDot.y - invaderPermDot.r,
                                          width: 2 * invaderPermDot.r, height: 2 * invaderPermDot.r))
                ctx.fillPath()
            }
            return true
        }
        img.isTemplate = (color == nil)
        return img
    }
}
