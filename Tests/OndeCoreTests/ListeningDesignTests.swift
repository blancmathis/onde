import XCTest
@testable import OndeCore

final class ListeningDesignTests: XCTestCase {
    func testSearchIgnoresCaseAccentsAndWhitespace() {
        XCTAssertTrue(ListeningDesign.matches(query: "  PIANÓ  warm  ", title: "Amber", id: "ambre", description: "Warm electric keys & piano"))
        XCTAssertTrue(ListeningDesign.matches(query: "", title: "Amber", id: "ambre", description: ""))
        XCTAssertFalse(ListeningDesign.matches(query: "piano rain", title: "Amber", id: "ambre", description: "Warm piano"))
    }
    func testSearchFindsStableIDAsWellAsEnglishName() {
        XCTAssertTrue(ListeningDesign.matches(query: "canopee", title: "Canopy", id: "canopee", description: "Wood tones"))
        XCTAssertTrue(ListeningDesign.matches(query: "canopy", title: "Canopy", id: "canopee", description: "Wood tones"))
    }
    func testDefaultRanksFirstWithoutExcludingLegacyMusic() {
        XCTAssertEqual(ListeningDesign.rank(id: "elan", defaultID: "elan"), -1)
        XCTAssertGreaterThan(ListeningDesign.rank(id: "elan", defaultID: "sillage"), ListeningDesign.rank(id: "ambre", defaultID: "sillage"))
        XCTAssertEqual(ListeningDesign.featured.count, Set(ListeningDesign.featured).count)
    }
    func testSeedIsStableFiniteAndInRange() {
        for id in ["", "ambre", "sanctuaire", "a personal import", "Été", String(repeating: "x", count: 300)] {
            let value = ListeningDesign.seed(id)
            XCTAssertTrue((0..<1).contains(value)); XCTAssertEqual(value, ListeningDesign.seed(id))
        }
        XCTAssertNotEqual(ListeningDesign.seed("ambre"), ListeningDesign.seed("sillage"))
    }
    func testGeometryIsFiniteAndFitsTheSurface() {
        for t in stride(from: 0.0, through: 80.0, by: 5) {
            for s in [0.0, 0.5, 1.0] {
                for i in 0...40 {
                    for j in 0...20 {
                        let p = EspaceGeometry.point(u: Double(i)/40, v: Double(j)/20, time: t, seed: s)
                        XCTAssertTrue(p.x.isFinite && p.y.isFinite)
                        XCTAssertTrue((0...1).contains(p.x) && (0...1).contains(p.y))
                    }
                }
            }
        }
    }
    func testGeometryActuallyMovesInsteadOfRepaintingAStill() {
        let a = EspaceGeometry.band(index: 18, count: 56, samples: 84, time: 0, seed: 0.42)
        let b = EspaceGeometry.band(index: 18, count: 56, samples: 84, time: 8, seed: 0.42)
        XCTAssertGreaterThan(zip(a,b).map { abs($0.x-$1.x) + abs($0.y-$1.y) }.max()!, 0.01)
    }
    func testPeriodicPositionAndVelocityAreContinuous() {
        let e = 0.0001
        for i in 0...30 {
            let u = Double(i)/30
            let a = EspaceGeometry.point(u:u,v:0.3,time:0,seed:0.42)
            let b = EspaceGeometry.point(u:u,v:0.3,time:80,seed:0.42)
            XCTAssertEqual(a.x,b.x,accuracy:1e-10); XCTAssertEqual(a.y,b.y,accuracy:1e-10)
            let l = EspaceGeometry.point(u:u,v:0.3,time:80-e,seed:0.42)
            let r = EspaceGeometry.point(u:u,v:0.3,time:e,seed:0.42)
            XCTAssertEqual((a.x-l.x)/e,(r.x-a.x)/e,accuracy:1e-6)
            XCTAssertEqual((a.y-l.y)/e,(r.y-a.y)/e,accuracy:1e-6)
        }
    }
    func testAdjacentBandsShareTheExactBoundary() {
        let a = EspaceGeometry.band(index: 10, count: 56, samples: 84, time: 5, seed: 0.2)
        let b = EspaceGeometry.band(index: 11, count: 56, samples: 84, time: 5, seed: 0.2)
        XCTAssertEqual(Array(a.suffix(85).reversed()), Array(b.prefix(85)))
    }
    func testInvalidGeometryInputsStayFiniteAndBounded() {
        for n in [Double.nan, .infinity, -.infinity, -1, 9] {
            let p = EspaceGeometry.point(u:n,v:n,time:n,seed:n)
            XCTAssertTrue(p.x.isFinite && p.y.isFinite)
            XCTAssertTrue((0...1).contains(p.x) && (0...1).contains(p.y))
        }
        XCTAssertEqual(EspaceGeometry.band(index:-2,count:-1,samples:-1,time:0,seed:0).count,18)
        XCTAssertEqual(EspaceGeometry.band(index:999,count:999,samples:999,time:0,seed:0).count,322)
    }
    func testPauseResumeNeverCatchesUpHiddenTime() {
        var clock = EspaceClock()
        clock.tick(now:1,running:true); clock.tick(now:1.05,running:true)
        XCTAssertEqual(clock.elapsed,0.05,accuracy:1e-10)
        clock.suspend(); clock.tick(now:100,running:true)
        XCTAssertEqual(clock.elapsed,0.05,accuracy:1e-10)
        clock.tick(now:100.04,running:true)
        XCTAssertEqual(clock.elapsed,0.09,accuracy:1e-10)
    }
    func testClockRejectsInvalidAndCapsStalls() {
        var clock = EspaceClock()
        clock.tick(now:1,running:true); clock.tick(now:.nan,running:true)
        clock.tick(now:2,running:true); XCTAssertEqual(clock.elapsed,0.1,accuracy:1e-10)
        clock.tick(now:0,running:true); XCTAssertEqual(clock.elapsed,0.1,accuracy:1e-10)
        clock.tick(now:1,running:false); XCTAssertEqual(clock.elapsed,0.1,accuracy:1e-10)
    }
    func testEveryMotionStopGateTakesPriorityOverQuality() {
        for lowPower in [false,true] {
            XCTAssertEqual(EspaceMotionPolicy.fps(visible:false,active:true,enabled:true,reduced:false,lowPower:lowPower,hot:false),0)
            XCTAssertEqual(EspaceMotionPolicy.fps(visible:true,active:false,enabled:true,reduced:false,lowPower:lowPower,hot:false),0)
            XCTAssertEqual(EspaceMotionPolicy.fps(visible:true,active:true,enabled:false,reduced:false,lowPower:lowPower,hot:false),0)
            XCTAssertEqual(EspaceMotionPolicy.fps(visible:true,active:true,enabled:true,reduced:true,lowPower:lowPower,hot:false),0)
            XCTAssertEqual(EspaceMotionPolicy.fps(visible:true,active:true,enabled:true,reduced:false,lowPower:lowPower,hot:true),0)
        }
    }
    func testMotionBudgetsAndGeometryCostsAreExplicit() {
        XCTAssertEqual(EspaceMotionPolicy.fps(visible:true,active:true,enabled:true,reduced:false,lowPower:false,hot:false),24)
        XCTAssertEqual(EspaceMotionPolicy.fps(visible:true,active:true,enabled:true,reduced:false,lowPower:true,hot:false),12)
        XCTAssertEqual(EspaceGeometry.band(index:0,count:56,samples:84,time:0,seed:0).count * 56,9520)
        XCTAssertEqual(EspaceGeometry.band(index:0,count:28,samples:48,time:0,seed:0).count * 28,2744)
    }
}
