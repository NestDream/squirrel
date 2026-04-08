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
    let path = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
    bgColor.setFill()
    path.fill()

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
  private(set) var asciiMode: Bool = false
  var enabled: Bool = false
  /// 是否跟随光标（true=跟随光标，false=固定在第一个字前面）
  var followCursor: Bool = true
  var chineseColor: NSColor = NSColor(srgbRed: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
  var asciiColor: NSColor = NSColor(srgbRed: 1.0, green: 0.647, blue: 0, alpha: 1.0)
  var cursorRect: NSRect = .zero
  /// 固定模式下记录的初始位置（activateServer 时设置）
  var fixedRect: NSRect = .zero

  static let indicatorSize = NSSize(width: 20, height: 20)
  static let offsetX: CGFloat = 0
  static let offsetY: CGFloat = 2

  private static let normalAlpha: CGFloat = 0.9
  private static let animationDuration: TimeInterval = 0.2
  /// 鼠标靠近时的检测半径
  private static let mouseProximityRadius: CGFloat = 30

  private let contentDrawView: IndicatorContentView
  /// 鼠标接近检测定时器
  private var mouseTracker: Timer?
  /// 当前是否因鼠标靠近而隐藏
  private var isMouseHidden: Bool = false

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
    startMouseTracking()
  }

  /// 停止鼠标追踪
  func stopMouseTracking() {
    mouseTracker?.invalidate()
    mouseTracker = nil
  }

  /// 启动鼠标接近检测
  private func startMouseTracking() {
    mouseTracker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.checkMouseProximity()
    }
  }

  /// 检测鼠标是否靠近 indicator
  private func checkMouseProximity() {
    guard isVisible, enabled else { return }
    let mouseLocation = NSEvent.mouseLocation
    let indicatorCenter = NSPoint(x: frame.midX, y: frame.midY)
    let dx = mouseLocation.x - indicatorCenter.x
    let dy = mouseLocation.y - indicatorCenter.y
    let distance = sqrt(dx * dx + dy * dy)

    if distance < SquirrelIndicator.mouseProximityRadius {
      if !isMouseHidden {
        isMouseHidden = true
        NSAnimationContext.runAnimationGroup { context in
          context.duration = SquirrelIndicator.animationDuration
          self.animator().alphaValue = 0.1
        }
      }
    } else {
      if isMouseHidden {
        isMouseHidden = false
        NSAnimationContext.runAnimationGroup { context in
          context.duration = SquirrelIndicator.animationDuration
          self.animator().alphaValue = SquirrelIndicator.normalAlpha
        }
      }
    }
  }

  nonisolated static func colorForMode(asciiMode: Bool, chineseColor: NSColor, asciiColor: NSColor) -> NSColor {
    asciiMode ? asciiColor : chineseColor
  }

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

  private func currentScreenRect() -> NSRect {
    var rect = NSScreen.main?.visibleFrame ?? .zero
    for screen in NSScreen.screens where screen.frame.contains(cursorRect.origin) {
      rect = screen.visibleFrame
      break
    }
    return rect
  }

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

    // 淡入显示（如果之前被隐藏或淡出）
    if !isMouseHidden && self.alphaValue < SquirrelIndicator.normalAlpha {
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

  func show() {
    guard enabled else { return }
    if !isMouseHidden {
      self.alphaValue = SquirrelIndicator.normalAlpha
    }
    orderFront(nil)
  }

  func hide() {
    self.alphaValue = 0
    orderOut(nil)
  }

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
