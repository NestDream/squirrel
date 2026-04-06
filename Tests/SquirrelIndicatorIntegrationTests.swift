//
//  SquirrelIndicatorIntegrationTests.swift
//  Squirrel
//
//  Integration tests for SquirrelIndicator lifecycle and notification callback flow.
//  Feature: cursor-input-indicator
//  Validates: Requirements 4.1, 4.2, 4.3, 5.3
//

import Testing
import AppKit
@testable import SquirrelCore

// MARK: - Mode Switching Tests

/// **Validates: Requirements 4.1**
/// Tests that mode switching via update() correctly changes the asciiMode property,
/// simulating the notificationHandler receiving ascii_mode changes.
@MainActor
struct SquirrelIndicatorModeSwitchingTests {

  @Test("Mode switching: update with asciiMode=false then asciiMode=true changes state")
  func modeSwitchingUpdatesAsciiMode() {
    let indicator = SquirrelIndicator()
    indicator.enabled = true
    let cursorRect = NSRect(x: 200, y: 300, width: 1, height: 18)

    // Simulate notificationHandler receiving ascii_mode=false (Chinese mode)
    indicator.update(asciiMode: false, cursorRect: cursorRect)
    #expect(indicator.asciiMode == false,
            "After update with asciiMode=false, indicator should be in Chinese mode")

    // Simulate notificationHandler receiving ascii_mode=true (ASCII mode)
    indicator.update(asciiMode: true, cursorRect: cursorRect)
    #expect(indicator.asciiMode == true,
            "After update with asciiMode=true, indicator should be in ASCII mode")

    // Clean up
    indicator.hide()
  }

  @Test("Rapid mode toggling preserves last state")
  func rapidModeTogglingPreservesLastState() {
    let indicator = SquirrelIndicator()
    indicator.enabled = true
    let cursorRect = NSRect(x: 100, y: 100, width: 1, height: 18)

    // Simulate rapid toggling
    indicator.update(asciiMode: false, cursorRect: cursorRect)
    indicator.update(asciiMode: true, cursorRect: cursorRect)
    indicator.update(asciiMode: false, cursorRect: cursorRect)
    indicator.update(asciiMode: true, cursorRect: cursorRect)
    indicator.update(asciiMode: false, cursorRect: cursorRect)

    #expect(indicator.asciiMode == false,
            "After rapid toggling ending with false, asciiMode should be false")

    // Clean up
    indicator.hide()
  }
}

// MARK: - Full Lifecycle Tests

/// **Validates: Requirements 4.1, 4.2, 4.3, 5.3**
/// Tests the complete lifecycle: activateServer → switch mode → show candidates
/// → hide Indicator → candidates disappear → restore Indicator → deactivateServer
@MainActor
struct SquirrelIndicatorLifecycleTests {

  @Test("Full lifecycle: activate → mode switch → candidate show/hide → deactivate")
  func fullLifecycleTest() {
    let indicator = SquirrelIndicator()
    indicator.enabled = true
    let cursorRect = NSRect(x: 300, y: 400, width: 1, height: 18)

    // Step 1: Simulate activateServer — update with initial mode, indicator becomes visible
    indicator.update(asciiMode: false, cursorRect: cursorRect)
    #expect(indicator.isVisible == true,
            "After activateServer (update), indicator should be visible")
    #expect(indicator.asciiMode == false,
            "Initial mode should be Chinese (asciiMode=false)")

    // Step 2: Simulate mode switch via notificationHandler
    indicator.update(asciiMode: true, cursorRect: cursorRect)
    #expect(indicator.isVisible == true,
            "After mode switch, indicator should still be visible")
    #expect(indicator.asciiMode == true,
            "After mode switch, asciiMode should be true")

    // Step 3: Simulate candidate panel showing — hide Indicator
    indicator.hide()
    #expect(indicator.isVisible == false,
            "When candidate panel shows, indicator should be hidden")

    // Step 4: Simulate candidates disappear — rimeUpdate restores Indicator
    indicator.update(asciiMode: true, cursorRect: cursorRect)
    #expect(indicator.isVisible == true,
            "After candidates disappear (rimeUpdate), indicator should be visible again")

    // Step 5: Simulate deactivateServer — hide Indicator
    indicator.hide()
    #expect(indicator.isVisible == false,
            "After deactivateServer, indicator should be hidden")
  }

  @Test("Lifecycle with disabled indicator stays hidden throughout")
  func lifecycleWithDisabledIndicator() {
    let indicator = SquirrelIndicator()
    indicator.enabled = false
    let cursorRect = NSRect(x: 300, y: 400, width: 1, height: 18)

    // Even with update calls, disabled indicator should not become visible
    indicator.update(asciiMode: false, cursorRect: cursorRect)
    #expect(indicator.isVisible == false,
            "Disabled indicator should not be visible after update")

    indicator.update(asciiMode: true, cursorRect: cursorRect)
    #expect(indicator.isVisible == false,
            "Disabled indicator should remain hidden after mode switch")
  }
}

// MARK: - Mode Update Preserves Cursor Position Tests

/// **Validates: Requirements 4.1**
/// Tests that a mode change (simulated via update) preserves the cursor position.
@MainActor
struct SquirrelIndicatorCursorPreservationTests {

  @Test("Mode update preserves cursor position when cursorRect is the same")
  func modeUpdatePreservesCursorPosition() {
    let indicator = SquirrelIndicator()
    indicator.enabled = true
    let cursorRect = NSRect(x: 500, y: 600, width: 2, height: 20)

    // Initial update with Chinese mode
    indicator.update(asciiMode: false, cursorRect: cursorRect)
    let positionAfterChinese = indicator.cursorRect

    // Simulate mode change with same cursor position (as notificationHandler would do)
    indicator.update(asciiMode: true, cursorRect: cursorRect)
    let positionAfterAscii = indicator.cursorRect

    #expect(positionAfterChinese == positionAfterAscii,
            "cursorRect should be preserved when only mode changes")
    #expect(indicator.cursorRect == cursorRect,
            "cursorRect should match the original value")

    // Clean up
    indicator.hide()
  }

  @Test("Cursor position updates when cursor moves")
  func cursorPositionUpdatesOnMove() {
    let indicator = SquirrelIndicator()
    indicator.enabled = true
    let firstRect = NSRect(x: 100, y: 200, width: 1, height: 18)
    let secondRect = NSRect(x: 400, y: 500, width: 1, height: 18)

    indicator.update(asciiMode: false, cursorRect: firstRect)
    #expect(indicator.cursorRect == firstRect)

    indicator.update(asciiMode: false, cursorRect: secondRect)
    #expect(indicator.cursorRect == secondRect,
            "cursorRect should update when cursor moves")

    // Clean up
    indicator.hide()
  }
}

// MARK: - Zero Rect Hides Indicator Tests

/// **Validates: Requirements 4.1, 4.2**
/// Tests that calling update() with a zero cursorRect hides the indicator.
@MainActor
struct SquirrelIndicatorZeroRectTests {

  @Test("Zero rect cursorRect hides indicator")
  func zeroRectHidesIndicator() {
    let indicator = SquirrelIndicator()
    indicator.enabled = true
    let normalRect = NSRect(x: 200, y: 300, width: 1, height: 18)

    // First show the indicator with a valid cursor position
    indicator.update(asciiMode: false, cursorRect: normalRect)
    #expect(indicator.isVisible == true,
            "Indicator should be visible with valid cursor position")

    // Now update with zero rect — should hide
    indicator.update(asciiMode: false, cursorRect: .zero)
    #expect(indicator.isVisible == false,
            "Indicator should be hidden when cursorRect is .zero")
  }

  @Test("Recovery from zero rect when valid cursor position is provided again")
  func recoveryFromZeroRect() {
    let indicator = SquirrelIndicator()
    indicator.enabled = true
    let normalRect = NSRect(x: 200, y: 300, width: 1, height: 18)

    // Show, then hide with zero rect
    indicator.update(asciiMode: false, cursorRect: normalRect)
    indicator.update(asciiMode: false, cursorRect: .zero)
    #expect(indicator.isVisible == false)

    // Recover with valid cursor position
    indicator.update(asciiMode: true, cursorRect: normalRect)
    #expect(indicator.isVisible == true,
            "Indicator should recover and become visible with valid cursor position")

    // Clean up
    indicator.hide()
  }
}
