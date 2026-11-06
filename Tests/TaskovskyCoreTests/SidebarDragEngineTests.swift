import XCTest
import Foundation
import CoreGraphics
@testable import TaskovskyCore

/// Lifecycle regression for the in-app sidebar drag driver shared by smart
/// lists, lists, folders, and tags. These tests drive `SidebarDragEngine`
/// directly — the same type the app's gesture layer feeds — with synthetic
/// pointer sequences (no UI, no synthetic desktop input): threshold gating,
/// hover tracking, release re-hit-testing, cancel/suppress/restart rules, and
/// the visible-viewport restriction.
final class SidebarDragEngineTests: XCTestCase {
    private var frames: [SidebarDropTarget: [CGRect]] = [:]
    private var viewport = CGRect(x: 0, y: 0, width: 220, height: 600)

    private var listA: UUID { UUID(uuidString: "11111111-1111-1111-1111-111111111111")! }
    private var listB: UUID { UUID(uuidString: "22222222-2222-2222-2222-222222222222")! }
    private var folder: UUID { UUID(uuidString: "33333333-3333-3333-3333-333333333333")! }

    override func setUp() {
        super.setUp()
        frames = [
            .list(listA): [CGRect(x: 8, y: 100, width: 204, height: 38)],
            .list(listB): [CGRect(x: 8, y: 138, width: 204, height: 38)],
            .folder(folder): [CGRect(x: 8, y: 200, width: 204, height: 38)],
            .root: [CGRect(x: 8, y: 60, width: 204, height: 30)],
        ]
        viewport = CGRect(x: 0, y: 0, width: 220, height: 600)
    }

    private func move(_ engine: inout SidebarDragEngine, from start: CGPoint, to location: CGPoint, payload: SidebarDragPayload) {
        engine.update(startLocation: start, location: location, payload: payload, frames: frames, viewport: viewport)
    }

    private var endFrames: [SidebarDropTarget: [CGRect]] {
        var next = frames
        next[.rootEnd] = [CGRect(x: 8, y: 260, width: 204, height: 14)]
        return next
    }

    private func moveEnd(_ engine: inout SidebarDragEngine, from start: CGPoint, to location: CGPoint, payload: SidebarDragPayload) {
        engine.update(startLocation: start, location: location, payload: payload, frames: endFrames, viewport: viewport)
    }

    // MARK: - Threshold and start

    func testBelowThresholdStaysIdle() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        move(&engine, from: origin, to: CGPoint(x: 55, y: 119), payload: .list(listB))
        XCTAssertFalse(engine.isActive)
        XCTAssertNil(engine.hover)
    }

    func testThresholdCrossStartsSessionWithHover() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 110)
        move(&engine, from: origin, to: CGPoint(x: 58, y: 110), payload: .list(listB))
        XCTAssertTrue(engine.isActive)
        XCTAssertEqual(engine.active, .list(listB))
        XCTAssertEqual(engine.hover, .list(listA))
        XCTAssertEqual(engine.edge, .above)
    }

    func testSecondSourceCannotHijackLiveSession() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 119), payload: .list(listB))
        move(&engine, from: origin, to: CGPoint(x: 70, y: 119), payload: .tag(UUID()))
        XCTAssertEqual(engine.active, .list(listB))
        XCTAssertEqual(engine.hover, .list(listA))
    }

    // MARK: - Hover tracking

    func testHoverFollowsPointerMidpoint() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 110)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 110), payload: .list(listB))
        XCTAssertEqual(engine.hover, .list(listA))
        XCTAssertEqual(engine.edge, .above)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 130), payload: .list(listB))
        XCTAssertEqual(engine.hover, .list(listA))
        XCTAssertEqual(engine.edge, .below)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 70), payload: .list(listB))
        XCTAssertEqual(engine.hover, .root)
        XCTAssertNil(engine.edge)
    }

    func testSelfTargetShowsNoHover() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 157)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 157), payload: .list(listB))
        XCTAssertTrue(engine.isActive)
        // Pointer over the source row itself: no marker.
        XCTAssertNil(engine.hover)
        XCTAssertNil(engine.edge)
        // Moving onto another row brings the marker back.
        move(&engine, from: origin, to: CGPoint(x: 70, y: 119), payload: .list(listB))
        XCTAssertEqual(engine.hover, .list(listA))
    }

    func testCrossTypeTargetShowsNoHover() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 219), payload: .tag(UUID()))
        XCTAssertTrue(engine.isActive)
        XCTAssertNil(engine.hover)
    }

    func testAssignTargetHighlightsWithoutEdge() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 219), payload: .list(listA))
        XCTAssertEqual(engine.hover, .folder(folder))
        XCTAssertNil(engine.edge)
    }

    // MARK: - Viewport restriction

    func testPointerOutsideViewportNeverHovers() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        // Pointer over a registered row that has scrolled out of view: the
        // viewport excludes it, so no hover and no commit.
        viewport = CGRect(x: 0, y: 300, width: 220, height: 300)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 119), payload: .list(listB))
        XCTAssertTrue(engine.isActive)
        XCTAssertNil(engine.hover)
        let release = engine.release(at: CGPoint(x: 70, y: 119), frames: frames, viewport: viewport)
        XCTAssertEqual(release, .none)
    }

    func testMissingViewportFailsClosed() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        engine.update(startLocation: origin, location: CGPoint(x: 70, y: 119), payload: .list(listB), frames: frames, viewport: nil)
        XCTAssertTrue(engine.isActive)
        XCTAssertNil(engine.hover)
    }

    // MARK: - Release re-hit-testing

    func testReleaseCommitsAtReleasePointNotLastMove() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 119), payload: .list(listB))
        XCTAssertEqual(engine.hover, .list(listA))
        // Release over the root affordance without an intervening move: the
        // commit target comes from the release coordinates.
        let release = engine.release(at: CGPoint(x: 70, y: 70), frames: frames, viewport: viewport)
        XCTAssertEqual(release, .commit(payload: .list(listB), target: .root, after: false))
        XCTAssertFalse(engine.isActive)
    }

    func testReleaseOutsideTargetsCancels() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 119), payload: .list(listB))
        let release = engine.release(at: CGPoint(x: 400, y: 119), frames: frames, viewport: viewport)
        XCTAssertEqual(release, .none)
        XCTAssertFalse(engine.isActive)
    }

    func testReleaseIsIdempotent() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 119), payload: .list(listB))
        let point = CGPoint(x: 70, y: 110)
        let first = engine.release(at: point, frames: frames, viewport: viewport)
        XCTAssertEqual(first, .commit(payload: .list(listB), target: .list(listA), after: false))
        XCTAssertEqual(engine.release(at: point, frames: frames, viewport: viewport), .none)
    }

    func testAssignReleaseTargetsFolder() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 219), payload: .list(listA))
        let release = engine.release(at: CGPoint(x: 70, y: 230), frames: frames, viewport: viewport)
        guard case .commit(let payload, let target, _) = release else {
            return XCTFail("expected a folder-assign commit, got \(release)")
        }
        XCTAssertEqual(payload, .list(listA))
        XCTAssertEqual(target, .folder(folder))
    }

    // MARK: - Absolute-end strip

    func testEndStripHoverShowsTargetWithoutEdge() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        moveEnd(&engine, from: origin, to: CGPoint(x: 70, y: 267), payload: .list(listB))
        XCTAssertTrue(engine.isActive)
        // The end strip is its own target: hover with no insertion edge, so
        // the app draws the root-level line instead of a row marker.
        XCTAssertEqual(engine.hover, .rootEnd)
        XCTAssertNil(engine.edge)
    }

    func testEndStripReleaseCommitsRootEnd() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        moveEnd(&engine, from: origin, to: CGPoint(x: 70, y: 267), payload: .list(listB))
        let release = engine.release(at: CGPoint(x: 70, y: 267), frames: endFrames, viewport: viewport)
        // The lower half of the 14pt strip resolves below (the commit ignores
        // `after` for .rootEnd: it always appends to the trailing end).
        XCTAssertEqual(release, .commit(payload: .list(listB), target: .rootEnd, after: true))
    }

    func testEndStripRejectsNonListSources() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        // Tags (and smart/folder payloads) must never hover or commit there.
        moveEnd(&engine, from: origin, to: CGPoint(x: 70, y: 267), payload: .tag(UUID()))
        XCTAssertTrue(engine.isActive)
        XCTAssertNil(engine.hover)
        XCTAssertEqual(engine.release(at: CGPoint(x: 70, y: 267), frames: endFrames, viewport: viewport), .none)
    }

    // MARK: - Cancel and restart rules

    func testCancelSuppressesSameSequenceRestart() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 119), payload: .list(listB))
        XCTAssertTrue(engine.isActive)
        engine.cancel()
        XCTAssertFalse(engine.isActive)
        XCTAssertTrue(engine.suppressUntilNewSequence)
        // Continued movement of the same pointer sequence must not restart.
        move(&engine, from: origin, to: CGPoint(x: 90, y: 119), payload: .list(listB))
        XCTAssertFalse(engine.isActive)
        // Release ends the sequence without committing and re-arms.
        XCTAssertEqual(engine.release(at: CGPoint(x: 90, y: 119), frames: frames, viewport: viewport), .none)
        XCTAssertFalse(engine.suppressUntilNewSequence)
    }

    func testNewSequenceRearmsAfterCancel() {
        var engine = SidebarDragEngine()
        let origin = CGPoint(x: 50, y: 119)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 119), payload: .list(listB))
        engine.cancel()
        let next = CGPoint(x: 60, y: 150)
        move(&engine, from: next, to: CGPoint(x: 80, y: 150), payload: .list(listA))
        XCTAssertTrue(engine.isActive)
        XCTAssertEqual(engine.hover, .list(listB))
    }

    func testIdleCancelIsNoOp() {
        var engine = SidebarDragEngine()
        engine.cancel()
        XCTAssertFalse(engine.suppressUntilNewSequence)
        let origin = CGPoint(x: 50, y: 119)
        move(&engine, from: origin, to: CGPoint(x: 70, y: 119), payload: .list(listB))
        XCTAssertTrue(engine.isActive)
    }
}
