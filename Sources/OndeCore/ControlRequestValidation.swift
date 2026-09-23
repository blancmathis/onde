import Foundation
import CoreFoundation

/// Reject malformed optional control values before any command can mutate state.
/// Foundation bridges JSON 0/1 to Bool, so `as? Bool` is not a JSON type check.
public enum ControlRequestValidation {
    public static func validate(_ request: [String: Any]) throws {
        guard let command = request["command"] as? String else { return }
        let fields: [String]
        switch command {
        case "mode": fields = ["play", "reset"]
        case "music.list", "music.select", "music.default", "mix.load": fields = ["play"]
        case "generate.play": fields = ["reset"]
        case "sound", "updates.automatic": fields = ["enabled"]
        case "ui": fields = ["quiet", "show"]
        case "settings" where ["chimesEnabled", "preventSleep", "reducedMotion"].contains(request["key"] as? String ?? ""):
            fields = ["value"]
        default: fields = []
        }
        for field in fields where request.keys.contains(field) {
            guard let value = request[field] as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else {
                throw OndeError("invalid_argument", "\(field) must be a JSON boolean, not a number or string.")
            }
        }
        if command == "timer.markers", let raw = request["seconds"] {
            guard let values = raw as? [Any], values.allSatisfy({ value in
                guard let number = value as? NSNumber else { return false }
                return CFGetTypeID(number) != CFBooleanGetTypeID() && number.doubleValue.isFinite
            }) else {
                throw OndeError("invalid_argument", "seconds must be an array of finite numbers, not booleans.")
            }
        }
        if command == "ui", let page = request["page"], !(page is String) {
            throw OndeError("invalid_argument", "page must be a string.")
        }
    }
}
