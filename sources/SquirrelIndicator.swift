//
//  SquirrelIndicator.swift
//  Squirrel
//
//  Created by Kiro on 2025/01/01.
//

import AppKit

/// 自定义绘制视图，精确控制文字垂直居中
private class IndicatorContentView: NSView {
  var text: String = "中"
  var textColor: NSColor = .white
  var bgColor: NSColor = NSColor(srgbRed: 0.4, green: 0.7, blue: 1.0, alpha: 0.85)
  var font: NSFont = NSFont.systemFont(ofSize: 11, weight: .semibold)

  override func draw(_ dirtyRect: NSRect) {
    // 绘制圆角背景
    let path = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
    bgColor.setFill()
    path.fill()

    // 绘制居中文字
    let attrs: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: textColor,
    ]
    let size = (text as NSString).size(withAttributes: attrs)
    let x = (bounds.width - size.width) / 2
    let y = (bounds.height - size.height) / 2
    (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
  }
}

final class SquirrelIndicator: NSPanel {
  /// 当前是否为 ASCII 模式
  private(set) var asciiMode: Bool = false

  /// 是否启用 Indicator
  var enabled: Bool = false

  /// 中文模式颜色（默认淡蓝色）
  var chineseColor: NSColor = NSColor(srgbRed: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)

  /// 英文模式颜色（默认橙色）
  var asciiColor: NSColor = NSColor(srgbRed: 1.0, green: 0.647, blue: 0, alpha: 1.0)

  /// 光标位置
  var cursorRect: NSRect = .zero

  /// Indicator 窗口固定尺寸
  static let indicatorSize = NSSize(width: 20, height: 20)

  /// 水平偏移量
  static let offsetX: CGFloat = 0
  /// 光标下方偏移量
  static let offsetY: CGFloat = 2

  /// 正常显示时的透明度
  private static let normalAlpha: CGFloat = 0.9
  /// 动画时长
  private static let animationDuration: TimeInterval = 0.2

  /// 自定义绘制视图
  private let contentDrawView: IndicatorContentView

  init() {
    let contentRect = NSRect(origin: .zero, size: SquirrelIndicator.indicatorSize)
    contentDrawView = IndicatorContentView(frame: contentRect)
    super.init(contentRect: contentRect, styleMask: .nonactivatingPanel, backing: .buffered, defer: true)
    self.level = .init(Int(CGShieldingWindowLevel()))
    self.ignoresMouseEvents = true
    self.hasShadow = true
    self.isOpaque = false
    self.backgroundColor = .clear
    self.alphaValue = SquirrelIndicator.normalAlpha

    self.contentView?.addSubview(contentDrawView)
    refreshLabel()
  }

  /// 根据 asciiMode 选择对应的显示颜色（纯函数，可独立测试）
  nonisolated static func colorForMode(asciiMode: Bool, chineseColor: NSColor, asciiColor: NSColor) -> NSColor {
    asciiMode ? asciiColor : chineseColor
  }

  /// 根据当前 asciiMode 刷新绘制内容
  private func refreshLabel() {
    let modeColor = SquirrelIndicator.colorForMode(asciiMode: asciiMode, chineseColor: chineseColor, asciiColor: asciiColor)
    contentDrawView.text = asciiMode ? "A" : "中"
    contentDrawView.textColor = .white
    contentDrawView.bgColor = modeColor.withAlphaComponent(0.85)
    contentDrawView.font = asciiMode
      ? NSFont.systemFont(ofSize: 12, weight: .bold)
      : NSFont.systemFont(ofSize: 12, weight: .semibold)
    contentDrawView.needsDisplay = true
  }

  /// 计算 Indicator 窗口位置（纯函数，可独立测试）
  /// 放在光标正下方，水平居中对齐
  static func calculatePosition(cursorRect: NSRect, indicatorSize: NSSize, screenRect: NSRect) -> NSPoint {
    var x = cursorRect.midX - indicatorSize.width / 2 + offsetX
    var y = cursorRect.minY - indicatorSize.height - offsetY

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

    // 淡入显示
    if self.alphaValue < SquirrelIndicator.normalAlpha {
      self.alphaValue = 0
      orderFront(nil)
      NSAnimationContext.runAnimationGroup { context in
        context.duration = SquirrelIndicator.animationDuration
        self.animator().alphaValue = SquirrelIndicator.normalAlpha
      }
    } else {
      show()
    }
  }

  /// 显示 Indicator（仅在 enabled 为 true 时）
  func show() {
    guard enabled else { return }
    self.alphaValue = SquirrelIndicator.normalAlpha
    orderFront(nil)
  }

  /// 隐藏 Indicator（立即）
  func hide() {
    self.alphaValue = 0
    orderOut(nil)
  }

  /// 带动画淡出隐藏 Indicator
  func fadeOut() {
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = SquirrelIndicator.animationDuration
      self.animator().alphaValue = 0
    }, completionHandler: {
      if self.alphaValue < 0.01 {
        self.orderOut(nil)
      }
    })
  }
}
