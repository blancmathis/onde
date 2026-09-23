import Foundation
import XCTest
@testable import OndeCore

final class ControlRequestValidationTests: XCTestCase {
    private func parsed(_ text: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }
    func testFoundationNumericBridgeDoesNotCountAsABoolean() throws {
        let request = try parsed(#"{"command":"mode","mode":"focus","play":1}"#)
        XCTAssertEqual(request["play"] as? Bool, true) // Demonstrates the former guard's failure.
        XCTAssertThrowsError(try ControlRequestValidation.validate(request))
    }
    func testEveryBooleanControlRejectsNumbersStringsNullAndContainers() throws {
        let controls: [(String, String, String?)] = [
            ("mode", "play", nil), ("mode", "reset", nil), ("music.select", "play", nil),
            ("mix.load", "play", nil), ("generate.play", "reset", nil), ("sound", "enabled", nil),
            ("ui", "quiet", nil), ("ui", "show", nil), ("updates.automatic", "enabled", nil),
            ("settings", "value", "chimesEnabled"), ("settings", "value", "preventSleep"),
            ("settings", "value", "reducedMotion")]
        for (command, field, key) in controls {
            for value in ["0", "1", "1.0", "2", "\"true\"", "\"false\"", "null", "[]", "{}"] {
                let extra = key.map { ",\"key\":\"\($0)\"" } ?? ""
                let request = try parsed("{\"command\":\"\(command)\",\"\(field)\":\(value)\(extra)}")
                XCTAssertThrowsError(try ControlRequestValidation.validate(request), "\(command).\(field)=\(value)") {
                    XCTAssertEqual(($0 as? OndeError)?.code, "invalid_argument")
                }
            }
            for value in ["true", "false"] {
                var request: [String: Any] = ["command": command]
                if let key { request["key"] = key }
                request[field] = try JSONSerialization.jsonObject(with: Data(value.utf8), options: [.fragmentsAllowed])
                XCTAssertNoThrow(try ControlRequestValidation.validate(request))
            }
        }
    }
    func testOmittedOptionalFieldsKeepTheirExistingDefaults() {
        for command in ["mode", "sound", "music.select", "mix.load", "generate.play", "ui"] {
            XCTAssertNoThrow(try ControlRequestValidation.validate(["command": command]))
        }
    }
    func testMalformedSecondaryUIOptionRejectsTheWholeRequest() throws {
        let request = try parsed(#"{"command":"ui","page":"settings","quiet":1}"#)
        XCTAssertThrowsError(try ControlRequestValidation.validate(request))
    }
    func testMixedSoundEditIsRejectedBeforeTheValidVolumeCanApply() throws {
        let request = try parsed(#"{"command":"sound","id":"rain","volume":0.2,"enabled":"false"}"#)
        XCTAssertThrowsError(try ControlRequestValidation.validate(request))
    }
    func testMarkerArraysRejectBooleanElementsAndNonArrays() throws {
        for value in ["[true]", "[1,false,3]", "[\"10\"]", "null", "{}", "3"] {
            XCTAssertThrowsError(try ControlRequestValidation.validate(parsed("{\"command\":\"timer.markers\",\"seconds\":\(value)}")))
        }
        for value in ["[]", "[1,2.5,600]"] {
            XCTAssertNoThrow(try ControlRequestValidation.validate(parsed("{\"command\":\"timer.markers\",\"seconds\":\(value)}")))
        }
    }
    func testNumbersOnUnrelatedCommandsRemainNumbers() throws {
        XCTAssertNoThrow(try ControlRequestValidation.validate(parsed(#"{"command":"settings","key":"chimeVolume","value":0.5}"#)))
        XCTAssertNoThrow(try ControlRequestValidation.validate(parsed(#"{"command":"volume","value":0}"#)))
    }
    func testUIPageRequiresAStringWithoutInterpretingUnknownCommands() throws {
        XCTAssertThrowsError(try ControlRequestValidation.validate(parsed(#"{"command":"ui","page":42}"#)))
        XCTAssertNoThrow(try ControlRequestValidation.validate(["command": "unknown", "enabled": 1]))
    }
}
