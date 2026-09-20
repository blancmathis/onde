import XCTest
@testable import OndeCore

final class UpdateTransferPolicyTests: XCTestCase {
    func testTimeoutBudgetAllowsLargeDownloadsOnSlowConnections() {
        XCTAssertGreaterThanOrEqual(UpdateTransferPolicy.requestTimeout, 60)
        XCTAssertGreaterThanOrEqual(UpdateTransferPolicy.resourceTimeout, 3_600)
        XCTAssertGreaterThan(UpdateTransferPolicy.resourceTimeout, UpdateTransferPolicy.requestTimeout)
    }

    func testProgressUsesPublishedArchiveSizeAndClamps() {
        XCTAssertNil(UpdateTransferPolicy.progress(received: 10, expected: 0))
        XCTAssertEqual(UpdateTransferPolicy.progress(received: -10, expected: 100), 0)
        XCTAssertEqual(UpdateTransferPolicy.progress(received: 25, expected: 100), 0.25)
        XCTAssertEqual(UpdateTransferPolicy.progress(received: 150, expected: 100), 1)
    }

    func testNetworkErrorsReceiveActionableMessages() {
        XCTAssertTrue(UpdateTransferPolicy.message(for: URLError(.timedOut)).contains("browser"))
        XCTAssertTrue(UpdateTransferPolicy.message(for: URLError(.notConnectedToInternet)).contains("offline"))
        XCTAssertTrue(UpdateTransferPolicy.message(for: URLError(.networkConnectionLost)).contains("interrupted"))
    }
}
