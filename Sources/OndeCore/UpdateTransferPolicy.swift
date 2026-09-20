import Foundation

public enum UpdateTransferPolicy {
    public static let requestTimeout: TimeInterval = 60
    public static let resourceTimeout: TimeInterval = 7_200
    public static let progressInterval: TimeInterval = 0.2

    public static func progress(received: Int64, expected: Int64) -> Double? {
        guard expected > 0 else { return nil }
        return min(1, max(0, Double(received) / Double(expected)))
    }

    public static func message(for error: Error) -> String {
        guard let urlError = error as? URLError else { return error.localizedDescription }
        switch urlError.code {
        case .timedOut:
            return "The download timed out. Try again, or download it in your browser."
        case .notConnectedToInternet:
            return "You appear to be offline. Reconnect and try the download again."
        case .networkConnectionLost:
            return "The network connection was interrupted. Try the download again."
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return "GitHub could not be reached. Try again, or download the release in your browser."
        case .cancelled:
            return "The download was cancelled."
        default:
            return urlError.localizedDescription
        }
    }
}
