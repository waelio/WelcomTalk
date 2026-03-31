import XCTest

/// Captures App Store screenshots by navigating key flows.
/// Run with: xcodebuild test -scheme WelcomTalk -destination 'id=AD18CF09-D811-4123-B610-8F127389EA0A' -only-testing WelcomTalkUITests/AppStoreScreenshotTests
final class AppStoreScreenshotTests: XCTestCase {

    var app: XCUIApplication!
    let screenshotDir = "/tmp/screenshots"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.waelio.Welcom")
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func saveScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: "\(screenshotDir)/\(name).png")
        try? screenshot.pngRepresentation.write(to: url)
    }

    // MARK: - Screenshot 1: Home screen

    func test01_HomeScreen() throws {
        XCTAssertTrue(app.staticTexts["Safe Communication"].waitForExistence(timeout: 8))
        sleep(1) // let UI settle
        saveScreenshot(named: "01_home")
    }

    // MARK: - Screenshot 2: Start Conversation / Create Session

    func test02_CreateSession() throws {
        XCTAssertTrue(app.buttons["Start Conversation"].waitForExistence(timeout: 8))
        app.buttons["Start Conversation"].tap()
        // Wait for the form to appear
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 6))
        sleep(1)
        saveScreenshot(named: "02_create_session")
    }

    // MARK: - Screenshot 3: Join Conversation

    func test03_JoinConversation() throws {
        XCTAssertTrue(app.buttons["Join Conversation"].waitForExistence(timeout: 8))
        app.buttons["Join Conversation"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 6))
        sleep(1)
        saveScreenshot(named: "03_join_conversation")
    }

    // MARK: - Screenshot 4: Demo / Active Session

    func test04_DemoSession() throws {
        XCTAssertTrue(app.buttons["Try Demo"].waitForExistence(timeout: 8))
        app.buttons["Try Demo"].tap()
        let sessionNav = app.navigationBars.firstMatch
        XCTAssertTrue(sessionNav.waitForExistence(timeout: 8))
        sleep(2) // let the timer start
        saveScreenshot(named: "04_demo_session")
    }
}
