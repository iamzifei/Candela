import XCTest
import CoreGraphics

/// The navigation model behind the panel's pages.
///
/// Worth testing on its own because the failure it guards against is one the user
/// cannot recover from: a page whose back arrow leads nowhere, or a page for a
/// display that has been unplugged, is a panel with no way out — and the panel is
/// the whole app.
final class PanelRouteTests: XCTestCase {

    private let display: CGDirectDisplayID = 3
    private let other: CGDirectDisplayID = 2

    // MARK: - Going back

    func testRootHasNoParent() {
        XCTAssertNil(PanelRoute.root.parent)
    }

    func testDisplayPageGoesBackToRoot() {
        XCTAssertEqual(PanelRoute.display(display).parent, .root)
    }

    func testResolutionListGoesBackToItsDisplay() {
        // Not to root: the list was reached from a display's page, and landing back
        // at root would lose the place.
        XCTAssertEqual(PanelRoute.allResolutions(display).parent, .display(display))
    }

    func testEveryPageReachesRootByGoingBack() {
        for start in [PanelRoute.root, .display(display), .allResolutions(display)] {
            var route = start
            var hops = 0
            while let parent = route.parent {
                route = parent
                hops += 1
                XCTAssertLessThan(hops, 10, "\(start) does not terminate at root")
            }
            XCTAssertEqual(route, .root)
        }
    }

    // MARK: - Which display a page belongs to

    func testRootBelongsToNoDisplay() {
        XCTAssertNil(PanelRoute.root.displayID)
    }

    func testDisplayPagesCarryTheirDisplay() {
        XCTAssertEqual(PanelRoute.display(display).displayID, display)
        XCTAssertEqual(PanelRoute.allResolutions(display).displayID, display)
    }

    func testPagesForDifferentDisplaysAreDifferentPages() {
        XCTAssertNotEqual(PanelRoute.display(display), .display(other))
        XCTAssertNotEqual(PanelRoute.allResolutions(display), .display(display))
    }
}
