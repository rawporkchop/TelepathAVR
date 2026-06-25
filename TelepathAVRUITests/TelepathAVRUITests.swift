//
//  TelepathAVRUITests.swift
//  TelepathAVRUITests
//
//  Created by Oliver Larsson on 1/12/25.
//

import XCTest

final class TelepathAVRUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        // Dismiss the first-run "Proceed to connect..." alert if it appears.
        let no = app.buttons["No"]
        if no.waitForExistence(timeout: 3) {
            no.tap()
        }
        return app
    }

    // Open the drawer with a left-to-right swipe starting at the leading edge (the swipe
    // replaced the old hamburger button).
    @MainActor
    private func openMenu(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    // Close the drawer with a right-to-left swipe over the dimmed content.
    @MainActor
    private func closeMenu(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    // Right-to-left background swipe — summons the next zone slider (startLocation well past the
    // 28pt leading open-strip, translation strongly negative to clear the -100 threshold).
    @MainActor
    private func swipeAddZone(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    // Left-to-right background swipe — dismisses the last summoned zone slider.
    @MainActor
    private func swipeRemoveZone(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    // The menu's visibility is best detected via isHittable (the menu may exist off-screen).
    @MainActor
    private func waitUntilHittable(_ element: XCUIElement,
                                   _ expected: Bool,
                                   timeout: TimeInterval = 4,
                                   _ message: String,
                                   file: StaticString = #filePath,
                                   line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isHittable == expected { return }
            usleep(100_000) // 0.1s
        }
        XCTAssertEqual(element.isHittable, expected, message, file: file, line: line)
    }

    // A left-edge swipe must OPEN the menu, a reverse swipe must CLOSE it, and the app must
    // stay interactive across the cycle (guards the "all UI frozen after toggling" regression).
    @MainActor
    func testSwipeOpensAndClosesMenu() throws {
        let app = launchApp()

        let settings = app.staticTexts["Settings"]
        waitUntilHittable(settings, false, "Side menu should start closed")

        openMenu(app)
        waitUntilHittable(settings, true, "Left-edge swipe should OPEN the side menu")
        XCTAssertTrue(app.buttons["Receivers"].isHittable, "Menu items should be reachable when open")

        closeMenu(app)
        waitUntilHittable(settings, false, "Right-to-left swipe should CLOSE the side menu")

        openMenu(app)
        waitUntilHittable(settings, true, "Menu should reopen; app must stay interactive after toggling")
    }

    // A menu item must actually do something — tapping Receivers presents the receivers sheet.
    @MainActor
    func testMenuReceiversItemPresentsSheet() throws {
        let app = launchApp()

        openMenu(app)
        let receivers = app.buttons["Receivers"]
        waitUntilHittable(receivers, true, "Receivers item should be visible when the menu is open")
        receivers.tap()

        XCTAssertTrue(app.staticTexts["Select Receiver"].waitForExistence(timeout: 4),
                      "Tapping Receivers should present the receivers sheet")
    }

    // Tapping General presents the General settings.
    @MainActor
    func testMenuGeneralItemPresentsSettings() throws {
        let app = launchApp()

        openMenu(app)
        let general = app.buttons["General"]
        waitUntilHittable(general, true, "General item should be visible when the menu is open")
        general.tap()

        XCTAssertTrue(app.switches["Swipe Gesture to Summon"].waitForExistence(timeout: 4),
                      "Tapping General should present the General settings")
    }

    // Tapping Theme reveals the theme picker inside the menu.
    @MainActor
    func testMenuThemeItemShowsThemePicker() throws {
        let app = launchApp()

        openMenu(app)
        let theme = app.buttons["Theme"]
        waitUntilHittable(theme, true, "Theme item should be visible when the menu is open")
        theme.tap()

        XCTAssertTrue(app.buttons["Custom"].waitForExistence(timeout: 4),
                      "Tapping Theme should reveal the theme picker")
    }

    // A right-to-left background swipe must SUMMON the next zone slider, and a left-to-right swipe
    // must DISMISS it again. Paced with pauses so a concurrent screen recording isolates each
    // trailing-edge slide for frame inspection.
    @MainActor
    func testZoneSwipeSummonsAndDismissesSliders() throws {
        let app = launchApp()

        let main = app.staticTexts["MAIN"]
        XCTAssertTrue(main.waitForExistence(timeout: 4), "The Main zone slider should be visible at launch")
        let zone2 = app.staticTexts["ZONE 2"]
        XCTAssertFalse(zone2.exists, "Zone 2 should be absent before any swipe")

        sleep(2) // stable 1-slider baseline in the recording
        swipeAddZone(app)
        XCTAssertTrue(zone2.waitForExistence(timeout: 4),
                      "A right-to-left swipe should summon the Zone 2 slider")

        sleep(2) // stable 2-slider state
        let zone3 = app.staticTexts["ZONE 3"]
        swipeAddZone(app)
        XCTAssertTrue(zone3.waitForExistence(timeout: 4),
                      "A second right-to-left swipe should summon the Zone 3 slider")

        sleep(2) // stable 3-slider state
        swipeRemoveZone(app)
        XCTAssertTrue(main.waitForExistence(timeout: 4), "Main must remain after dismissing a zone")
        XCTAssertFalse(app.staticTexts["ZONE 3"].isHittable,
                       "A left-to-right swipe should dismiss the Zone 3 slider")
        sleep(2) // stable 2-slider state
    }

    // The Main slider must always stay — a left-to-right swipe from the single-slider baseline is a
    // no-op (minimum one slider is shown).
    @MainActor
    func testMainSliderIsNeverRemoved() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["MAIN"].waitForExistence(timeout: 4),
                      "The Main slider should be visible at launch")

        swipeRemoveZone(app)
        swipeRemoveZone(app)

        XCTAssertTrue(app.staticTexts["MAIN"].exists,
                      "Main slider must always remain — minimum one slider is shown")
        XCTAssertFalse(app.staticTexts["ZONE 2"].exists,
                       "Remove swipes from the baseline must not add a zone")
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
