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

  /// 光标右侧偏移量
  static let offsetX: CGFloat = 2
  /// 光标上方偏移量
  static let offsetY: CGFloat = 2

  /// 正常显示时的透明度
  private static let normalAlpha: CGFloat = 0.85
  /// 候选面板显示时的降低透明度
  private static let dimmedAlpha: CGFloat = 0.3
  /// 动画时长
  private static let animationDuration: TimeInterval = 0.15

  /// 圆角背景视图
  private let backgroundView: NSView
  /// 文字标签
  private let label: NSTextField

  init() {
    let contentRect = NSRect(origin: .zero, size: SquirrelIndicator.indicatorSize)
    backgroundView = NSView(frame: contentRect)
    label = NSTextField(labelWithString: "")
    super.init(contentRect: contentRect, styleMask: .nonactivatingPanel, backing: .buffered, defer: true)
    self.level = .init(Int(CGShieldingWindowLevel()))
    self.ignoresMouseEvents = true
    self.hasShadow = true
    self.isOpaque = false
    self.backgroundColor = .clear
    self.alphaValue = SquirrelIndicator.normalAlpha

    setupBackground()
    setupLabel()
  }

  private func setupBackground() {
    backgroundView.wantsLayer = true
    backgroundView.layer?.cornerRadius = 4
    backgroundView.layer?.masksToBounds = true
    // 半透明深色背景，类似 macOS 系统气泡
    backgroundView.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.75).cgColor
    self.contentView?.addSubview(backgroundView)
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

  /// 根据 asciiMode 选择对应的显示颜色（纯函数，可独立测试）
  nonisolated static func colorForMode(asciiMode: Bool, chineseColor: NSColor, asciiColor: NSColor) -> NSColor {
    asciiMode ? asciiColor : chineseColor
  }

  /// 根据当前 asciiMode 刷新文字标签和颜色
  private func refreshLabel() {
    let text = asciiMode ? "A" : "中"
    let color = SquirrelIndicator.colorForMode(asciiMode: asciiMode, chineseColor: chineseColor, asciiColor: asciiColor)

    label.stringValue = text
    label.textColor = color
    label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)

    // 更新背景色：使用模式颜色的极淡版本叠加在深色底上
    let bgColor = color.withAlphaComponent(0.15)
    backgroundView.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.75).blended(withFraction: 0.3, of: bgColor)?.cgColor
      ?? NSColor(white: 0.1, alpha: 0.75).cgColor
  }

  /// 计算 Indicator 窗口位置（纯函数，可独立测试）
  static func calculatePosition(cursorRect: NSRect, indicatorSize: NSSize, screenRect: NSRect) -> NSPoint {
    var x = cursorRect.maxX + offsetX
    var y = cursorRect.maxY + offsetY

    if x + indicatorSize.width > screenRect.maxX {
      x = screenRect.maxX - indicatorSize.width
    }
    if x < screenRect.minX {
      x = screenRect.minX
    }
    if y + indicatorSize.height > screenRect.maxY {
      y = screenRect.maxY - indicatorSize.height
    }
    if y < screenRect.minY {
      y = screenRect.minY
    }

    return NSPoint(x: x, y: y)
  }

  /// 获取包含光标位置的屏幕 frame
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
    if cursorRect == .zero {
      hide()
      return
    }

    let modeChanged = self.asciiMode != asciiMode
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

    // 模式切换时用动画恢复到正常透明度
    if modeChanged {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = SquirrelIndicator.animationDuration
        self.animator().alphaValue = SquirrelIndicator.normalAlpha
      }
    } else if self.alphaValue < SquirrelIndicator.normalAlpha {
      // 从 dimmed 状态恢复
      NSAnimationContext.runAnimationGroup { context in
        context.duration = SquirrelIndicator.animationDuration
        self.animator().alphaValue = SquirrelIndicator.normalAlpha
      }
    }

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

  /// 降低透明度（候选面板显示时调用，而非完全隐藏）
  func dim() {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = SquirrelIndicator.animationDuration
      self.animator().alphaValue = SquirrelIndicator.dimmedAlpha
    }
  }
}
