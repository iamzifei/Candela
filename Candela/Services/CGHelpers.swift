import Foundation
import CoreGraphics
import Synchronization

/// `CGDisplayMode` is an immutable snapshot of one mode a display supports: CoreGraphics
/// hands it out from `CGDisplayCopyAllDisplayModes` / `CGDisplayCopyDisplayMode` and
/// exposes only getters, with no API that mutates one. It is therefore safe to read from
/// any thread, but the C header carries no `Sendable` annotation, so Swift 6 refuses to
/// let a mode cross an isolation boundary — which every resolution change does, since the
/// modes are picked on the main actor and applied on a background queue.
///
/// `@unchecked` because the guarantee comes from CoreGraphics' contract rather than from
/// anything the compiler can verify. Declared here, once, rather than sprinkling `sending`
/// across call sites: `sending` cannot work for a mode picked out of a still-live array,
/// which is how every call site obtains one.
extension CGDisplayMode: @retroactive @unchecked Sendable {}

/// Shared utilities for wrapping blocking CoreGraphics calls.
enum CGHelpers {

    /// Runs a blocking operation on a background thread with a timeout.
    ///
    /// The operation is dispatched to a `.userInitiated` global queue. If it
    /// completes within `seconds`, its return value is forwarded. If the
    /// deadline fires first, `fallback` is returned instead.
    ///
    /// This is useful for any CoreGraphics / WindowServer IPC call that can
    /// hang indefinitely (e.g. `CGCompleteDisplayConfiguration`,
    /// `CGVirtualDisplay.apply(_:)`).
    ///
    /// - Parameters:
    ///   - seconds:   Maximum time to wait before returning `fallback`.
    ///   - fallback:  Value returned on timeout.
    ///   - operation: The blocking work to execute off-thread.
    /// - Returns: The operation's result, or `fallback` on timeout.
    static func runWithTimeout<T: Sendable>(
        seconds: Double,
        fallback: T,
        operation: @escaping @Sendable () -> T
    ) async -> T {
        await withCheckedContinuation { cont in
            // Whichever of the two branches gets here first resumes the continuation;
            // the loser must not, because resuming twice traps. `Mutex` rather than the
            // NSLock-around-a-captured-var this used to be: the invariant is identical,
            // but a mutex-guarded value is one the compiler can verify, so it holds up
            // under strict concurrency instead of only in review.
            let didResume = Mutex(false)
            let claimResume: @Sendable () -> Bool = {
                didResume.withLock { claimed in
                    if claimed { return false }
                    claimed = true
                    return true
                }
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let result = operation()
                if claimResume() { cont.resume(returning: result) }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                if claimResume() { cont.resume(returning: fallback) }
            }
        }
    }
}
