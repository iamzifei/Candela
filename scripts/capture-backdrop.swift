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

/// A soft diagonal gradient in the website's own palette — kami's warm neutrals
/// (Olive #504e49 through Dark Warm #3d3d3a), not the cool blue-violet this used to
/// be. A screenshot is a plate on a page, and a cool-blue plate on a parchment page
/// reads as borrowed from somewhere else.
///
/// Mid-tone rather than black or white: the panel is glass and picks up whatever it
/// sits on, so a flat extreme makes it look washed out or silhouetted instead of
/// like the material it is. Dark enough that a light panel still separates from it.
final class BackdropView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.314, green: 0.306, blue: 0.286, alpha: 1),  // #504e49
            NSColor(calibratedRed: 0.267, green: 0.263, blue: 0.251, alpha: 1),
            NSColor(calibratedRed: 0.239, green: 0.239, blue: 0.227, alpha: 1),  // #3d3d3a
        ])
        gradient?.draw(in: bounds, angle: 35)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = BackdropController()
controller.show()
app.run()
