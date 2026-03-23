import XCTest

/// Shared launch helper + home-screen sanity tests.
final class WelcomTalkUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Home screen

    func testHomeScreenElements() {
        XCTAssertTrue(app.staticTexts["Safe Communication"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start Conversation"].exists)
        XCTAssertTrue(app.buttons["Join Conversation"].exists)
        XCTAssertTrue(app.buttons["Try Demo"].exists)
    }

    func testHomeScreenHasSettingsToolbarButton() {
        XCTAssertTrue(app.staticTexts["Safe Communication"].waitForExistence(timeout: 5))
        // The network-settings toolbar button uses the "network" SF Symbol label
        let settingsButton = app.buttons["network"]
        XCTAssertTrue(settingsButton.exists)
    }

    func testTapStartConversationOpensSheet() {
        XCTAssertTrue(app.buttons["Start Conversation"].waitForExistence(timeout: 5))
        app.buttons["Start Conversation"].tap()
        // Inline nav title may not appear as staticText; verify via form text field
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 4))
    }

    func testTapJoinConversationOpensSheet() {
        XCTAssertTrue(app.buttons["Join Conversation"].waitForExistence(timeout: 5))
        app.buttons["Join Conversation"].tap()
        // Inline nav title may not appear as staticText; verify via form text field
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 4))
    }

    func testTapTryDemoOpensSession() {
        XCTAssertTrue(app.buttons["Try Demo"].waitForExistence(timeout: 5))
        app.buttons["Try Demo"].tap()
        // The session view header shows the session title or "WelcomTalk"
        let sessionNav = app.navigationBars.firstMatch
        XCTAssertTrue(sessionNav.waitForExistence(timeout: 6))
    }

    func testDismissCreateSessionSheet() {
        app.buttons["Start Conversation"].waitForExistence(timeout: 5)
        app.buttons["Start Conversation"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 4))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Safe Communication"].waitForExistence(timeout: 4))
    }

    func testDismissJoinSessionSheet() {
        app.buttons["Join Conversation"].waitForExistence(timeout: 5)
        app.buttons["Join Conversation"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 4))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Safe Communication"].waitForExistence(timeout: 4))
    }

    func testMessagingSettingsSheet() {
        XCTAssertTrue(app.staticTexts["Safe Communication"].waitForExistence(timeout: 5))
        app.buttons["network"].tap()
        XCTAssertTrue(app.staticTexts["Messaging Server"].waitForExistence(timeout: 4))
        // Close the sheet
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        } else {
            app.swipeDown()
        }
        XCTAssertTrue(app.staticTexts["Safe Communication"].waitForExistence(timeout: 4))
    }
}
