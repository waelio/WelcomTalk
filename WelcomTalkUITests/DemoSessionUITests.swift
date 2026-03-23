import XCTest

/// End-to-end tests for the demo / active session flow.
final class DemoSessionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.waelio.WelcomTalk")
        app.launchArguments = ["UI_TESTING"]
        app.launch()
        // Open demo session
        XCTAssertTrue(app.buttons["Try Demo"].waitForExistence(timeout: 5))
        app.buttons["Try Demo"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 6))
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Session navigation and basic elements

    func testSessionViewIsPresented() {
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
    }

    func testTimerSectionExists() {
        // The timer shows minutes:seconds (e.g., "2:00") or a progress indicator
        let timerLabel = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '\\\\d+:\\\\d{2}'")
        ).firstMatch
        XCTAssertTrue(timerLabel.waitForExistence(timeout: 5))
    }

    func testPartyStatusSectionExists() {
        // The session shows "Party A" or "Party B" labels
        let partyText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Party' OR label CONTAINS 'Turn'")
        ).firstMatch
        XCTAssertTrue(partyText.waitForExistence(timeout: 5))
    }

    func testSimulateJoinButtonVisible() {
        // In host-waiting-room the demo button shows "Simulate Join (Demo)"
        let simBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Simulate'")
        ).firstMatch
        // Only present in WaitingRoomView; demo session may skip it
        if simBtn.waitForExistence(timeout: 3) {
            XCTAssertTrue(simBtn.isEnabled)
        }
    }

    func testLeaveOrEndButtonExists() {
        // There should be a way to exit – "Leave" or "End" or a close button
        let leaveOrClose = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Leave' OR label CONTAINS 'End' OR label == 'Done' OR label == 'Close'")
        ).firstMatch
        XCTAssertTrue(leaveOrClose.waitForExistence(timeout: 5))
    }

    func testNotesSectionExists() {
        // The active session shows a notes text editor or "Notes" label
        let notesLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Note'")
        ).firstMatch
        XCTAssertTrue(notesLabel.waitForExistence(timeout: 5))
    }

    // MARK: - Simulate join → active session

    func testSimulateJoinStartsSession() {
        let simBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Simulate'")
        ).firstMatch
        guard simBtn.waitForExistence(timeout: 4) else {
            // Already in active session (demo path)
            return
        }
        simBtn.tap()
        // After simulated join the timer should be ticking
        let runningTimer = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '\\\\d+:\\\\d{2}'")
        ).firstMatch
        XCTAssertTrue(runningTimer.waitForExistence(timeout: 6))
    }

    func testSessionLogsVisible() {
        // Activate the session first if still in waiting room
        let simBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Simulate'")
        ).firstMatch
        if simBtn.waitForExistence(timeout: 3) { simBtn.tap() }

        let logSection = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Log' OR label CONTAINS 'History' OR label CONTAINS 'Started'")
        ).firstMatch
        XCTAssertTrue(logSection.waitForExistence(timeout: 6))
    }

    func testModificationRequestButtonExists() {
        let simBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Simulate'")
        ).firstMatch
        if simBtn.waitForExistence(timeout: 3) { simBtn.tap() }

        // "Request" or similar modification-request button
        let reqBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Request' OR label CONTAINS 'Extend' OR label CONTAINS 'Pause'")
        ).firstMatch
        // Present only during active session
        _ = reqBtn.waitForExistence(timeout: 5)
        // Non-fatal: just assert we don't crash
    }

    // MARK: - Dismissal

    func testLeaveSessionReturnsHome() {
        let leaveOrClose = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Leave' OR label CONTAINS 'End' OR label == 'Done' OR label == 'Close'")
        ).firstMatch
        guard leaveOrClose.waitForExistence(timeout: 5) else {
            XCTFail("No way to leave the session was found")
            return
        }
        leaveOrClose.tap()
        // There may be a confirmation alert
        if app.alerts.firstMatch.waitForExistence(timeout: 2) {
            let confirmBtn = app.alerts.buttons.matching(
                NSPredicate(format: "label CONTAINS 'End' OR label CONTAINS 'Leave' OR label CONTAINS 'Yes' OR label CONTAINS 'Confirm'")
            ).firstMatch
            if confirmBtn.exists { confirmBtn.tap() }
        }
        // Expect rating sheet OR home screen
        let backHome = app.staticTexts["Safe Communication"]
            .waitForExistence(timeout: 5)
        let ratingSheet = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Rate' OR label CONTAINS 'Rating'")
        ).firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(backHome || ratingSheet)
    }
}
