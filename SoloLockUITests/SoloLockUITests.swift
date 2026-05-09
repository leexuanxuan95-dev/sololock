import XCTest

/// End-to-end tour. Each test screenshots the screen it lands on so we can
/// verify rendering visually and prove every flow runs without crashing.
final class SoloLockUITests: XCTestCase {

    /// First-test cold-start can take 30+ seconds for the simulator+app to
    /// settle. Use this for the very first wait in every test.
    private let coldStartTimeout: TimeInterval = 20
    private let warmTimeout: TimeInterval = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func makeApp(skipOnboarding: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-reset"]
        if skipOnboarding {
            app.launchArguments += ["--ui-test-skip-onboarding"]
        }
        return app
    }

    private func attach(_ name: String, app: XCUIApplication) {
        let shot = app.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    /// Find an element by accessibility identifier across any element type.
    /// More resilient than `app.buttons["..."]` when SwiftUI exposes the
    /// element with an unexpected type.
    private func findAny(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    // MARK: - Onboarding flow

    func test01_onboardingRendersAndProgresses() {
        let app = makeApp(skipOnboarding: false)
        app.launch()
        let cta = app.buttons["onboarding.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: coldStartTimeout))
        attach("01-onboarding", app: app)
        cta.tap()
        let aiCard = findAny("picker.ai_judge", in: app)
        XCTAssertTrue(aiCard.waitForExistence(timeout: warmTimeout))
    }

    // MARK: - Picker → AI Judge → Setup → Lock → Chat → Preview takeover

    func test02_aiJudgeFullFlow() {
        let app = makeApp()
        app.launch()

        let aiCard = findAny("picker.ai_judge", in: app)
        XCTAssertTrue(aiCard.waitForExistence(timeout: coldStartTimeout))
        attach("02-picker", app: app)
        aiCard.tap()

        let cont = app.buttons["explainer.continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: warmTimeout))
        attach("03-explainer", app: app)
        cont.tap()

        let oneHour = findAny("duration.h1", in: app)
        XCTAssertTrue(oneHour.waitForExistence(timeout: warmTimeout))
        attach("04-setup", app: app)
        let handItOver = app.buttons["setup.handItOver"]
        XCTAssertTrue(handItOver.waitForExistence(timeout: warmTimeout))
        handItOver.tap()

        let chat = app.buttons["lock.openChat"]
        XCTAssertTrue(chat.waitForExistence(timeout: coldStartTimeout))
        attach("05-lock", app: app)
        chat.tap()

        let composer = app.textFields["chat.composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: warmTimeout))
        composer.tap()
        composer.typeText("im bored")
        let send = app.buttons["chat.send"]
        XCTAssertTrue(send.waitForExistence(timeout: warmTimeout))
        send.tap()
        Thread.sleep(forTimeInterval: 0.5)
        attach("06-chat", app: app)
    }

    // MARK: - Picker → Charity Lock → Setup screen with charity controls

    func test03_charityLockSetup() {
        let app = makeApp()
        app.launch()

        let charityCard = findAny("picker.charity", in: app)
        XCTAssertTrue(charityCard.waitForExistence(timeout: coldStartTimeout))
        charityCard.tap()
        let cont = app.buttons["explainer.continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: warmTimeout))
        cont.tap()

        let thirty = findAny("duration.m30", in: app)
        XCTAssertTrue(thirty.waitForExistence(timeout: warmTimeout))
        attach("08-charity-setup", app: app)
    }

    // MARK: - History tab

    func test04_historyTabRenders() {
        let app = makeApp()
        app.launch()

        let history = app.tabBars.buttons["History"]
        XCTAssertTrue(history.waitForExistence(timeout: coldStartTimeout))
        history.tap()
        Thread.sleep(forTimeInterval: 0.4)
        attach("09-history-empty", app: app)
        XCTAssertTrue(app.staticTexts["no sessions yet."].waitForExistence(timeout: warmTimeout))
    }

    // MARK: - Settings + paywall

    func test05_settingsAndPaywall() {
        let app = makeApp()
        app.launch()

        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: coldStartTimeout))
        settings.tap()
        Thread.sleep(forTimeInterval: 0.4)
        attach("10-settings", app: app)

        let seePlans = app.buttons["see plans"]
        if seePlans.waitForExistence(timeout: warmTimeout) {
            seePlans.tap()
            // Give StoreKit local config a moment to populate products,
            // otherwise the snapshot catches the "loading plans…" placeholder.
            let monthly = app.staticTexts["Pro Monthly"]
            _ = monthly.waitForExistence(timeout: 8)
            attach("11-paywall", app: app)
        }
    }
}
