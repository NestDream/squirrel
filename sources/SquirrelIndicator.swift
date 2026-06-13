//
//  SquirrelIndicator.swift
//  Squirrel
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
  /// 候選面板淡出期間，停止鄰近邏輯與其爭用 alpha / suppress proximity logic during panel fade-out
  private var isFadingForPanel: Bool = false

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

  deinit {
    stopMouseTracking()
  }

  /// 停止鼠标追踪
  func stopMouseTracking() {
    mouseTracker?.invalidate()
    mouseTracker = nil
  }

  /// 启动鼠标接近检测
  private func startMouseTracking() {
    // I1: 避免重複排程，且僅在啟用時才啟動計時器 / don't double-schedule; gate on enabled
    guard enabled, mouseTracker == nil else { return }
    let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.checkMouseProximity()
    }
    // I1: 以 .common 模式保持在模態／追蹤迴圈中持續觸發 / keep firing during modal/tracking loops
    RunLoop.main.add(timer, forMode: .common)
    mouseTracker = timer
  }

  /// 检测鼠标是否靠近 indicator
  private func checkMouseProximity() {
    // I6: 面板淡出期間停止鄰近邏輯，避免與淡出爭用 alpha / bail during panel fade-out
    guard isVisible, enabled, !isFadingForPanel else { return }
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
    var rect = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
    for screen in NSScreen.screens where screen.frame.contains(cursorRect.origin) {
      rect = screen.visibleFrame
      break
    }
    return rect
  }

  func update(asciiMode: Bool, cursorRect: NSRect) {
    // I3: 確保所有 AppKit 操作在主執行緒 / hop to main before any AppKit work
    if !Thread.isMainThread {
      DispatchQueue.main.async { self.update(asciiMode: asciiMode, cursorRect: cursorRect) }
      return
    }
    // I4: 停用時一律隱藏，保護所有呼叫者（含淡入分支）/ disabled → always hide
    guard enabled else {
      hide()
      return
    }
    if cursorRect == .zero {
      hide()
      return
    }

    self.asciiMode = asciiMode
    self.cursorRect = cursorRect
    refreshLabel()

    let screenRect = currentScreenRect()
    // I8: 螢幕無法容納指示器時抑制顯示，而非定位到 (0,0) / suppress on degenerate screen
    guard screenRect.width >= SquirrelIndicator.indicatorSize.width,
          screenRect.height >= SquirrelIndicator.indicatorSize.height else {
      hide()
      return
    }
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
      startMouseTracking()   // I1/I6: 顯示時重新啟動鄰近追蹤 / re-arm proximity tracking on show
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
    startMouseTracking()   // I1: 僅在顯示時才延遲啟動 10Hz 鄰近計時器 / lazily start the 10Hz proximity timer only while shown
  }

  func hide() {
    stopMouseTracking()        // I1: 未顯示時停止計時器 / stop the timer when not shown
    isMouseHidden = false      // I6: 重置狀態，下次顯示乾淨開始 / reset so a fresh show starts clean
    isFadingForPanel = false   // I6: 清除面板淡出旗標 / clear panel-fade flag
    self.alphaValue = 0
    orderOut(nil)
  }

  func fadeOut() {
    // I1/I6: 停止鄰近追蹤避免還原動畫與此淡出爭用，並重置狀態使完成時必定 orderOut
    // stop proximity tracking so a restore animation can't fight this fade, and reset
    // proximity state so completion always orders out.
    stopMouseTracking()
    isMouseHidden = false
    isFadingForPanel = true
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = SquirrelIndicator.animationDuration
      self.animator().alphaValue = 0
    }, completionHandler: {
      self.isFadingForPanel = false
      self.orderOut(nil)   // I6: 無條件 orderOut，不再被鄰近邏輯可能改動的 alpha 阻擋 / unconditional
    })
  }
}
