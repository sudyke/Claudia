import AppKit

// Pure function: ServiceStatus → NSImage for the menu bar.
//
// Design:
//   .up      → Claude Code logo, native orange
//   .down    → Claude Code logo, labelColor (dark in light mode, light in dark mode — visible in both)
//   .unknown → exclamationmark.triangle.fill, secondary grey (distinct shape signals "error")
//
// .up vs .down differ by color alone (same logo silhouette), which the user requested.
// .unknown uses a distinct shape so the error case is unambiguous.
enum StatusIcon {
    private static let iconSize = NSSize(width: 18, height: 18)

    static func image(for status: ServiceStatus) -> NSImage {
        switch status {
        case .up:
            return tintedClaudeIcon(.claudeOrange, accessibility: "Claudia: all services up")
        case .down:
            return tintedClaudeIcon(.labelColor, accessibility: "Claudia: a service is down")
        case .unknown:
            return exclamationIcon()
        }
    }

    private static func tintedClaudeIcon(_ color: NSColor, accessibility: String) -> NSImage {
        guard let source = NSImage(named: "ClaudeCode") else {
            return NSImage()
        }
        // Re-tint via sourceAtop: replaces RGB inside the silhouette while preserving alpha.
        let tinted = NSImage(size: iconSize, flipped: false) { rect in
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.accessibilityDescription = accessibility
        // CRITICAL: never set isTemplate = true here — menu bar would discard our color.
        tinted.isTemplate = false
        return tinted
    }

    private static func exclamationIcon() -> NSImage {
        let symbol = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                             accessibilityDescription: "Claudia: status unknown") ?? NSImage()
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let paletteConfig = NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor])
        let tinted = symbol.withSymbolConfiguration(sizeConfig.applying(paletteConfig)) ?? symbol
        tinted.isTemplate = false
        return tinted
    }
}

private extension NSColor {
    // Claude brand orange — sampled from the provided SVG (#D97757).
    static let claudeOrange = NSColor(
        srgbRed: 0xD9 / 255.0,
        green:   0x77 / 255.0,
        blue:    0x57 / 255.0,
        alpha:   1.0
    )
}
