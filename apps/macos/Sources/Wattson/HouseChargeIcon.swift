import AppKit

/// Draws the full menu bar glyph: a left-hand column (solar wattage + sun
/// on top, grid import/export arrows on the bottom), a house-shaped battery
/// gauge styled after macOS's own battery icon, and a right-hand column
/// (charge percentage on top, consumption on the bottom) — the two columns
/// mirror each other's row heights so everything reads as one aligned grid.
///
/// This image is NOT a template (`isTemplate = false`), since the sun and
/// grid arrows need real color (yellow/blue) to show active vs. inactive
/// state, and template images are forced monochrome by the OS. That means
/// the house portion has to pick its own light/dark "ink" color by hand
/// instead of getting that adaptation for free — see `currentInkColor()`.
@MainActor
enum HouseChargeIcon {
    /// Menu bar wattage readouts drop the "kW" suffix to save space and
    /// always show one decimal place.
    nonisolated static func formatKW(_ watts: Double) -> String {
        String(format: "%.1f", watts / 1000)
    }

    /// Gap between a wattage number and its icon at the default menu bar
    /// size (18pt).
    static let numberIconGap: CGFloat = 18 * 0.08

    static func make(
        percentage: Double,
        isCharging: Bool,
        isDischarging: Bool,
        solarPower: Double,
        isSolarActive: Bool,
        gridPower: Double,
        isGridImporting: Bool,
        isGridExporting: Bool,
        loadPower: Double,
        size: CGFloat = 18
    ) -> NSImage {
        let clamped = max(0, min(100, percentage))
        let ink = currentInkColor()
        let dimInk = ink.withAlphaComponent(0.28)
        let textFont = NSFont.monospacedDigitSystemFont(ofSize: size * 0.5, weight: .regular)

        let solarText = NSAttributedString(
            string: formatKW(solarPower),
            attributes: [.font: textFont, .foregroundColor: isSolarActive ? NSColor.systemYellow : dimInk]
        )
        let solarTextSize = solarText.size()

        let sunConfiguration = NSImage.SymbolConfiguration(pointSize: size * 0.56, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [isSolarActive ? .systemYellow : dimInk]))
        let sunImage = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Solar")?
            .withSymbolConfiguration(sunConfiguration)
        let sunSize = sunImage?.size ?? .zero

        // Green when exporting to the grid, red when importing from it —
        // red doubling up with the consumption reading's color is
        // intentional: both represent power being drawn/used.
        let gridColor: NSColor = isGridExporting ? .systemGreen : (isGridImporting ? .systemRed : dimInk)
        let gridText = NSAttributedString(
            string: formatKW(abs(gridPower)),
            attributes: [.font: textFont, .foregroundColor: gridColor]
        )
        let gridTextSize = gridText.size()

        let arrowConfiguration = NSImage.SymbolConfiguration(pointSize: size * 0.32, weight: .bold)
        let exportImage = NSImage(systemSymbolName: "arrowtriangle.left.fill", accessibilityDescription: "Exporting to grid")?
            .withSymbolConfiguration(arrowConfiguration.applying(NSImage.SymbolConfiguration(paletteColors: [isGridExporting ? .systemGreen : dimInk])))
        let importImage = NSImage(systemSymbolName: "arrowtriangle.right.fill", accessibilityDescription: "Importing from grid")?
            .withSymbolConfiguration(arrowConfiguration.applying(NSImage.SymbolConfiguration(paletteColors: [isGridImporting ? .systemRed : dimInk])))
        let exportSize = exportImage?.size ?? .zero
        let importSize = importImage?.size ?? .zero

        let percentageText = NSAttributedString(
            string: "\(Int(clamped.rounded()))%",
            attributes: [.font: textFont, .foregroundColor: ink]
        )
        let percentageTextSize = percentageText.size()

        let consumptionConfiguration = NSImage.SymbolConfiguration(pointSize: size * 0.32, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.systemRed]))
        let consumptionImage = NSImage(systemSymbolName: "arrowtriangle.right.fill", accessibilityDescription: "Consumption")?
            .withSymbolConfiguration(consumptionConfiguration)
        let consumptionSize = consumptionImage?.size ?? .zero
        let consumptionText = NSAttributedString(
            string: formatKW(loadPower),
            attributes: [.font: textFont, .foregroundColor: NSColor.systemRed]
        )
        let consumptionTextSize = consumptionText.size()

        let textIconGap = size * (numberIconGap / 18)
        let columnMargin = size * 0.05
        let topRowWidth = solarTextSize.width + textIconGap + sunSize.width
        let bottomRowWidth = gridTextSize.width + textIconGap + exportSize.width + textIconGap * 0.6 + importSize.width
        let leftColumnWidth = columnMargin + max(topRowWidth, bottomRowWidth) + columnMargin

        let consumptionRowWidth = consumptionSize.width + textIconGap + consumptionTextSize.width
        let rightColumnWidth = columnMargin + max(percentageTextSize.width, consumptionRowWidth) + columnMargin

        let houseWidth = size * (14.0 / 18.0)
        let houseCanvasWidth = size
        let totalWidth = leftColumnWidth + houseCanvasWidth + rightColumnWidth

        let image = NSImage(size: NSSize(width: totalWidth, height: size), flipped: false) { _ in
            drawLeftColumn(
                width: leftColumnWidth,
                height: size,
                margin: columnMargin,
                textIconGap: textIconGap,
                font: textFont,
                solarText: solarText,
                solarTextSize: solarTextSize,
                sunImage: sunImage,
                sunSize: sunSize,
                gridText: gridText,
                gridTextSize: gridTextSize,
                exportImage: exportImage,
                exportSize: exportSize,
                importImage: importImage,
                importSize: importSize
            )

            drawHouse(
                canvasOffsetX: leftColumnWidth,
                size: size,
                houseWidth: houseWidth,
                percentage: clamped,
                isCharging: isCharging,
                isDischarging: isDischarging,
                ink: ink
            )

            drawRightColumn(
                canvasOffsetX: leftColumnWidth + houseCanvasWidth,
                height: size,
                margin: columnMargin,
                textIconGap: textIconGap,
                font: textFont,
                percentageText: percentageText,
                consumptionImage: consumptionImage,
                consumptionSize: consumptionSize,
                consumptionText: consumptionText,
                consumptionTextSize: consumptionTextSize
            )

            return true
        }

        image.isTemplate = false
        return image
    }

    /// Just the house/gauge, without the solar+grid column — for places
    /// like the dropdown header where it's shown bigger on its own and the
    /// solar/grid detail is already broken out into separate rows.
    static func makeHouseOnly(percentage: Double, isCharging: Bool, isDischarging: Bool = false, size: CGFloat = 18) -> NSImage {
        let clamped = max(0, min(100, percentage))
        let ink = currentInkColor()
        let houseWidth = size * (12.0 / 18.0)

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            drawHouse(canvasOffsetX: 0, size: size, houseWidth: houseWidth, percentage: clamped, isCharging: isCharging, isDischarging: isDischarging, ink: ink)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func currentInkColor() -> NSColor {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? .white : .black
    }

    /// `NSAttributedString.draw(at:)` anchors the *bottom of the full line
    /// box* (baseline + descender), not the visual center of the glyphs.
    /// Digits have no descenders, so the ink actually sits in the upper
    /// portion of that box — centering by `size().height` alone leaves text
    /// visibly off-center against icons, which center correctly by their
    /// own image bounds. This computes the box-bottom Y that puts the
    /// *visual* center (baseline + capHeight / 2) at `midY`.
    private static func textOriginY(midY: CGFloat, font: NSFont) -> CGFloat {
        midY + font.descender - font.capHeight / 2
    }

    private static func drawLeftColumn(
        width: CGFloat,
        height: CGFloat,
        margin: CGFloat,
        textIconGap: CGFloat,
        font: NSFont,
        solarText: NSAttributedString,
        solarTextSize: CGSize,
        sunImage: NSImage?,
        sunSize: CGSize,
        gridText: NSAttributedString,
        gridTextSize: CGSize,
        exportImage: NSImage?,
        exportSize: CGSize,
        importImage: NSImage?,
        importSize: CGSize
    ) {
        // Icons sit at the outer edge and numbers sit next to the house on
        // both sides — a sunburst, a pair of triangle arrows, and a percent
        // sign are all different shapes, so anchoring *icons* next to the
        // house made the gap between the house and its neighbors look
        // inconsistent row to row. Numbers are all the same monospaced
        // digit glyphs, so putting them next to the house instead keeps
        // that gap visually uniform on every row.
        let rowStartX = margin
        let topRowMidY = height * 0.73
        let bottomRowMidY = height * 0.24
        let smallGap = textIconGap * 0.6

        sunImage?.draw(in: NSRect(
            x: rowStartX,
            y: topRowMidY - sunSize.height / 2,
            width: sunSize.width,
            height: sunSize.height
        ))
        let solarTextX = rowStartX + sunSize.width + textIconGap
        solarText.draw(at: NSPoint(x: solarTextX, y: textOriginY(midY: topRowMidY, font: font)))

        // Bottom row: export arrow, then import arrow, then the magnitude
        // — arrows outermost (keeping their own tight internal spacing),
        // number innermost next to the house.
        exportImage?.draw(in: NSRect(
            x: rowStartX,
            y: bottomRowMidY - exportSize.height / 2,
            width: exportSize.width,
            height: exportSize.height
        ))
        let importX = rowStartX + exportSize.width + smallGap
        importImage?.draw(in: NSRect(
            x: importX,
            y: bottomRowMidY - importSize.height / 2,
            width: importSize.width,
            height: importSize.height
        ))
        let gridTextX = importX + importSize.width + textIconGap
        gridText.draw(at: NSPoint(x: gridTextX, y: textOriginY(midY: bottomRowMidY, font: font)))
    }

    /// Right-hand column, mirroring `drawLeftColumn`'s icons-outside,
    /// numbers-next-to-the-house layout: charge percentage on top (level
    /// with the solar row) and consumption on the bottom (level with the
    /// grid row).
    private static func drawRightColumn(
        canvasOffsetX: CGFloat,
        height: CGFloat,
        margin: CGFloat,
        textIconGap: CGFloat,
        font: NSFont,
        percentageText: NSAttributedString,
        consumptionImage: NSImage?,
        consumptionSize: CGSize,
        consumptionText: NSAttributedString,
        consumptionTextSize: CGSize
    ) {
        let rowStartX = canvasOffsetX + margin
        let topRowMidY = height * 0.73
        let bottomRowMidY = height * 0.24

        // No separate icon on this side — the percent sign already reads
        // as a unit label, so the number just sits next to the house like
        // every other row.
        percentageText.draw(at: NSPoint(x: rowStartX, y: textOriginY(midY: topRowMidY, font: font)))

        // Bottom row: number next to the house, arrow outermost.
        consumptionText.draw(at: NSPoint(x: rowStartX, y: textOriginY(midY: bottomRowMidY, font: font)))
        let arrowX = rowStartX + consumptionTextSize.width + textIconGap
        consumptionImage?.draw(in: NSRect(
            x: arrowX,
            y: bottomRowMidY - consumptionSize.height / 2,
            width: consumptionSize.width,
            height: consumptionSize.height
        ))
    }

    private static func drawHouse(
        canvasOffsetX: CGFloat,
        size: CGFloat,
        houseWidth: CGFloat,
        percentage: Double,
        isCharging: Bool,
        isDischarging: Bool,
        ink: NSColor
    ) {
        let wallHeight = size * (9.0 / 18.0)
        let roofHeight = size * (7.0 / 18.0)
        let houseOriginX = canvasOffsetX + (size - houseWidth) / 2
        let houseBottom = (size - (wallHeight + roofHeight)) / 2
        let shoulderY = houseBottom + wallHeight
        let houseTop = shoulderY + roofHeight

        let apex = NSPoint(x: canvasOffsetX + size / 2, y: houseTop)
        let rightShoulder = NSPoint(x: houseOriginX + houseWidth, y: shoulderY)
        let bottomRight = NSPoint(x: houseOriginX + houseWidth, y: houseBottom)
        let bottomLeft = NSPoint(x: houseOriginX, y: houseBottom)
        let leftShoulder = NSPoint(x: houseOriginX, y: shoulderY)
        let housePoints = [apex, rightShoulder, bottomRight, bottomLeft, leftShoulder]

        // A round line join only rounds a corner by about half the stroke
        // width — with a thin 1.4pt stroke that's barely a fraction of a
        // point, so the outline still reads as sharp-cornered even with
        // .round joins. Build an actually-rounded path instead, using the
        // same corner radius as the fill so the border visually follows
        // the same silhouette it's tracing rather than pointing past it.
        let cornerRadius = size * (1.1 / 18.0)
        let housePath = roundedPolygonPath(housePoints, radius: cornerRadius)
        housePath.lineJoinStyle = .round
        housePath.lineCapStyle = .round
        housePath.lineWidth = 1.4
        // The border (not the fill) turns green while the battery is
        // discharging — power actively flowing out of the house — the same
        // way the bolt marks charging, but on the outline instead of an
        // overlay so it stays legible at every fill level.
        let borderColor = isDischarging ? NSColor.systemGreen : ink
        borderColor.setStroke()
        housePath.stroke()

        // Fill proportionally across the *whole* silhouette — roof
        // included — not just the wall rectangle. The wall and roof are
        // roughly equal-sized halves of the house, so a gauge confined to
        // the wall alone tops out at "wall full, roof always empty" below
        // 100%, which reads as barely half full even at 97-99%. Filling
        // bottom-up across the full inset height instead means a near-full
        // charge actually looks near-full.
        //
        // Inset uniformly around the perimeter rather than filling
        // housePath itself (border and fill would be the same color in the
        // same place, so the border disappears into a solid blob) and
        // rather than scaling around the center (which pulls in
        // far-from-center points like the roof apex much further than near
        // ones, giving uneven border spacing). A true perimeter inset keeps
        // the same gap on every edge, matching how a full macOS battery
        // icon still shows an even border around its fill.
        let inset: CGFloat = size * (1.6 / 18.0)
        let insetPoints = insetPolygon(housePoints, by: inset)
        // Rounded corners here, not sharp miters — a hard-pointed fill
        // apex inside a softly-rounded outline apex reads as visually
        // broken, so this reuses the same radius as the outline above.
        let insetPath = roundedPolygonPath(insetPoints, radius: cornerRadius)
        let insetTop = insetPoints.map(\.y).max() ?? houseTop
        let insetBottom = insetPoints.map(\.y).min() ?? houseBottom
        let insetHeight = insetTop - insetBottom

        NSGraphicsContext.saveGraphicsState()
        insetPath.addClip()
        let fillHeight = CGFloat(percentage / 100) * insetHeight
        ink.setFill()
        NSRect(x: canvasOffsetX, y: insetBottom, width: size, height: fillHeight).fill()
        NSGraphicsContext.restoreGraphicsState()

        // Tesla "T" logo, always visible (not just while charging), colored
        // by state — drawn solid on top of everything for the same reason
        // the old charging bolt was: a cutout only reads correctly where it
        // overlaps the filled part of the gauge, so it'd fragment at low
        // charge levels.
        let logoColor: NSColor = isCharging ? .systemGreen : (isDischarging ? .systemRed : .systemGray)
        // Dead center of the full silhouette puts the bar's top edge inside
        // the roof's taper, where it's wide enough to touch the sloped
        // sides — nudging down a bit keeps it clear while still reading as
        // centered in the house overall (not just the wall, like before).
        let logoCenterY = houseBottom + (houseTop - houseBottom) * 0.42
        drawTeslaLogo(
            center: NSPoint(x: houseOriginX + houseWidth / 2, y: logoCenterY),
            height: wallHeight * 0.72,
            color: logoColor
        )
    }

    /// A simple geometric "T" — a tapered stem under a lens-shaped crossbar
    /// with pointed ends — standing in for a Tesla logo without tracing the
    /// exact trademarked artwork. Drawn from scratch rather than via SF
    /// Symbols since there's no built-in glyph for it.
    private static func drawTeslaLogo(center: NSPoint, height: CGFloat, color: NSColor) {
        let h = height
        let w = height * 0.42

        func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: center.x + x, y: center.y - h / 2 + y)
        }

        // Stem: tapered, wide where it meets the crossbar, pointed at the
        // bottom.
        let stemTopY: CGFloat = 0.58 * h
        let stemHalfWidth = 0.50 * w
        let stemTopLeft = pt(-stemHalfWidth, stemTopY)
        let stemTopRight = pt(stemHalfWidth, stemTopY)
        let stemBottom = pt(0, 0)

        let stem = NSBezierPath()
        stem.move(to: stemTopLeft)
        stem.curve(
            to: stemBottom,
            controlPoint1: pt(-stemHalfWidth * 0.5, stemTopY * 0.55),
            controlPoint2: pt(-stemHalfWidth * 0.2, stemTopY * 0.2)
        )
        stem.curve(
            to: stemTopRight,
            controlPoint1: pt(stemHalfWidth * 0.2, stemTopY * 0.2),
            controlPoint2: pt(stemHalfWidth * 0.5, stemTopY * 0.55)
        )
        stem.line(to: stemTopLeft)
        stem.close()

        // Crossbar: a fully curved lens with a subtle peak at the top
        // center and a dip at the bottom center — no flat segments, so the
        // two halves read as smoothly swept wings rather than a geometric
        // hexagon. The bottom-center dip is pulled down past stemTopY so
        // it fully overlaps the stem's flat top edge; a shallower dip left
        // a sliver of background visible between the two shapes.
        let barMidY = 0.72 * h
        let barHalfThickness = 0.095 * h
        let barHalfWidth = 1.0 * w

        let leftTip = pt(-barHalfWidth, barMidY)
        let rightTip = pt(barHalfWidth, barMidY)
        let topCenter = pt(0, barMidY + barHalfThickness * 1.2)
        let bottomCenter = pt(0, stemTopY - barHalfThickness * 0.3)

        let bar = NSBezierPath()
        bar.move(to: leftTip)
        bar.curve(
            to: topCenter,
            controlPoint1: pt(-barHalfWidth * 0.72, barMidY + barHalfThickness * 0.55),
            controlPoint2: pt(-barHalfWidth * 0.28, barMidY + barHalfThickness * 1.25)
        )
        bar.curve(
            to: rightTip,
            controlPoint1: pt(barHalfWidth * 0.28, barMidY + barHalfThickness * 1.25),
            controlPoint2: pt(barHalfWidth * 0.72, barMidY + barHalfThickness * 0.55)
        )
        bar.curve(
            to: bottomCenter,
            controlPoint1: pt(barHalfWidth * 0.62, barMidY - barHalfThickness * 0.7),
            controlPoint2: pt(barHalfWidth * 0.18, stemTopY - barHalfThickness * 0.3)
        )
        bar.curve(
            to: leftTip,
            controlPoint1: pt(-barHalfWidth * 0.18, stemTopY - barHalfThickness * 0.3),
            controlPoint2: pt(-barHalfWidth * 0.62, barMidY - barHalfThickness * 0.7)
        )
        bar.close()

        color.setFill()
        stem.fill()
        bar.fill()
    }

    /// Builds a closed polygon path with every corner rounded to `radius`,
    /// using `appendArc(from:to:radius:)` at each vertex. Starting the path
    /// at the midpoint of the last edge (rather than at a vertex) means
    /// `close()` reconnects along a flat edge instead of a sharp corner, so
    /// every vertex — including the wraparound one — ends up rounded.
    private static func roundedPolygonPath(_ points: [NSPoint], radius: CGFloat) -> NSBezierPath {
        let n = points.count
        let last = points[n - 1]
        let first = points[0]
        let path = NSBezierPath()
        path.move(to: NSPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
        for i in 0..<n {
            let corner = points[i]
            let next = points[(i + 1) % n]
            path.appendArc(from: corner, to: next, radius: radius)
        }
        path.close()
        return path
    }

    /// Insets a closed, convex polygon inward by `distance` on every edge,
    /// by offsetting each edge along its inward normal and intersecting
    /// consecutive offset edges — a true uniform-distance inset, unlike
    /// scaling around the centroid. `points` must be in clockwise order
    /// (as used throughout this file, in AppKit's y-up coordinate space).
    private static func insetPolygon(_ points: [NSPoint], by distance: CGFloat) -> [NSPoint] {
        let n = points.count
        let offsetLines: [(origin: NSPoint, direction: NSPoint)] = (0..<n).map { i in
            let a = points[i]
            let b = points[(i + 1) % n]
            let edge = NSPoint(x: b.x - a.x, y: b.y - a.y)
            let length = sqrt(edge.x * edge.x + edge.y * edge.y)
            let direction = NSPoint(x: edge.x / length, y: edge.y / length)
            // Clockwise polygon, y-up: rotating the edge direction -90°
            // (x, y) -> (y, -x) points inward.
            let inwardNormal = NSPoint(x: direction.y, y: -direction.x)
            let origin = NSPoint(x: a.x + inwardNormal.x * distance, y: a.y + inwardNormal.y * distance)
            return (origin, direction)
        }

        return (0..<n).map { i in
            let line1 = offsetLines[(i - 1 + n) % n]
            let line2 = offsetLines[i]
            return lineIntersection(p1: line1.origin, d1: line1.direction, p2: line2.origin, d2: line2.direction)
                ?? points[i]
        }
    }

    private static func lineIntersection(p1: NSPoint, d1: NSPoint, p2: NSPoint, d2: NSPoint) -> NSPoint? {
        let denominator = d1.x * d2.y - d1.y * d2.x
        guard abs(denominator) > 1e-6 else { return nil }
        let t = ((p2.x - p1.x) * d2.y - (p2.y - p1.y) * d2.x) / denominator
        return NSPoint(x: p1.x + t * d1.x, y: p1.y + t * d1.y)
    }
}
