//
//  SquirrelIndicatorConfigTests.swift
//  Squirrel
//
//  Unit tests for SquirrelIndicator configuration behavior
//  Feature: cursor-input-indicator
//  Validates: Requirements 1.1, 1.2, 6.3, 6.4, 6.5
//

import Testing
import AppKit
@testable import SquirrelCore

/// Helper to compare two NSColors by their sRGB components
private func colorsEqual(_ c1: NSColor, _ c2: NSColor, epsilon: CGFloat = 0.001) -> Bool {
  guard let srgb1 = c1.usingColorSpace(.sRGB),
        let srgb2 = c2.usingColorSpace(.sRGB) else {
    return false
  }
  return abs(srgb1.redComponent - srgb2.redComponent) < epsilon
    && abs(srgb1.greenComponent - srgb2.greenComponent) < epsilon
    && abs(srgb1.blueComponent - srgb2.blueComponent) < epsilon
    && abs(srgb1.alphaComponent - srgb2.alphaComponent) < epsilon
}

// MARK: - Default Values Tests

/// **Validates: Requirements 1.1, 1.2**
/// Tests that SquirrelIndicator defaults match the "not set" configuration behavior.
@MainActor
struct SquirrelIndicatorDefaultValuesTests {

  @Test("Default enabled is false (matches show_input_indicator not set)")
  func defaultEnabledIsFalse() {
    let indicator = SquirrelIndicator()
    #expect(indicator.enabled == false,
            "When show_input_indicator is not set, enabled should default to false")
  }

  @Test("Default chineseColor is light blue (0.4, 0.7, 1.0, 1)")
  func defaultChineseColorIsLightBlue() {
    let indicator = SquirrelIndicator()
    let expectedBlue = NSColor(srgbRed: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
    #expect(colorsEqual(indicator.chineseColor, expectedBlue),
            "Default chineseColor should be light blue (sRGB 0.4, 0.7, 1.0, 1)")
  }

  @Test("Default asciiColor is orange (1, 0.647, 0, 1)")
  func defaultAsciiColorIsOrange() {
    let indicator = SquirrelIndicator()
    let expectedOrange = NSColor(srgbRed: 1.0, green: 0.647, blue: 0, alpha: 1.0)
    #expect(colorsEqual(indicator.asciiColor, expectedOrange),
            "Default asciiColor should be orange (sRGB 1, 0.647, 0, 1)")
  }
}

// MARK: - Enabled Behavior Tests

/// **Validates: Requirements 1.3, 1.4**
/// Tests that the enabled flag controls whether show() makes the indicator visible.
@MainActor
struct SquirrelIndicatorEnabledBehaviorTests {

  @Test("show() does nothing when enabled is false")
  func showDoesNothingWhenDisabled() {
    let indicator = SquirrelIndicator()
    indicator.enabled = false
    indicator.show()
    #expect(indicator.isVisible == false,
            "Indicator should not be visible when enabled is false")
  }

  @Test("show() makes indicator visible when enabled is true")
  func showWorksWhenEnabled() {
    let indicator = SquirrelIndicator()
    indicator.enabled = true
    indicator.show()
    #expect(indicator.isVisible == true,
            "Indicator should be visible when enabled is true and show() is called")
    // Clean up
    indicator.hide()
  }

  @Test("hide() hides indicator regardless of enabled state")
  func hideAlwaysHides() {
    let indicator = SquirrelIndicator()
    indicator.enabled = true
    indicator.show()
    #expect(indicator.isVisible == true)
    indicator.hide()
    #expect(indicator.isVisible == false,
            "Indicator should be hidden after hide() is called")
  }
}

// MARK: - Custom Color Assignment Tests

/// **Validates: Requirements 6.3, 6.4, 6.5**
/// Tests that custom colors can be assigned and are used correctly via colorForMode.
struct SquirrelIndicatorCustomColorTests {

  @Test("Custom chineseColor is used by colorForMode when asciiMode is false")
  func customChineseColorUsedInChineseMode() {
    let customChinese = NSColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
    let customAscii = NSColor(srgbRed: 0.9, green: 0.1, blue: 0.3, alpha: 1.0)

    let result = SquirrelIndicator.colorForMode(
      asciiMode: false,
      chineseColor: customChinese,
      asciiColor: customAscii
    )
    #expect(colorsEqual(result, customChinese),
            "colorForMode should return chineseColor when asciiMode is false")
  }

  @Test("Custom asciiColor is used by colorForMode when asciiMode is true")
  func customAsciiColorUsedInAsciiMode() {
    let customChinese = NSColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
    let customAscii = NSColor(srgbRed: 0.9, green: 0.1, blue: 0.3, alpha: 1.0)

    let result = SquirrelIndicator.colorForMode(
      asciiMode: true,
      chineseColor: customChinese,
      asciiColor: customAscii
    )
    #expect(colorsEqual(result, customAscii),
            "colorForMode should return asciiColor when asciiMode is true")
  }

  @Test("colorForMode with default colors returns blue for Chinese mode")
  func defaultColorForChineseMode() {
    let defaultChinese = NSColor(srgbRed: 0, green: 0, blue: 1.0, alpha: 1.0)
    let defaultAscii = NSColor(srgbRed: 1.0, green: 0.647, blue: 0, alpha: 1.0)

    let result = SquirrelIndicator.colorForMode(
      asciiMode: false,
      chineseColor: defaultChinese,
      asciiColor: defaultAscii
    )
    #expect(colorsEqual(result, defaultChinese),
            "colorForMode should return default blue for Chinese mode")
  }

  @Test("colorForMode with default colors returns orange for ASCII mode")
  func defaultColorForAsciiMode() {
    let defaultChinese = NSColor(srgbRed: 0, green: 0, blue: 1.0, alpha: 1.0)
    let defaultAscii = NSColor(srgbRed: 1.0, green: 0.647, blue: 0, alpha: 1.0)

    let result = SquirrelIndicator.colorForMode(
      asciiMode: true,
      chineseColor: defaultChinese,
      asciiColor: defaultAscii
    )
    #expect(colorsEqual(result, defaultAscii),
            "colorForMode should return default orange for ASCII mode")
  }

  @Test("Assigning colors with full alpha (simulating 0xAABBGGRR format)")
  func colorWithFullAlpha() {
    // Simulating a color parsed from 0xAABBGGRR format with alpha
    let colorWithAlpha = NSColor(srgbRed: 0.5, green: 0.3, blue: 0.8, alpha: 0.7)
    let other = NSColor.white

    let result = SquirrelIndicator.colorForMode(
      asciiMode: false,
      chineseColor: colorWithAlpha,
      asciiColor: other
    )

    // Verify the alpha component is preserved
    guard let srgb = result.usingColorSpace(.sRGB) else {
      Issue.record("Failed to convert result color to sRGB")
      return
    }
    #expect(abs(srgb.alphaComponent - 0.7) < 0.001,
            "Alpha component should be preserved from the assigned color")
    #expect(abs(srgb.redComponent - 0.5) < 0.001)
    #expect(abs(srgb.greenComponent - 0.3) < 0.001)
    #expect(abs(srgb.blueComponent - 0.8) < 0.001)
  }

  @Test("Assigning colors without alpha (simulating 0xBBGGRR format, alpha defaults to 1.0)")
  func colorWithoutAlpha() {
    // Simulating a color parsed from 0xBBGGRR format (alpha = 1.0)
    let colorNoAlpha = NSColor(srgbRed: 0.1, green: 0.9, blue: 0.5, alpha: 1.0)
    let other = NSColor.white

    let result = SquirrelIndicator.colorForMode(
      asciiMode: true,
      chineseColor: other,
      asciiColor: colorNoAlpha
    )

    guard let srgb = result.usingColorSpace(.sRGB) else {
      Issue.record("Failed to convert result color to sRGB")
      return
    }
    #expect(abs(srgb.alphaComponent - 1.0) < 0.001,
            "Alpha should be 1.0 for colors from 0xBBGGRR format")
    #expect(abs(srgb.redComponent - 0.1) < 0.001)
    #expect(abs(srgb.greenComponent - 0.9) < 0.001)
    #expect(abs(srgb.blueComponent - 0.5) < 0.001)
  }
}
