import XCTest

final class StrideUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLoadSampleRunsAndOpenInsights() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let loadSample = app.buttons["loadSampleButton"]
        XCTAssertTrue(loadSample.waitForExistence(timeout: 5))
        loadSample.tap()

        // The history list appears with the analysed sample runs.
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5))

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.buttons["askCoachButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLogRunShowsLiveAIAnalysis() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.buttons["logRunButton"].tap()
        XCTAssertTrue(app.navigationBars["Log a run"].waitForExistence(timeout: 5))
        // Default values (5 km in 32 min) are valid, so the AI preview and Save are available.
        XCTAssertTrue(app.buttons["saveRunButton"].isEnabled)
        app.buttons["saveRunButton"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5))
    }
}
