# 需求文档

## 简介

为 macOS 输入法 Squirrel（鼠须管）添加一个光标旁常驻的输入状态指示器功能。该指示器在光标附近始终显示当前输入模式（中文/英文），帮助用户无需切换即可感知当前的 `ascii_mode` 状态。指示器设计为轻量级浮动窗口，跟随光标移动，不干扰正常输入操作，且可通过 `squirrel.yaml` 配置文件开启或关闭。

## 术语表

- **Indicator**: 光标旁常驻的小型浮动窗口，用于显示当前输入模式状态
- **SquirrelPanel**: 已有的浮动候选面板系统，负责候选词展示和光标跟随定位
- **SquirrelInputController**: 基于 InputMethodKit (IMK) 框架的输入控制器，处理按键事件和输入状态管理
- **SquirrelConfig**: 配置解析类，负责从 `squirrel.yaml` 读取和解析配置项
- **SquirrelTheme**: 主题管理类，负责管理面板的视觉样式（颜色、字体、布局等）
- **ascii_mode**: Rime 引擎中的一个 option，`true` 表示英文模式，`false` 表示中文模式
- **notificationHandler**: Rime 引擎的通知回调函数，当 `ascii_mode` 等 option 发生变化时被调用
- **RimeSessionId**: Rime 引擎中标识一个输入会话的唯一 ID

## 需求

### 需求 1：Indicator 的可配置开关

**用户故事：** 作为用户，我希望能通过配置文件控制 Indicator 是否显示，以便根据个人偏好决定是否使用此功能。

#### 验收标准

1. THE SquirrelConfig SHALL 支持从 `squirrel.yaml` 中读取 `style/show_input_indicator` 布尔配置项
2. WHEN `show_input_indicator` 配置项未设置时, THE SquirrelConfig SHALL 将该配置项默认值视为 `false`（不显示 Indicator）
3. WHEN `show_input_indicator` 设置为 `true` 时, THE Indicator SHALL 在光标附近显示当前输入模式
4. WHEN `show_input_indicator` 设置为 `false` 时, THE Indicator SHALL 不显示

### 需求 2：Indicator 的输入模式显示

**用户故事：** 作为用户，我希望 Indicator 能清晰地区分中文模式和英文模式，以便我随时了解当前输入状态。

#### 验收标准

1. WHILE `ascii_mode` 为 `false`（中文模式）时, THE Indicator SHALL 显示中文模式对应的视觉标识
2. WHILE `ascii_mode` 为 `true`（英文模式）时, THE Indicator SHALL 显示英文模式对应的视觉标识
3. THE Indicator SHALL 使用不同的颜色区分中文模式和英文模式
4. THE Indicator SHALL 使用不同的文字标签区分中文模式和英文模式（中文模式显示 "中"，英文模式显示 "A"）

### 需求 3：Indicator 跟随光标定位

**用户故事：** 作为用户，我希望 Indicator 始终出现在光标附近，以便我在不同位置输入时都能方便地查看当前模式。

#### 验收标准

1. THE Indicator SHALL 根据 IMKTextInput 客户端报告的光标位置进行定位
2. WHEN 光标位置发生变化时, THE Indicator SHALL 更新自身位置以跟随光标
3. WHEN Indicator 的计算位置超出当前屏幕边界时, THE Indicator SHALL 调整位置使其完全显示在屏幕范围内
4. THE Indicator SHALL 定位在光标位置的右上方，与光标保持固定的小间距，避免遮挡正在输入的文字

### 需求 4：Indicator 的状态实时更新

**用户故事：** 作为用户，我希望 Indicator 能在我切换输入模式时立即更新显示，以便我获得即时的视觉反馈。

#### 验收标准

1. WHEN notificationHandler 收到 `ascii_mode` 变化的通知时, THE Indicator SHALL 在通知回调内更新显示内容以反映新的输入模式
2. WHEN SquirrelInputController 激活一个新的输入会话时, THE Indicator SHALL 根据该会话的当前 `ascii_mode` 状态显示对应的模式标识
3. WHEN SquirrelInputController 停用输入会话时, THE Indicator SHALL 隐藏

### 需求 5：Indicator 不干扰正常输入

**用户故事：** 作为用户，我希望 Indicator 不会影响我的正常输入操作，以便我能专注于文字输入。

#### 验收标准

1. THE Indicator SHALL 使用 `NSPanel` 的 `nonactivatingPanel` 样式，确保不会获取键盘焦点
2. THE Indicator SHALL 忽略所有鼠标事件，不拦截用户的点击操作
3. WHILE SquirrelPanel 正在显示候选词时, THE Indicator SHALL 隐藏，避免与候选面板产生视觉冲突
4. THE Indicator 的窗口尺寸 SHALL 保持在 20x20 像素以内，确保视觉上的轻量感

### 需求 6：Indicator 的视觉样式可配置

**用户故事：** 作为用户，我希望能自定义 Indicator 的颜色，以便它能与我使用的配色方案协调。

#### 验收标准

1. THE SquirrelConfig SHALL 支持从 `squirrel.yaml` 中读取 `style/indicator_chinese_color` 配置项，用于设置中文模式下 Indicator 的颜色
2. THE SquirrelConfig SHALL 支持从 `squirrel.yaml` 中读取 `style/indicator_ascii_color` 配置项，用于设置英文模式下 Indicator 的颜色
3. WHEN `indicator_chinese_color` 未设置时, THE Indicator SHALL 使用默认的蓝色（`0x0000FF`）作为中文模式颜色
4. WHEN `indicator_ascii_color` 未设置时, THE Indicator SHALL 使用默认的橙色（`0x00A5FF`）作为英文模式颜色
5. THE Indicator SHALL 支持与 SquirrelTheme 相同的颜色格式（`0xAABBGGRR` 或 `0xBBGGRR`）和色彩空间配置

### 需求 7：开源项目文档更新

**用户故事：** 作为开源项目的贡献者和用户，我希望新功能有完整的文档记录，以便其他开发者和用户能了解和使用此功能。

#### 验收标准

1. THE CHANGELOG.md SHALL 新增一条中英双语的功能记录，遵循项目现有的 changelog 格式（中文「主要功能更新」和英文「Major Updates」两段）
2. THE `data/squirrel.yaml` 配置示例文件 SHALL 包含 `show_input_indicator`、`indicator_chinese_color`、`indicator_ascii_color` 等新增配置项及其注释说明
3. WHEN 提交 Pull Request 时, THE PR 描述 SHALL 包含功能说明、配置示例、以及截图或 GIF 演示 Indicator 的效果
