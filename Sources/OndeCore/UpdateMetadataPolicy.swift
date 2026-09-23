import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A small metadata check must not inherit the two-hour archive-transfer budget.
public enum UpdateMetadataPolicy {
    public static let requestTimeout: TimeInterval = 15
    public static let resourceTimeout: TimeInterval = 30
    public static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        #if os(macOS)
        configuration.waitsForConnectivity = false
        #endif
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        return configuration
    }
    public static func message(for error: Error) -> String {
        guard let error = error as? URLError else { return error.localizedDescription }
        switch error.code {
        case .notConnectedToInternet:
            return "You are offline. Listening still works; reconnect and check again."
        case .timedOut:
            return "The update check timed out. Try again when your connection is stable."
        case .networkConnectionLost:
            return "The connection was interrupted. Try checking for updates again."
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return "GitHub could not be reached. Listening still works; try checking again later."
        case .cancelled:
            return "The update check was cancelled."
        default:
            return error.localizedDescription
        }
    }
}
