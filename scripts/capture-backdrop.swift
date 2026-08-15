import AppKit

// A full-screen backdrop for screenshots, so the panel is photographed against a
// controlled surface instead of whatever happens to be on the desk.
//
// This is not cosmetic. The panel's background is NSGlassEffectView, which samples
// what is behind it, so every screenshot taken on a working desktop has the
// contents of other windows legible through the glass — in the first batch that
// included a private document. A backdrop is also the only way to get the same
// shot twice: the glass renders differently over a light window than a dark one.
//
// Sits above ordinary windows and below the panel, and covers every screen.
// Run it, take the screenshots, then kill it.
/// AppKit moves borderless windows to keep them "on screen", and on a display
/// arranged below the primary one — where the frame origin is negative — that
/// nudge pushed the backdrop a full screen height past its display, leaving the
/// desk visible behind the panel on exactly the screen being photographed.
/// Overriding the constraint is the documented way to place a window yourself.
final class UnconstrainedWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

final class BackdropController {
    private var windows: [NSWindow] = []

    func show() {
        for screen in NSScreen.screens {
            let window = UnconstrainedWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = true
            // Above normal windows, below the status-item panel we are photographing.
            window.level = NSWindow.Level(
                rawValue: Int(CGWindowLevelForKey(.floatingWindow)) - 1)
            // Present on every Space, so switching desktops does not reveal the desk.
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.contentView = BackdropView(frame: .zero)
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }
}

/// A generated wallpaper, in the website's own palette — kami's warm neutrals
/// (Olive #504e49 through Dark Warm #3d3d3a), not the cool blue-violet this used to
/// be. A screenshot is a plate on a page, and a cool-blue plate on a parchment page
/// reads as borrowed from somewhere else.
///
/// Generated rather than photographed, and generated rather than using whatever the
/// machine's own wallpaper happens to be: the screenshots go on a public site, and a
/// personal desktop picture is not something to publish by accident. Drawing it also
/// means the same shot can be taken again in a year and look identical.
///
/// A flat gradient reads as a CSS background rather than a desk. The soft off-centre
/// glow and the vignette are what make it read as a picture — which is the point of
/// including the desktop at all.
final class BackdropView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let base = NSGradient(colors: [
            NSColor(calibratedRed: 0.314, green: 0.306, blue: 0.286, alpha: 1),  // #504e49
            NSColor(calibratedRed: 0.267, green: 0.263, blue: 0.251, alpha: 1),
            NSColor(calibratedRed: 0.212, green: 0.212, blue: 0.200, alpha: 1),
        ])
        base?.draw(in: bounds, angle: 35)

        // A warm light source high on the RIGHT. Status items live in the top-right
        // corner, so that is the part of the desktop a panel screenshot actually
        // contains — a glow placed on the left was cropped out of every shot and the
        // wallpaper came back looking like a flat fill.
        let glow = NSGradient(colors: [
            NSColor(calibratedRed: 0.78, green: 0.68, blue: 0.48, alpha: 0.52),
            NSColor(calibratedRed: 0.56, green: 0.49, blue: 0.38, alpha: 0.22),
            NSColor(calibratedRed: 0.30, green: 0.29, blue: 0.27, alpha: 0.0),
        ])
        let centre = NSPoint(x: bounds.width * 0.74, y: bounds.height * 0.86)
        glow?.draw(fromCenter: centre, radius: 0,
                   toCenter: centre, radius: bounds.width * 0.75,
                   options: [])

        // And a vignette, so the corners settle and the panel sits in the light.
        let vignette = NSGradient(colors: [
            NSColor(calibratedWhite: 0, alpha: 0.0),
            NSColor(calibratedWhite: 0, alpha: 0.06),
            NSColor(calibratedWhite: 0, alpha: 0.42),
        ])
        let mid = NSPoint(x: bounds.width * 0.6, y: bounds.height * 0.55)
        vignette?.draw(fromCenter: mid, radius: 0,
                       toCenter: mid, radius: max(bounds.width, bounds.height) * 0.66,
                       options: [])
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = BackdropController()
controller.show()
app.run()
