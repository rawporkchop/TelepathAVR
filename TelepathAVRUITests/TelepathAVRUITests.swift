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

    // Tapping the hamburger must OPEN the menu, tapping again must CLOSE it, and the app must
    // stay interactive across the cycle (guards the "all UI frozen after toggling" regression).
    @MainActor
    func testHamburgerOpensAndClosesMenu() throws {
        let app = launchApp()

        let menuButton = app.buttons["menuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Hamburger button should exist")

        let settings = app.staticTexts["Settings"]
        waitUntilHittable(settings, false, "Side menu should start closed")

        menuButton.tap()
        waitUntilHittable(settings, true, "Tapping the hamburger should OPEN the side menu")
        XCTAssertTrue(app.buttons["Receivers"].isHittable, "Menu items should be reachable when open")

        menuButton.tap()
        waitUntilHittable(settings, false, "Tapping the hamburger again should CLOSE the side menu")

        menuButton.tap()
        waitUntilHittable(settings, true, "Menu should reopen; app must stay interactive after toggling")
    }

    // A menu item must actually do something — tapping Receivers presents the receivers sheet.
    @MainActor
    func testMenuReceiversItemPresentsSheet() throws {
        let app = launchApp()

        let menuButton = app.buttons["menuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()

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

        let menuButton = app.buttons["menuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()

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

        let menuButton = app.buttons["menuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()

        let theme = app.buttons["Theme"]
        waitUntilHittable(theme, true, "Theme item should be visible when the menu is open")
        theme.tap()

        XCTAssertTrue(app.buttons["Custom"].waitForExistence(timeout: 4),
                      "Tapping Theme should reveal the theme picker")
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
