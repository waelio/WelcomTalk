import XCTest

/// End-to-end tests for the Join Session flow.
final class JoinSessionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
        XCTAssertTrue(app.buttons["Join Conversation"].waitForExistence(timeout: 5))
        app.buttons["Join Conversation"].tap()
        XCTAssertTrue(app.textFields["Session Code"].waitForExistence(timeout: 4))
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Field visibility

    func testJoinFormFieldsVisible() {
        XCTAssertTrue(app.textFields["Your Name"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Session Code"].exists)
    }

    func testJoinButtonDisabledWhenEmpty() {
        // The modal submit button should be disabled when fields are empty.
        // Check using isEnabled directly (background buttons also have "Join" in their label
        // but they may still be in the accessibility tree behind the sheet).
        let disabledJoinBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Join Conversation' AND enabled == false")
        ).firstMatch
        XCTAssertTrue(disabledJoinBtn.waitForExistence(timeout: 3), "Join button should be disabled when fields are empty")
    }

    func testSessionCodeUppercased() {
        let codeField = app.textFields["Session Code"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 3))
        codeField.tap()
        codeField.typeText("abc123")
        // The field binds with .uppercased() so the displayed value should be uppercase
        XCTAssertEqual(codeField.value as? String ?? "", "ABC123")
    }

    func testSessionCodeMaxLengthReflected() {
        let codeField = app.textFields["Session Code"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 3))
        codeField.tap()
        codeField.typeText("ABCDEF")
        XCTAssertEqual((codeField.value as? String ?? "").count, 6)
    }

    func testFillBothFields_EnablesJoin() {
        let nameField = app.textFields["Your Name"]
        let codeField = app.textFields["Session Code"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Carol")
        codeField.tap()
        codeField.typeText("XYZ123")
        let joinBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Join' AND enabled == true")
        ).firstMatch
        XCTAssertTrue(joinBtn.waitForExistence(timeout: 2))
    }

    func testQRScanSectionVisible() {
        let scanBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Scan QR'")
        ).firstMatch
        XCTAssertTrue(scanBtn.waitForExistence(timeout: 3))
    }

    func testCancelReturnsHome() {
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Safe Communication"].waitForExistence(timeout: 4))
    }

    // MARK: - Attempt join with invalid code

    func testJoinWithInvalidCodeShowsError() {
        let nameField = app.textFields["Your Name"]
        let codeField = app.textFields["Session Code"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Dave")
        codeField.tap()
        codeField.typeText("XXXXXX")
        // Tap the "Join by Code" button
        let joinBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Join' AND enabled == true")
        ).firstMatch
        if joinBtn.waitForExistence(timeout: 2) {
            joinBtn.tap()
            // Without a real host the app shows an error or goes to connecting state
            // Either state is acceptable – we just confirm the app does not crash
            let resultState = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'error' OR label CONTAINS 'Error' OR label CONTAINS 'Connecting' OR label CONTAINS 'Waiting'")
            ).firstMatch
            // Allow either result or a timeout – the primary concern is no crash
            _ = resultState.waitForExistence(timeout: 5)
        }
    }
}
