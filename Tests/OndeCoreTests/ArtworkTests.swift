import XCTest
@testable import OndeCore

final class ArtworkTests: XCTestCase {
    func testTwelveRecoveredIdentitiesWithStableMusicMapping() {
        XCTAssertEqual(OndeMotif.allCases.count, 12)
        for (id, motif) in [("ambre", OndeMotif.amber), ("sillage", .laminar), ("meridien", .prism),
                            ("canopee", .canopy), ("filigrane", .filigree), ("confluence", .confluence),
                            ("sanctuaire", .sanctuary), ("lagoon", .tide), ("stillwater", .stillwater),
                            ("hearth", .hearth), ("reverie", .reverie), ("immersion", .bloom)] {
            XCTAssertEqual(EspaceArtworkSelection.motif(choice: "automatic", musicID: id, mode: .focus), motif)
        }
    }
    func testManualChoiceAndObsoleteChoiceFallback() {
        XCTAssertEqual(EspaceArtworkSelection.motif(choice:"bloom",musicID:"ambre",mode:.focus),.bloom)
        for value in ["automatic", "", "obsolete", "../../foo"] {
            XCTAssertEqual(EspaceArtworkSelection.motif(choice:value,musicID:"ambre",mode:.focus),.amber)
        }
    }
    func testEveryMotifMovesWithinOneSecond() {
        for motif in OndeMotif.allCases {
            let a = OndeMotionGeometry.strokes(motif,time:0,intensity:0.85).flatMap(\.points)
            let b = OndeMotionGeometry.strokes(motif,time:1,intensity:0.85).flatMap(\.points)
            let displacement = zip(a,b).map { hypot($0.x-$1.x,$0.y-$1.y) }.max()!
            XCTAssertGreaterThan(displacement, 0.007, motif.rawValue)
        }
    }
    func testBankIsBoundedAcrossCompleteCycles() {
        for motif in OndeMotif.allCases {
            for quality in [OndeMotionQuality.economy,.balanced] {
                for phase in 0..<12 {
                    let strokes = OndeMotionGeometry.strokes(motif,time:Double(phase)*motif.period/12,quality:quality,intensity:0.85)
                    XCTAssertEqual(strokes.count,quality.lines)
                    for p in strokes.flatMap(\.points) {
                        XCTAssertTrue(p.x.isFinite && p.y.isFinite)
                        XCTAssertTrue((-0.05...1.05).contains(p.x) && (-0.05...1.05).contains(p.y), motif.rawValue)
                    }
                }
            }
        }
    }
    func testLoopPositionAndVelocityAreContinuous() {
        let e = 0.0001
        for motif in OndeMotif.allCases {
            let a = OndeMotionGeometry.strokes(motif,time:0,quality:.economy).flatMap(\.points)
            let end = OndeMotionGeometry.strokes(motif,time:motif.period,quality:.economy).flatMap(\.points)
            let l = OndeMotionGeometry.strokes(motif,time:motif.period-e,quality:.economy).flatMap(\.points)
            let r = OndeMotionGeometry.strokes(motif,time:e,quality:.economy).flatMap(\.points)
            for i in a.indices {
                XCTAssertEqual(a[i].x,end[i].x,accuracy:1e-9); XCTAssertEqual(a[i].y,end[i].y,accuracy:1e-9)
                XCTAssertEqual((a[i].x-l[i].x)/e,(r[i].x-a[i].x)/e,accuracy:1e-4)
                XCTAssertEqual((a[i].y-l[i].y)/e,(r[i].y-a[i].y)/e,accuracy:1e-4)
            }
        }
    }
    func testInvalidTimeAndIntensityDoNotPoisonTheRenderer() {
        for motif in OndeMotif.allCases {
            for n in [Double.nan,Double.infinity,-Double.infinity] {
                let pts = OndeMotionGeometry.strokes(motif,time:n,intensity:n).flatMap(\.points)
                XCTAssertTrue(pts.allSatisfy { $0.x.isFinite && $0.y.isFinite })
            }
        }
    }
    func testVisibleInactiveWindowIsEconomicalNotFrozen() {
        XCTAssertEqual(EspaceMotionPolicy.fps(visible:true,active:false,enabled:true,reduced:false,lowPower:false,hot:false),12)
        XCTAssertEqual(EspaceMotionPolicy.fps(visible:false,active:true,enabled:true,reduced:false,lowPower:false,hot:false),0)
    }
    func testRenderBudgetIsBoundedAndHasNoVideoDependency() {
        XCTAssertEqual(OndeMotionQuality.balanced.lines * (OndeMotionQuality.balanced.samples + 1),3616)
        XCTAssertEqual(OndeMotionQuality.economy.lines * (OndeMotionQuality.economy.samples + 1),1620)
        XCTAssertEqual(OndeMotionQuality.balanced.fps,24)
        XCTAssertEqual(OndeMotionQuality.economy.fps,12)
    }
}
