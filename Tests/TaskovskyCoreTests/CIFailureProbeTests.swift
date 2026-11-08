import XCTest

// Temporary CI acceptance probe. Removed after the failure run is verified.
final class CIFailureProbeTests: XCTestCase {
    func testIntentionalFailureIsReported() {
        XCTFail("Intentional CI acceptance probe: the job must fail and retain diagnostics.")
    }
}
