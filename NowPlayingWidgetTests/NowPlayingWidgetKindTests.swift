import XCTest

final class NowPlayingWidgetKindTests: XCTestCase {
    func testKindUsesCurrentCacheBustingIdentity() {
        XCTAssertEqual(NowPlayingWidgetKind.identifier, "NowPlayingWidget.v8")
    }
}
