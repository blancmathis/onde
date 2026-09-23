import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import OndeCore

final class UpdateMetadataPolicyTests: XCTestCase {
    func testSmallMetadataChecksHaveABoundedIndependentBudget() {
        let config = UpdateMetadataPolicy.configuration()
        XCTAssertEqual(config.timeoutIntervalForRequest, 15)
        XCTAssertEqual(config.timeoutIntervalForResource, 30)
        XCTAssertLessThan(config.timeoutIntervalForResource, UpdateTransferPolicy.resourceTimeout)
        #if os(macOS)
        XCTAssertFalse(config.waitsForConnectivity)
        #endif
    }
    func testChecksDoNotPersistCookiesCredentialsOrResponses() {
        let config = UpdateMetadataPolicy.configuration()
        XCTAssertFalse(config.httpShouldSetCookies)
        XCTAssertNil(config.httpCookieStorage)
        XCTAssertNil(config.urlCredentialStorage)
        XCTAssertNil(config.urlCache)
    }
    func testMetadataErrorsExplainRecoveryWithoutCallingItADownload() {
        for code: URLError.Code in [.notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost] {
            let text = UpdateMetadataPolicy.message(for: URLError(code)).lowercased()
            XCTAssertFalse(text.contains("download"))
            XCTAssertTrue(text.contains("again"))
        }
        XCTAssertTrue(UpdateMetadataPolicy.message(for: URLError(.notConnectedToInternet)).contains("Listening still works"))
    }
}
