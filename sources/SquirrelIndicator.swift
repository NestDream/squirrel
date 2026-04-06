//
//  SquirrelIndicator.swift
//  Squirrel
//
//  Created by Kiro on 2025/01/01.
//

import AppKit

final class SquirrelIndicator: NSPanel {
  /// 当前是否为 ASCII 模式
  private(set) var asciiMode: Bool = false

  /// 是否启用 Indicator
  var enabled: Bool = false

  /// 中文模式颜色（默认蓝色）
  var chineseColor: NSColor = NSColor(srgbRed: 0, green: 0, blue: 1.0, alpha: 1.0)

  /// 英文模式颜色（默认橙色）
  var asciiColor: NSColor = NSColor(srgbRed: 1.0, green: 0.647, blue: 0, alpha: 1.0)

  /// 光标位置
  var cursorRect: NSRect = .zero

  /// Indicator 窗口固定尺寸
  static let indicatorSize = NSSize(width: 20, height: 20)

  /// 文字标签
  private let label: NSTextField

  init() {
    let contentRect = NSRect(origin: .zero, size: SquirrelIndicator.indicatorSize)
    label = NSTextField(labelWithString: "")
    super.init(contentRect: contentRect, styleMask: .nonactivatingPanel, backing: .buffered, defer: true)
    self.level = .init(Int(CGShieldingWindowLevel()))
    self.ignoresMouseEvents = true
    self.hasShadow = false
    self.isOpaque = false
    self.backgroundColor = .clear

    setupLabel()
  }

  private func setupLabel() {
    label.isBezeled = false
    label.drawsBackground = false
    label.isEditable = false
    label.isSelectable = false
    label.alignment = .center
    label.frame = NSRect(origin: .zero, size: SquirrelIndicator.indicatorSize)
    self.contentView?.addSubview(label)
    refreshLabel()
  }

  /// 光标右侧偏移量
  static let offsetX: CGFloat = 2
  /// 光标上方偏移量
  static let offsetY: CGFloat = 2

  /// 根据 asciiMode 选择对应的显示颜色（纯函数，可独立测试）
  /// - Parameters:
  ///   - asciiMode: 是否为 ASCII 模式
  ///   - chineseColor: 中文模式颜色
  ///   - asciiColor: 英文模式颜色
  /// - Returns: 当前模式对应的颜色
  nonisolated static func colorForMode(asciiMode: Bool, chineseColor: NSColor, asciiColor: NSColor) -> NSColor {
    asciiMode ? asciiColor : chineseColor
  }

  /// 根据当前 asciiMode 刷新文字标签和颜色
  private func refreshLabel() {
    label.stringValue = asciiMode ? "A" : "中"
    label.textColor = SquirrelIndicator.colorForMode(asciiMode: asciiMode, chineseColor: chineseColor, asciiColor: asciiColor)
    label.font = NSFont.boldSystemFont(ofSize: 12)
  }

  /// 计算 Indicator 窗口位置（纯函数，可独立测试）
  /// - Parameters:
  ///   - cursorRect: 光标矩形（屏幕坐标）
  ///   - indicatorSize: Indicator 窗口尺寸
  ///   - screenRect: 屏幕可见区域
  /// - Returns: Indicator 窗口的 origin 点
  static func calculatePosition(cursorRect: NSRect, indicatorSize: NSSize, screenRect: NSRect) -> NSPoint {
    // 默认位置：光标右上方，带小间距偏移
    var x = cursorRect.maxX + offsetX
    var y = cursorRect.maxY + offsetY

    // 屏幕右边界约束
    if x + indicatorSize.width > screenRect.maxX {
      x = screenRect.maxX - indicatorSize.width
    }
    // 屏幕左边界约束
    if x < screenRect.minX {
      x = screenRect.minX
    }
    // 屏幕上边界约束
    if y + indicatorSize.height > screenRect.maxY {
      y = screenRect.maxY - indicatorSize.height
    }
    // 屏幕下边界约束
    if y < screenRect.minY {
      y = screenRect.minY
    }

    return NSPoint(x: x, y: y)
  }

  /// 获取包含光标位置的屏幕 frame（参考 SquirrelPanel.currentScreen()）
  private func currentScreenRect() -> NSRect {
    var rect = NSScreen.main?.visibleFrame ?? .zero
    for screen in NSScreen.screens where screen.frame.contains(cursorRect.origin) {
      rect = screen.visibleFrame
      break
    }
    return rect
  }

  /// 更新输入模式并刷新显示
  func update(asciiMode: Bool, cursorRect: NSRect) {
    // 零矩形光标位置：隐藏 Indicator
    if cursorRect == .zero {
      hide()
      return
    }

    self.asciiMode = asciiMode
    self.cursorRect = cursorRect
    refreshLabel()

    let screenRect = currentScreenRect()
    let origin = SquirrelIndicator.calculatePosition(
      cursorRect: cursorRect,
      indicatorSize: SquirrelIndicator.indicatorSize,
      screenRect: screenRect
    )
    let frame = NSRect(origin: origin, size: SquirrelIndicator.indicatorSize)
    setFrame(frame, display: true)
    show()
  }

  /// 显示 Indicator（仅在 enabled 为 true 时）
  func show() {
    guard enabled else { return }
    orderFront(nil)
  }

  /// 隐藏 Indicator
  func hide() {
    orderOut(nil)
  }
}
