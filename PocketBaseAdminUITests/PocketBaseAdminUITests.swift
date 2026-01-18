//
//  PocketBaseAdminUITests.swift
//  PocketBaseAdminUITests
//
//  Created by Brianna Zamora on 3/16/25.
//

import XCTest
@testable import PocketBaseAdminApp

final class PocketBaseAdminUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testCreateNewRecord() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Wait for login view to appear
        let emailField = app.textFields["admin@example.com"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))

        // Type email
        emailField.tap()
        emailField.typeText("fake@fake.com")

        // Type password
        let passwordField = app.secureTextFields["••••••••"]
        passwordField.tap()
        passwordField.typeText("Test123456")

        // Tap Sign In button
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.isEnabled)
        signInButton.tap()

        // Wait for the main content to load (Collections tab should appear)
        let collectionsTab = app.buttons["Collections"]
        XCTAssertTrue(collectionsTab.waitForExistence(timeout: 10))
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
