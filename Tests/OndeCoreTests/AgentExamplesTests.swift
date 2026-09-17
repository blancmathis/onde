import XCTest
@testable import OndeCore

final class AgentExamplesTests: XCTestCase {
    func testExamplesCoverThePrimaryListeningActions() {
        for command in ["onde music list focus", "onde music list relax", "onde music defaults",
                        "onde music default meditation rive", "onde music play velours --mode meditation",
                        "onde background white 0.15", "onde background off", "onde generate transition 10"] {
            XCTAssertTrue(AgentExamples.commands.contains(command))
        }
    }
    func testMultiwordNamesCopyAsValidShellQuotes() {
        XCTAssertTrue(AgentExamples.commands.contains("onde mix save 'My focus mix'"))
        XCTAssertTrue(AgentExamples.commands.contains("onde mix load 'My focus mix'"))
        XCTAssertFalse(AgentExamples.commands.contains("\\\""))
    }
}
