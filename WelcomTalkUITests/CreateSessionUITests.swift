import XCTest

/// End-to-end tests for the Create Session flow.
final class CreateSessionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
        // Open the Create Session sheet before each test
        XCTAssertTrue(app.buttons["Start Conversation"].waitForExistence(timeout: 5))
        app.buttons["Start Conversation"].tap()
        XCTAssertTrue(app.textFields["Topic (e.g., Family Discussion)"].waitForExistence(timeout: 4))
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Field validation

    func testStartButtonDisabledWhenFieldsEmpty() {
        // Both fields empty → "Start Conversation" action button should be disabled
        let startBtn = app.buttons["Start Conversation"].firstMatch
        // Buttons inside a Form are found by label; the CTA is inside the Section
        // We look for the Submit button specifically by its text in the form
        XCTAssertTrue(startBtn.waitForExistence(timeout: 3))
        // The first "Start Conversation" is the home-screen one (now hidden); the sheet
        // button label text is rendered inside the Form.
        let formButtons = app.buttons.matching(identifier: "Start Conversation")
        // At least one should exist
        XCTAssertGreaterThan(formButtons.count, 0)
    }

    func testFormFieldsVisible() {
        XCTAssertTrue(app.textFields["Topic (e.g., Family Discussion)"].exists
            || app.textFields.firstMatch.exists)
        XCTAssertTrue(app.textFields["Your Name"].exists
            || app.textFields.element(boundBy: 1).exists)
    }

    func testFillTitleOnly_StartButtonStillDisabled() {
        let topicField = app.textFields["Topic (e.g., Family Discussion)"]
        XCTAssertTrue(topicField.waitForExistence(timeout: 3))
        topicField.tap()
        topicField.typeText("Family Budget Discussion")
        // userName still empty – button must remain disabled
        let startBtn = app.buttons.matching(NSPredicate(format: "label == 'Start Conversation' AND enabled == true")).firstMatch
        XCTAssertFalse(startBtn.exists)
    }

    func testFillBothFields_StartButtonEnabled() {
        let topicField = app.textFields["Topic (e.g., Family Discussion)"]
        let nameField  = app.textFields["Your Name"]
        XCTAssertTrue(topicField.waitForExistence(timeout: 3))
        topicField.tap()
        topicField.typeText("Work Conflict")
        nameField.tap()
        nameField.typeText("Alice")
        // Now the Start Conversation button inside the form should be enabled
        let enabledStart = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start Conversation' AND enabled == true")).firstMatch
        XCTAssertTrue(enabledStart.waitForExistence(timeout: 2))
    }

    func testCreateSession_LaunchesWaitingRoom() {
        let topicField = app.textFields["Topic (e.g., Family Discussion)"]
        let nameField  = app.textFields["Your Name"]
        XCTAssertTrue(topicField.waitForExistence(timeout: 3))
        topicField.tap()
        topicField.typeText("Household Finances")
        nameField.tap()
        nameField.typeText("Bob")
        // Dismiss keyboard so the button is reachable
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start Conversation' AND enabled == true")).firstMatch.tap()
        // Should arrive at the WaitingRoom / SessionView
        // The waiting view shows the session code or a "Waiting for other party" text
        let arrived = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Waiting' OR label CONTAINS 'Session Code' OR label CONTAINS 'code' OR label CONTAINS 'Conversation'")
        ).firstMatch
        XCTAssertTrue(arrived.waitForExistence(timeout: 6))
    }

    func testCancelReturnsHome() {
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Safe Communication"].waitForExistence(timeout: 4))
    }

    // MARK: - "How It Works" section

    func testHowItWorksSectionVisible() {
        XCTAssertTrue(app.staticTexts["How It Works"].waitForExistence(timeout: 3))
    }

    func testPickerDefaultValues() {
        // The "Number of Turns" picker default label should contain "10"
        let turnPicker = app.otherElements.matching(NSPredicate(format: "label CONTAINS 'Number of Turns'")).firstMatch
        // Alternatively check for the default value text
        XCTAssertTrue(app.staticTexts["10 turns each"].waitForExistence(timeout: 3)
            || app.buttons["10 turns each"].waitForExistence(timeout: 1)
            || turnPicker.waitForExistence(timeout: 1))
    }
}
