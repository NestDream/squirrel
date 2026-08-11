//
//  ShiftSwitchBehaviorTests.swift
//  Squirrel
//
//  Unit tests for the Shift-switch behavior setting written into default.custom.yaml.
//  Feature: shift-switch-behavior
//

import Testing
import Foundation
@testable import SquirrelCore

// MARK: - 讀取既有配置 / Parsing existing configs

@Suite("ShiftSwitchBehavior parsing")
struct ShiftSwitchParsingTests {
  /// 展開的 map 寫法，也就是用戶手寫 default.custom.yaml 最常見的樣子。
  @Test("reads the expanded map form")
  func expandedMap() {
    let yaml = """
      patch:
        ascii_composer/good_old_caps_lock: true
        ascii_composer/switch_key:
          Shift_L: commit_code
          Shift_R: noop
          Caps_Lock: clear
      """
    #expect(ShiftSwitchConfigFile.parse(yaml) == .commitCode)
  }

  /// 單行葉子路徑寫法，也就是我們自己插進去的樣子。
  @Test("reads the leaf-path form")
  func leafPath() {
    let yaml = """
      patch:
        ascii_composer/switch_key/Shift_L: inline_ascii
      """
    #expect(ShiftSwitchConfigFile.parse(yaml) == .inlineAscii)
  }

  @Test("reads every supported value", arguments: ShiftSwitchBehavior.allCases)
  func everyValue(behavior: ShiftSwitchBehavior) {
    let yaml = "patch:\n  ascii_composer/switch_key/Shift_L: \(behavior.rawValue)\n"
    #expect(ShiftSwitchConfigFile.parse(yaml) == behavior)
  }

  /// 行尾註釋不該被算進取值裡。
  @Test("ignores trailing comments")
  func trailingComment() {
    let yaml = """
      patch:
        ascii_composer/switch_key:
          Shift_L: commit_text   # 左 Shift = 中/英双向切换
      """
    #expect(ShiftSwitchConfigFile.parse(yaml) == .commitText)
  }

  @Test("ignores a commented-out binding")
  func commentedOut() {
    let yaml = """
      patch:
        ascii_composer/switch_key:
          # Shift_L: commit_text
          Shift_R: noop
      """
    #expect(ShiftSwitchConfigFile.parse(yaml) == nil)
  }

  @Test("unquotes values")
  func quoted() {
    let yaml = "patch:\n  ascii_composer/switch_key/Shift_L: \"clear\"\n"
    #expect(ShiftSwitchConfigFile.parse(yaml) == .clear)
  }

  /// Shift_L 出現在別的 map 下面時不能誤讀，例如 key_binder。
  @Test("does not read Shift_L from an unrelated map")
  func unrelatedMap() {
    let yaml = """
      patch:
        key_binder/bindings:
          Shift_L: noop
      """
    #expect(ShiftSwitchConfigFile.parse(yaml) == nil)
  }

  /// 縮進退回頂層後，switch_key 的作用範圍就結束了。
  @Test("stops reading once the map is dedented")
  func dedentEndsMap() {
    let yaml = """
      patch:
        ascii_composer/switch_key:
          Shift_R: noop
        other_section:
          Shift_L: commit_text
      """
    #expect(ShiftSwitchConfigFile.parse(yaml) == nil)
  }

  @Test("returns nil for an empty or unrelated file")
  func noBinding() {
    #expect(ShiftSwitchConfigFile.parse("") == nil)
    #expect(ShiftSwitchConfigFile.parse("patch:\n  style/color_scheme: native\n") == nil)
  }

  @Test("returns nil for an unknown value")
  func unknownValue() {
    #expect(ShiftSwitchConfigFile.parse("patch:\n  ascii_composer/switch_key/Shift_L: bogus\n") == nil)
  }

  /// CRLF 存檔的文件不能只讀得出卻改不動，兩邊必須一致。
  @Test("handles CRLF line endings in both directions")
  func crlf() {
    let yaml = "patch:\r\n  ascii_composer/switch_key:\r\n    Shift_L: commit_text\r\n"
    #expect(ShiftSwitchConfigFile.parse(yaml) == .commitText)

    let out = ShiftSwitchConfigFile.apply(.clear, to: yaml)
    #expect(ShiftSwitchConfigFile.parse(out) == .clear)
    #expect(!out.contains("commit_text"))
  }
}

// MARK: - 改寫配置 / Rewriting configs

@Suite("ShiftSwitchBehavior rewriting")
struct ShiftSwitchRewriteTests {
  /// 核心約束：只有 Shift_L 那一行變，註釋和其他鍵一字不動。
  @Test("changes only the Shift_L line, keeping comments and siblings")
  func preservesEverythingElse() {
    let yaml = """
      # Rime 全局自定义
      patch:
        # 左 Shift 干净地切换中/英
        ascii_composer/good_old_caps_lock: true
        ascii_composer/switch_key:
          Shift_L: commit_text   # 左 Shift = 中/英双向切换
          Shift_R: noop          # 右 Shift 不动作
          Caps_Lock: clear       # Caps Lock 保持原始功能
      """
    let out = ShiftSwitchConfigFile.apply(.commitCode, to: yaml)

    #expect(out.contains("Shift_L: commit_code   # 左 Shift = 中/英双向切换"))
    #expect(!out.contains("commit_text"))
    // 其餘內容原樣保留 / everything else survives verbatim
    #expect(out.contains("# Rime 全局自定义"))
    #expect(out.contains("# 左 Shift 干净地切换中/英"))
    #expect(out.contains("ascii_composer/good_old_caps_lock: true"))
    #expect(out.contains("Shift_R: noop          # 右 Shift 不动作"))
    #expect(out.contains("Caps_Lock: clear       # Caps Lock 保持原始功能"))
    // 行數不變，說明沒有多插 / no line inserted
    #expect(out.components(separatedBy: "\n").count == yaml.components(separatedBy: "\n").count)
  }

  @Test("rewrites the leaf-path form in place")
  func rewritesLeafPath() {
    let yaml = "patch:\n  ascii_composer/switch_key/Shift_L: commit_text\n"
    let out = ShiftSwitchConfigFile.apply(.clear, to: yaml)
    #expect(out == "patch:\n  ascii_composer/switch_key/Shift_L: clear\n")
  }

  /// 已有 patch: 但沒有這個鍵時，插在 patch: 下面而不是新建一份。
  @Test("inserts under an existing patch: block")
  func insertsUnderPatch() {
    let yaml = """
      patch:
        style/color_scheme: native
      """
    let out = ShiftSwitchConfigFile.apply(.commitCode, to: yaml)
    #expect(out.contains("ascii_composer/switch_key/Shift_L: commit_code"))
    #expect(out.contains("style/color_scheme: native"))
    #expect(ShiftSwitchConfigFile.parse(out) == .commitCode)
    // 只能有一個 patch: 頂層鍵 / exactly one top-level patch:
    #expect(out.components(separatedBy: "\n").filter { $0.trimmingCharacters(in: .whitespaces) == "patch:" }.count == 1)
  }

  @Test("creates a minimal file when empty")
  func createsFromEmpty() {
    let out = ShiftSwitchConfigFile.apply(.inlineAscii, to: "")
    #expect(out == "patch:\n  ascii_composer/switch_key/Shift_L: inline_ascii\n")
    #expect(ShiftSwitchConfigFile.parse(out) == .inlineAscii)
  }

  /// 沒有 patch: 的文件（例如只有註釋）要補上 patch: 而不是把鍵扔在頂層。
  @Test("adds a patch: block to a comment-only file")
  func addsPatchBlock() {
    let yaml = "# 我的配置\n"
    let out = ShiftSwitchConfigFile.apply(.noop, to: yaml)
    #expect(out.contains("# 我的配置"))
    #expect(out.contains("patch:"))
    #expect(ShiftSwitchConfigFile.parse(out) == .noop)
  }

  /// 讀寫要對稱：寫進去的值必須讀得回來。
  @Test("round-trips every value", arguments: ShiftSwitchBehavior.allCases)
  func roundTrip(behavior: ShiftSwitchBehavior) {
    let base = """
      patch:
        ascii_composer/switch_key:
          Shift_L: commit_text
          Caps_Lock: clear
      """
    let out = ShiftSwitchConfigFile.apply(behavior, to: base)
    #expect(ShiftSwitchConfigFile.parse(out) == behavior)
    // Caps_Lock 永遠不該被動到 / Caps_Lock is never touched
    #expect(out.contains("Caps_Lock: clear"))
  }

  /// 反覆切換不該讓文件持續膨脹。
  @Test("is idempotent across repeated switches")
  func idempotent() {
    let base = "patch:\n  ascii_composer/switch_key/Shift_L: commit_text\n"
    let once = ShiftSwitchConfigFile.apply(.commitCode, to: base)
    let twice = ShiftSwitchConfigFile.apply(.commitCode, to: once)
    #expect(once == twice)

    let back = ShiftSwitchConfigFile.apply(.commitText, to: once)
    #expect(back == base)
  }
}

// MARK: - 落盤與備份 / Disk round-trip and backup

@Suite("ShiftSwitchConfigFile disk I/O")
struct ShiftSwitchDiskTests {
  private func makeTempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("squirrel-shift-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  @Test("writes and reads back")
  func writeThenRead() throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }

    let file = ShiftSwitchConfigFile(url: dir.appendingPathComponent("default.custom.yaml"))
    #expect(file.read() == nil)

    try file.write(.commitCode)
    #expect(file.read() == .commitCode)

    try file.write(.inlineAscii)
    #expect(file.read() == .inlineAscii)
  }

  /// 覆蓋既有文件前必須留一份 .bak。
  @Test("backs up an existing file before overwriting")
  func backsUp() throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }

    let url = dir.appendingPathComponent("default.custom.yaml")
    let original = "patch:\n  ascii_composer/switch_key/Shift_L: commit_text\n"
    try original.write(to: url, atomically: true, encoding: .utf8)

    try ShiftSwitchConfigFile(url: url).write(.clear)

    let backup = try String(contentsOf: url.appendingPathExtension("bak"), encoding: .utf8)
    #expect(backup == original)
    #expect(ShiftSwitchConfigFile(url: url).read() == .clear)
  }

  /// 值沒變就不該碰文件，也就不該產生 .bak。
  @Test("does not rewrite or back up when the value is unchanged")
  func noopWhenUnchanged() throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }

    let url = dir.appendingPathComponent("default.custom.yaml")
    try "patch:\n  ascii_composer/switch_key/Shift_L: clear\n".write(to: url, atomically: true, encoding: .utf8)

    try ShiftSwitchConfigFile(url: url).write(.clear)

    #expect(!FileManager.default.fileExists(atPath: url.appendingPathExtension("bak").path))
  }

  /// 目錄不存在時要自己建出來（全新安裝的情況）。
  @Test("creates missing parent directories")
  func createsParentDir() throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }

    let nested = dir.appendingPathComponent("Rime", isDirectory: true).appendingPathComponent("default.custom.yaml")
    try ShiftSwitchConfigFile(url: nested).write(.noop)
    #expect(ShiftSwitchConfigFile(url: nested).read() == .noop)
  }
}
