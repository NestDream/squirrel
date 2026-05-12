# 实现计划：光标输入状态指示器 (Cursor Input Indicator)

## 概述

为 Squirrel（鼠须管）输入法新增一个轻量级的光标旁常驻输入状态指示器。实现采用 Swift，遵循现有项目架构模式（参考 `SquirrelPanel`），以最小侵入方式集成到现有代码中。

## 任务

- [x] 1. 创建 SquirrelIndicator 核心组件
  - [x] 1.1 创建 `sources/SquirrelIndicator.swift` 文件，实现 `SquirrelIndicator` 类
    - 继承 `NSPanel`，使用 `nonactivatingPanel` 样式、`buffered` backing
    - 设置窗口级别为 `CGShieldingWindowLevel`（与 `SquirrelPanel` 一致）
    - 设置 `ignoresMouseEvents = true`，`hasShadow = false`，`isOpaque = false`，`backgroundColor = .clear`
    - 定义属性：`asciiMode: Bool`、`enabled: Bool`、`chineseColor: NSColor`、`asciiColor: NSColor`、`cursorRect: NSRect`
    - 窗口尺寸固定为 20x20 像素以内
    - _需求: 5.1, 5.2, 5.4_

  - [x] 1.2 实现 Indicator 的文字标签绘制逻辑
    - 使用 `NSTextField` 或 Core Graphics 绘制文字标签
    - 中文模式（`asciiMode == false`）显示 "中"，英文模式（`asciiMode == true`）显示 "A"
    - 根据当前 `asciiMode` 状态选择对应颜色（`chineseColor` 或 `asciiColor`）
    - _需求: 2.1, 2.2, 2.3, 2.4_

  - [x] 1.3 实现 `update(asciiMode:cursorRect:)` 方法
    - 更新 `asciiMode` 和 `cursorRect` 属性
    - 刷新文字标签和颜色
    - 计算窗口位置：光标右上方，保持固定小间距偏移
    - 处理屏幕边界约束：获取包含光标位置的屏幕 frame，确保窗口完全在屏幕内
    - 处理零矩形光标位置：隐藏 Indicator
    - 参考 `SquirrelPanel` 的 `currentScreen()` 逻辑处理多显示器
    - _需求: 3.1, 3.2, 3.3, 3.4_

  - [x] 1.4 实现 `show()` 和 `hide()` 方法
    - `show()` 调用 `orderFront(nil)` 显示窗口（仅在 `enabled` 为 `true` 时）
    - `hide()` 调用 `orderOut(nil)` 隐藏窗口
    - _需求: 1.3, 1.4_


  - [x] 1.5 为 SquirrelIndicator 编写 Property 测试：模式颜色映射正确性
    - **Property 1: 模式颜色映射正确性**
    - 生成随机 `asciiMode` 布尔值和随机颜色对，验证 `asciiMode == false` 时使用 `chineseColor`，`asciiMode == true` 时使用 `asciiColor`
    - 使用 swift-testing 框架，运行至少 100 次迭代
    - **验证需求: 2.3**

  - [x] 1.6 为 SquirrelIndicator 编写 Property 测试：屏幕边界约束
    - **Property 2: 屏幕边界约束**
    - 生成随机 `cursorRect`（包括屏幕边缘和超出边界的位置）和随机 `screenRect`，验证最终 frame 完全在屏幕内
    - **验证需求: 3.3**

  - [x] 1.7 为 SquirrelIndicator 编写 Property 测试：光标右上方偏移定位
    - **Property 3: 光标右上方偏移定位**
    - 生成随机 `cursorRect`（限制在屏幕内部足够远的位置），验证 Indicator 在光标右上方固定偏移处
    - **验证需求: 3.4**

  - [x] 1.8 为 SquirrelIndicator 编写 Property 测试：窗口尺寸不变量
    - **Property 4: 窗口尺寸不变量**
    - 生成随机 `asciiMode` 和随机配置，验证窗口尺寸 width 和 height 均不超过 20 像素
    - **验证需求: 5.4**

- [x] 2. 检查点 - 确认 SquirrelIndicator 核心组件
  - 确保所有测试通过，如有疑问请询问用户。

- [x] 3. 集成配置读取与 SquirrelApplicationDelegate
  - [x] 3.1 修改 `sources/SquirrelApplicationDelegate.swift`，新增 `indicator` 属性
    - 在 `SquirrelApplicationDelegate` 中添加 `var indicator: SquirrelIndicator?` 属性
    - 在 `applicationWillFinishLaunching` 中初始化 `indicator = SquirrelIndicator()`
    - 在 `applicationWillTerminate` 中调用 `indicator?.hide()`
    - _需求: 1.1, 1.2_

  - [x] 3.2 修改 `loadSettings()` 方法，读取 Indicator 相关配置
    - 从 `SquirrelConfig` 读取 `style/show_input_indicator` 布尔值，默认 `false`
    - 设置 `indicator?.enabled` 属性
    - 当启用时，读取 `style/indicator_chinese_color` 和 `style/indicator_ascii_color`
    - 使用 `config?.getColor(_:inSpace:)` 方法解析颜色，复用现有色彩空间配置
    - 未配置颜色时使用默认值：蓝色 `NSColor(srgbRed: 0, green: 0, blue: 1.0, alpha: 1.0)` 和橙色 `NSColor(srgbRed: 1.0, green: 0.647, blue: 0, alpha: 1.0)`
    - _需求: 1.1, 1.2, 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 3.3 为配置读取编写单元测试
    - 测试 `show_input_indicator` 为 `true`/`false`/未设置时的行为
    - 测试未配置颜色时使用默认蓝色和橙色
    - 测试颜色格式解析（`0xBBGGRR` 和 `0xAABBGGRR`）
    - _需求: 1.1, 1.2, 6.3, 6.4, 6.5_

- [x] 4. 集成 SquirrelInputController
  - [x] 4.1 修改 `sources/SquirrelInputController.swift` 的 `rimeUpdate()` 方法
    - 在获取 status 和 ctx 之后，当 `indicator.enabled` 为 `true` 时：
    - 通过 `client?.attributes(forCharacterIndex: 0, lineHeightRectangle:)` 获取光标位置
    - 通过 `rimeAPI.get_option(session, "ascii_mode")` 获取当前模式
    - 调用 `indicator.update(asciiMode:cursorRect:)` 更新 Indicator
    - _需求: 3.1, 3.2, 4.1_

  - [x] 4.2 修改 `showPanel(...)` 方法，候选面板显示时隐藏 Indicator
    - 当 `candidates.count > 0` 时调用 `NSApp.squirrelAppDelegate.indicator?.hide()`
    - _需求: 5.3_

  - [x] 4.3 修改 `activateServer(_:)` 方法，激活会话时显示 Indicator
    - 获取当前 `ascii_mode` 状态和光标位置
    - 调用 `indicator.update(asciiMode:cursorRect:)` 显示 Indicator
    - _需求: 4.2_

  - [x] 4.4 修改 `deactivateServer(_:)` 方法，停用会话时隐藏 Indicator
    - 在现有代码之前调用 `NSApp.squirrelAppDelegate.indicator?.hide()`
    - _需求: 4.3_

  - [x] 4.5 修改 `hidePalettes()` 方法
    - 在隐藏候选面板的同时隐藏 Indicator（如果候选面板不再显示，恢复 Indicator 的逻辑已在 `rimeUpdate` 中处理）
    - _需求: 5.3_

- [x] 5. 集成 notificationHandler
  - [x] 5.1 修改 `sources/SquirrelApplicationDelegate.swift` 中的 `notificationHandler` 函数
    - 在 `messageType == "option"` 分支中，检测 `ascii_mode` 或 `!ascii_mode` 变化
    - 调用 `delegate.indicator?.update(asciiMode:cursorRect:)` 更新 Indicator 状态
    - 使用 Indicator 当前保存的 `cursorRect`（位置不变，仅更新模式）
    - _需求: 4.1_

  - [x] 5.2 为通知回调流程编写集成测试
    - 模拟 `notificationHandler` 收到 `ascii_mode` 变化，验证 Indicator 状态更新
    - 测试完整生命周期：`activateServer` → 切换模式 → 显示候选 → 隐藏 Indicator → 候选消失 → 恢复 Indicator → `deactivateServer`
    - _需求: 4.1, 4.2, 4.3, 5.3_

- [x] 6. 检查点 - 确认集成功能
  - 确保所有测试通过，如有疑问请询问用户。

- [x] 7. 更新配置示例与文档
  - [x] 7.1 更新 `data/squirrel.yaml`，添加 Indicator 配置项
    - 在 `style:` 段落中添加 `show_input_indicator`、`indicator_chinese_color`、`indicator_ascii_color` 配置项及注释说明
    - _需求: 7.2_

  - [x] 7.2 更新 `CHANGELOG.md`，添加功能记录
    - 在最新版本段落中新增中英双语功能记录，遵循项目现有 changelog 格式
    - 中文：「新增光标旁输入状态指示器，以 `style/show_input_indicator: true/false` 控制」
    - 英文：「Add cursor input indicator to show current input mode near cursor」
    - _需求: 7.1_

- [x] 8. 最终检查点 - 确保所有测试通过
  - 确保所有测试通过，如有疑问请询问用户。

## 备注

- 标记 `*` 的任务为可选任务，可跳过以加速 MVP 开发
- 每个任务引用了具体的需求编号，确保可追溯性
- 检查点任务用于阶段性验证，确保增量开发的正确性
- Property 测试验证设计文档中定义的正确性属性
- 单元测试验证具体示例和边界情况
