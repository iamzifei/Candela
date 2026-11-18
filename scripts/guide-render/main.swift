// Renders the welcome guide's screenshots from Candela's real SwiftUI views, offscreen,
// with demo data. Built by build.sh against a patched copy of the app sources (patch.py).
//
// No screen capture and no input synthesis: each page is an NSHostingView drawn into a
// bitmap with cacheDisplay. The window is never ordered onto the screen.
//
// Usage: harness <output-dir> <language-code>   (the language itself is forced by the
// -AppleLanguages launch argument build.sh passes, which is what the app's own strings follow)
import SwiftUI
import AppKit

/// Which demo displays answer DDC (the rest show the Software badge). Read by the patched
/// BrightnessSliderView instead of probing real hardware.
enum DemoData {
    static var ddc: [CGDirectDisplayID: Bool] = [:]
}

@MainActor
enum Render {
    static let outDir = CommandLine.arguments[1]
    static let lang = CommandLine.arguments[2]

    // Fake display IDs, far above any real CGDirectDisplayID.
    static let vxID: CGDirectDisplayID = 90_001
    static let builtinID: CGDirectDisplayID = 90_002
    static let m28ID: CGDirectDisplayID = 90_003

    static func mode(_ id: Int32, _ w: Int, _ h: Int, hz: Double, hidpi: Bool = false, native: Bool = false) -> DisplayMode {
        DisplayMode(id: id, width: w, height: h, pixelWidth: hidpi ? w * 2 : w, pixelHeight: hidpi ? h * 2 : h,
                    refreshRate: hz, isHiDPI: hidpi, isNative: native)
    }

    static func display(_ id: CGDirectDisplayID, _ name: String, _ w: Int, _ h: Int, builtin: Bool = false,
                        brightness: Double, ddc: Bool, volume: Double? = nil, modes: [DisplayMode] = []) -> DisplayInfo {
        let d = DisplayInfo(displayID: id)
        d.name = name
        d.isBuiltin = builtin
        d.isOnline = true
        d.isEnabled = true
        d.pixelWidth = w
        d.pixelHeight = h
        d.brightness = brightness
        d.maxBrightness = 100
        if let volume { d.volume = volume; d.volumeSupported = true }
        d.availableModes = modes
        d.currentDisplayMode = modes.first(where: { $0.width == w && $0.height == h && !$0.isHiDPI })
            ?? mode(Int32(id), w, h, hz: 60, native: true)
        DemoData.ddc[id] = ddc
        return d
    }

    static func panel<V: View>(_ content: V) -> some View {
        content
            .frame(width: 308)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.19, green: 0.18, blue: 0.165)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
            .padding(16)
            .background(LinearGradient(colors: [Color(red: 0.43, green: 0.40, blue: 0.34),
                                                Color(red: 0.30, green: 0.28, blue: 0.24)],
                                       startPoint: .top, endPoint: .bottom))
            .environment(\.colorScheme, .dark)
            .environment(\.controlActiveState, .key)
    }

    static func write<V: View>(_ page: Int, _ view: V) {
        let host = NSHostingView(rootView: view)
        host.safeAreaRegions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: NSSize(width: 340, height: 900)),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        // Let .task / .onAppear run (slider positions are set there) and layout settle.
        for _ in 0..<6 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        let size = host.fittingSize
        window.setContentSize(size)
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("no bitmap") }
        host.cacheDisplay(in: host.bounds, to: rep)
        let png = rep.representation(using: .png, properties: [:])!
        try! png.write(to: URL(fileURLWithPath: "\(outDir)/guide-\(page)-\(lang).png"))
    }

    static func run() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)

        // Demo data. Same cast as the marketing shots.
        let vxModes = [mode(1, 1920, 1080, hz: 75, native: true), mode(2, 1920, 1080, hz: 60, native: true),
                       mode(3, 1280, 720, hz: 60, hidpi: true), mode(4, 1600, 900, hz: 60)]
        let vx = display(vxID, "VX1622-4K", 1920, 1080, brightness: 82, ddc: true, volume: 12, modes: vxModes)
        vx.currentDisplayMode = vxModes[1]
        let builtin = display(builtinID, "Built-in Display", 1800, 1169, builtin: true, brightness: 86, ddc: false)
        let m28 = display(m28ID, "M28U", 2560, 1440, brightness: 50, ddc: false)
        builtin.isMain = true
        let displays = [vx, builtin, m28]

        let dm = DisplayManager()
        dm.displays = displays
        let state = PanelSectionState()

        let settings = SettingsService.shared
        settings.showCombinedBrightness = true
        settings.showVolumeSliders = true
        settings.brightnessKeyTarget = .allDisplays
        AutoBrightnessService.shared.isEnabled = true
        let effects = CoreBrightnessService.shared
        effects.nightShiftAvailable = true
        effects.trueToneAvailable = true
        effects.darkModeEnabled = true
        effects.nightShiftEnabled = false
        effects.trueToneEnabled = true

        // Page 1: the displays and the combined slider.
        write(1, panel(VStack(spacing: 0) {
            ForEach(displays) { d in
                PanelCard { DisplayHeaderBlock(display: d, isFirst: d.displayID == vxID, state: state) }
            }
            PanelCard { CombinedBrightnessView(displays: displays) }
        }.environmentObject(dm)))

        // Page 2: combined, quick toggles, presets, Tools / Settings, Quit.
        write(2, panel(VStack(spacing: 0) {
            PanelCard { CombinedBrightnessView(displays: displays) }
            PanelCard { ScreenEffectsView() }
            PanelCard(title: "Presets") { PresetListView() }
            PanelCard {
                PanelPushRow(icon: "wrench.and.screwdriver.fill", label: String(localized: "Tools")) {}
                PanelPushRow(icon: "gearshape.fill", label: String(localized: "Settings")) {}
            }
            PanelFooterBlock()
        }.environmentObject(dm)))

        // Page 3: one display's page.
        let controller = DisplayModeController(display: vx, displayManager: dm)
        write(3, panel(VStack(spacing: 0) {
            PanelBackHeader(title: vx.name) {}
            PanelGroupGap()
            ResolutionHeadBlock(controller: controller, state: state).padding(.leading, 4)
            RefreshHeadBlock(controller: controller, state: state).padding(.leading, 4)
            ModeTailBlock(controller: controller).padding(.leading, 4)
            PanelGroupGap()
            PanelCard(title: "Combined brightness") { CombinedFloorView(display: vx) }
        }.environmentObject(dm)))

        // Page 4: Tools.
        write(4, panel(VStack(spacing: 0) {
            PanelBackHeader(title: PanelRoute.tools.title ?? "") {}
            KeepAwakeRow()
            PanelPushRow(icon: "display.2", label: String(localized: "Virtual Displays")) {}
            PanelPushRow(icon: "ipad.landscape", label: String(localized: "iPad Display")) {}
            PanelPushRow(icon: "rectangle.3.offgrid", label: String(localized: "Arrange Displays")) {}
            PanelFooterBlock()
        }.environmentObject(dm)))

        // Page 5: Settings.
        write(5, panel(VStack(spacing: 0) {
            PanelBackHeader(title: PanelRoute.settings.title ?? "") {}
            SettingsView()
            PanelFooterBlock()
        }.environmentObject(dm)))
    }
}

MainActor.assumeIsolated { Render.run() }
