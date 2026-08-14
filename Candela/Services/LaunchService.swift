import Foundation
import ServiceManagement

/// Manages "Launch at Login" using SMAppService.
@MainActor
final class LaunchService: @unchecked Sendable {
    static let shared = LaunchService()
    private init() {}

    // MARK: - State

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: - Enable / Disable

    @discardableResult
    func enable() -> Bool {
        do {
            try SMAppService.mainApp.register()
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func disable() -> Bool {
        do {
            try SMAppService.mainApp.unregister()
            return true
        } catch {
            return false
        }
    }

    /// Toggle and return the new state.
    @discardableResult
    func toggle() -> Bool {
        if isEnabled {
            disable()
            return false
        } else {
            enable()
            return true
        }
    }
}
