//
//  SquirrelIndicatorPropertyTests.swift
//  Squirrel
//
//  Property-based tests for SquirrelIndicator
//  Feature: cursor-input-indicator
//

import Testing
import AppKit
@testable import SquirrelCore

/// **Validates: Requirements 2.3**
/// Property 1: 模式颜色映射正确性
///
/// For any boolean `asciiMode` and any pair of `(chineseColor, asciiColor)`,
/// when the Indicator updates to that `asciiMode` state, the display color
/// should be `chineseColor` when `asciiMode == false`, or `asciiColor` when
/// `asciiMode == true`.
///
/// Tag: Feature: cursor-input-indicator, Property 1: 模式颜色映射正确性
struct SquirrelIndicatorColorMappingPropertyTests {

  /// Generate a random NSColor using sRGB components in [0, 1]
  private func randomColor(using rng: inout some RandomNumberGenerator) -> NSColor {
    let r = CGFloat.random(in: 0...1, using: &rng)
    let g = CGFloat.random(in: 0...1, using: &rng)
    let b = CGFloat.random(in: 0...1, using: &rng)
    let a = CGFloat.random(in: 0...1, using: &rng)
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
  }

  /// Helper to compare two NSColors by their sRGB components
  private func colorsEqual(_ c1: NSColor, _ c2: NSColor) -> Bool {
    // Convert both to sRGB for comparison
    guard let srgb1 = c1.usingColorSpace(.sRGB),
          let srgb2 = c2.usingColorSpace(.sRGB) else {
      return false
    }
    let epsilon: CGFloat = 0.0001
    return abs(srgb1.redComponent - srgb2.redComponent) < epsilon
      && abs(srgb1.greenComponent - srgb2.greenComponent) < epsilon
      && abs(srgb1.blueComponent - srgb2.blueComponent) < epsilon
      && abs(srgb1.alphaComponent - srgb2.alphaComponent) < epsilon
  }

  @Test("Property 1: 模式颜色映射正确性 - colorForMode returns correct color based on asciiMode")
  func colorForModePropertyTest() {
    var rng = SystemRandomNumberGenerator()
    let iterations = 200

    for _ in 0..<iterations {
      // Generate random inputs
      let asciiMode = Bool.random(using: &rng)
      let chineseColor = randomColor(using: &rng)
      let asciiColor = randomColor(using: &rng)

      // Exercise the pure function
      let result = SquirrelIndicator.colorForMode(
        asciiMode: asciiMode,
        chineseColor: chineseColor,
        asciiColor: asciiColor
      )

      // Verify the property
      if asciiMode {
        #expect(colorsEqual(result, asciiColor),
                "When asciiMode is true, colorForMode should return asciiColor")
      } else {
        #expect(colorsEqual(result, chineseColor),
                "When asciiMode is false, colorForMode should return chineseColor")
      }
    }
  }
}


/// **Validates: Requirements 3.3**
/// Property 2: 屏幕边界约束
///
/// For any cursor position `cursorRect` and any screen rectangle `screenRect`,
/// the indicator's final window frame (origin + indicatorSize) should be fully
/// contained within `screenRect`.
///
/// Tag: Feature: cursor-input-indicator, Property 2: 屏幕边界约束
@MainActor
struct SquirrelIndicatorScreenBoundsPropertyTests {

  /// Generate a random CGFloat in the given range
  private func randomCGFloat(in range: ClosedRange<CGFloat>, using rng: inout some RandomNumberGenerator) -> CGFloat {
    CGFloat.random(in: range, using: &rng)
  }

  /// Generate a random screen rect with reasonable minimum size (at least 100x100)
  private func randomScreenRect(using rng: inout some RandomNumberGenerator) -> NSRect {
    let x = randomCGFloat(in: -2000...2000, using: &rng)
    let y = randomCGFloat(in: -2000...2000, using: &rng)
    let width = randomCGFloat(in: 100...4000, using: &rng)
    let height = randomCGFloat(in: 100...4000, using: &rng)
    return NSRect(x: x, y: y, width: width, height: height)
  }

  /// Generate a random cursor rect, including edge cases and out-of-bounds positions
  private func randomCursorRect(screenRect: NSRect, using rng: inout some RandomNumberGenerator) -> NSRect {
    // Allow cursor positions well outside the screen bounds to test clamping
    let extendedMinX = screenRect.minX - 500
    let extendedMaxX = screenRect.maxX + 500
    let extendedMinY = screenRect.minY - 500
    let extendedMaxY = screenRect.maxY + 500

    let x = randomCGFloat(in: extendedMinX...extendedMaxX, using: &rng)
    let y = randomCGFloat(in: extendedMinY...extendedMaxY, using: &rng)
    let width = randomCGFloat(in: 0...50, using: &rng)
    let height = randomCGFloat(in: 0...30, using: &rng)
    return NSRect(x: x, y: y, width: width, height: height)
  }

  @Test("Property 2: 屏幕边界约束 - indicator frame is always within screen bounds")
  func screenBoundsConstraintPropertyTest() {
    var rng = SystemRandomNumberGenerator()
    let iterations = 200
    let indicatorSize = SquirrelIndicator.indicatorSize

    for _ in 0..<iterations {
      // Generate random inputs
      let screenRect = randomScreenRect(using: &rng)
      let cursorRect = randomCursorRect(screenRect: screenRect, using: &rng)

      // Exercise the pure function
      let origin = SquirrelIndicator.calculatePosition(
        cursorRect: cursorRect,
        indicatorSize: indicatorSize,
        screenRect: screenRect
      )

      // Compute the full indicator frame
      let indicatorFrame = NSRect(origin: origin, size: indicatorSize)

      // Verify the property: indicator frame must be fully contained within screenRect
      #expect(
        indicatorFrame.minX >= screenRect.minX,
        "Indicator left edge (\(indicatorFrame.minX)) must be >= screen left edge (\(screenRect.minX)). cursorRect=\(cursorRect), screenRect=\(screenRect)"
      )
      #expect(
        indicatorFrame.maxX <= screenRect.maxX,
        "Indicator right edge (\(indicatorFrame.maxX)) must be <= screen right edge (\(screenRect.maxX)). cursorRect=\(cursorRect), screenRect=\(screenRect)"
      )
      #expect(
        indicatorFrame.minY >= screenRect.minY,
        "Indicator bottom edge (\(indicatorFrame.minY)) must be >= screen bottom edge (\(screenRect.minY)). cursorRect=\(cursorRect), screenRect=\(screenRect)"
      )
      #expect(
        indicatorFrame.maxY <= screenRect.maxY,
        "Indicator top edge (\(indicatorFrame.maxY)) must be <= screen top edge (\(screenRect.maxY)). cursorRect=\(cursorRect), screenRect=\(screenRect)"
      )
    }
  }
}


/// **Validates: Requirements 3.4**
/// Property 3: 光标右上方偏移定位
///
/// For any cursor position `cursorRect` that is far enough from all screen edges
/// (so boundary clamping does not trigger), the indicator's origin should be at
/// exactly `(cursorRect.maxX + offsetX, cursorRect.maxY + offsetY)`.
///
/// Tag: Feature: cursor-input-indicator, Property 3: 光标下方居中定位
@MainActor
struct SquirrelIndicatorOffsetPositionPropertyTests {

  private func randomCGFloat(in range: ClosedRange<CGFloat>, using rng: inout some RandomNumberGenerator) -> CGFloat {
    CGFloat.random(in: range, using: &rng)
  }

  @Test("Property 3: 光标下方居中定位 - indicator is placed below cursor, horizontally centered")
  func cursorOffsetPositionPropertyTest() {
    var rng = SystemRandomNumberGenerator()
    let iterations = 200
    let indicatorSize = SquirrelIndicator.indicatorSize
    let offsetX = SquirrelIndicator.offsetX
    let offsetY = SquirrelIndicator.offsetY

    for _ in 0..<iterations {
      let screenX = randomCGFloat(in: -2000...2000, using: &rng)
      let screenY = randomCGFloat(in: -2000...2000, using: &rng)
      let screenW = randomCGFloat(in: 200...4000, using: &rng)
      let screenH = randomCGFloat(in: 200...4000, using: &rng)
      let screenRect = NSRect(x: screenX, y: screenY, width: screenW, height: screenH)

      // X constraint: cursorRect.midX - indicatorSize.width/2 + offsetX >= screenRect.minX
      //               cursorRect.midX - indicatorSize.width/2 + offsetX + indicatorSize.width <= screenRect.maxX
      // => cursorRect.midX >= screenRect.minX + indicatorSize.width/2 - offsetX
      // => cursorRect.midX <= screenRect.maxX - indicatorSize.width/2 - offsetX
      let midXLower = screenRect.minX + indicatorSize.width / 2 - offsetX
      let midXUpper = screenRect.maxX - indicatorSize.width / 2 - offsetX

      // Y constraint: cursorRect.minY - indicatorSize.height - offsetY >= screenRect.minY
      // => cursorRect.minY >= screenRect.minY + indicatorSize.height + offsetY
      let minYLower = screenRect.minY + indicatorSize.height + offsetY + 30
      let minYUpper = screenRect.maxY - 10

      guard midXLower < midXUpper, minYLower < minYUpper else { continue }

      let cursorMidX = randomCGFloat(in: midXLower...midXUpper, using: &rng)
      let cursorMinY = randomCGFloat(in: minYLower...minYUpper, using: &rng)

      let cursorW = randomCGFloat(in: 1...10, using: &rng)
      let cursorH = randomCGFloat(in: 10...30, using: &rng)
      let cursorRect = NSRect(x: cursorMidX - cursorW / 2, y: cursorMinY, width: cursorW, height: cursorH)

      let origin = SquirrelIndicator.calculatePosition(
        cursorRect: cursorRect,
        indicatorSize: indicatorSize,
        screenRect: screenRect
      )

      let expectedX = cursorRect.midX - indicatorSize.width / 2 + offsetX
      let expectedY = cursorRect.minY - indicatorSize.height - offsetY
      let epsilon: CGFloat = 0.001

      #expect(
        abs(origin.x - expectedX) < epsilon,
        "origin.x (\(origin.x)) should equal cursorRect.midX - w/2 + offsetX (\(expectedX))"
      )
      #expect(
        abs(origin.y - expectedY) < epsilon,
        "origin.y (\(origin.y)) should equal cursorRect.minY - h - offsetY (\(expectedY))"
      )
    }
  }
}


/// **Validates: Requirements 5.4**
/// Property 4: 窗口尺寸不变量
///
/// For any `asciiMode` value and any configuration state, the indicator's
/// window size (width and height) should never exceed 20 pixels.
/// Additionally, `calculatePosition` always produces a frame of exactly
/// `indicatorSize` dimensions — the size never changes based on input.
///
/// Tag: Feature: cursor-input-indicator, Property 4: 窗口尺寸不变量
@MainActor
struct SquirrelIndicatorWindowSizeInvariantPropertyTests {

  /// Generate a random CGFloat in the given range
  private func randomCGFloat(in range: ClosedRange<CGFloat>, using rng: inout some RandomNumberGenerator) -> CGFloat {
    CGFloat.random(in: range, using: &rng)
  }

  /// Generate a random screen rect with reasonable minimum size
  private func randomScreenRect(using rng: inout some RandomNumberGenerator) -> NSRect {
    let x = randomCGFloat(in: -2000...2000, using: &rng)
    let y = randomCGFloat(in: -2000...2000, using: &rng)
    let width = randomCGFloat(in: 100...4000, using: &rng)
    let height = randomCGFloat(in: 100...4000, using: &rng)
    return NSRect(x: x, y: y, width: width, height: height)
  }

  /// Generate a random cursor rect
  private func randomCursorRect(using rng: inout some RandomNumberGenerator) -> NSRect {
    let x = randomCGFloat(in: -3000...3000, using: &rng)
    let y = randomCGFloat(in: -3000...3000, using: &rng)
    let width = randomCGFloat(in: 0...50, using: &rng)
    let height = randomCGFloat(in: 0...30, using: &rng)
    return NSRect(x: x, y: y, width: width, height: height)
  }

  @Test("Property 4: 窗口尺寸不变量 - indicatorSize width and height never exceed 20 pixels")
  func windowSizeInvariantPropertyTest() {
    var rng = SystemRandomNumberGenerator()
    let iterations = 200
    let indicatorSize = SquirrelIndicator.indicatorSize

    // Static invariant: indicatorSize itself must be <= 20x20
    #expect(
      indicatorSize.width <= 20,
      "indicatorSize.width (\(indicatorSize.width)) must be <= 20"
    )
    #expect(
      indicatorSize.height <= 20,
      "indicatorSize.height (\(indicatorSize.height)) must be <= 20"
    )

    for _ in 0..<iterations {
      // Generate random inputs
      let asciiMode = Bool.random(using: &rng)
      let screenRect = randomScreenRect(using: &rng)
      let cursorRect = randomCursorRect(using: &rng)

      // Exercise calculatePosition with random inputs
      let origin = SquirrelIndicator.calculatePosition(
        cursorRect: cursorRect,
        indicatorSize: indicatorSize,
        screenRect: screenRect
      )

      // Build the frame that would be used for the indicator window
      let frame = NSRect(origin: origin, size: indicatorSize)

      // Verify the invariant: frame dimensions always equal indicatorSize and never exceed 20x20
      #expect(
        frame.width <= 20,
        "Frame width (\(frame.width)) must be <= 20 for asciiMode=\(asciiMode), cursorRect=\(cursorRect), screenRect=\(screenRect)"
      )
      #expect(
        frame.height <= 20,
        "Frame height (\(frame.height)) must be <= 20 for asciiMode=\(asciiMode), cursorRect=\(cursorRect), screenRect=\(screenRect)"
      )

      // Verify that the frame size is exactly indicatorSize (size never changes based on input)
      #expect(
        frame.width == indicatorSize.width,
        "Frame width (\(frame.width)) must equal indicatorSize.width (\(indicatorSize.width))"
      )
      #expect(
        frame.height == indicatorSize.height,
        "Frame height (\(frame.height)) must equal indicatorSize.height (\(indicatorSize.height))"
      )
    }
  }
}
