//
//  ShiftSwitchBehavior.swift
//  Squirrel
//
//  在中文輸入未上屏時按 Shift 切到英文，未上屏的編碼該怎麼處理。
//  librime 的 AsciiComposer 從 default.yaml 讀 ascii_composer/switch_key，
//  不讀 squirrel.yaml，所以這個選項要落在 ~/Library/Rime/default.custom.yaml 的 patch 裡。
//
//  How to treat an unfinished composition when Shift switches to ASCII mode.
//  librime's AsciiComposer reads ascii_composer/switch_key from default.yaml
//  (never squirrel.yaml), so this setting lands as a patch in default.custom.yaml.
//

import Foundation

/// librime `ascii_composer/switch_key` 支援的取值中，適合掛在 Shift 上的幾種。
/// The subset of librime's `ascii_composer/switch_key` styles that make sense on Shift.
enum ShiftSwitchBehavior: String, CaseIterable, Sendable {
  /// 未選定的編碼原樣以字母上屏，然後切英文。最接近搜狗／微軟的行為。
  /// Commit the raw input as-is, then switch to ASCII. Closest to Sogou/MSPY.
  case commitCode = "commit_code"
  /// 先把當前候選上屏，再切英文（librime 預設在多數配置裡是這個）。
  /// Confirm the current candidate first, then switch to ASCII.
  case commitText = "commit_text"
  /// 進入臨時英文模式，這段打完上屏後自動回中文（單向，不能當雙向開關）。
  /// Temporary ASCII mode; returns to Chinese once the composition commits.
  case inlineAscii = "inline_ascii"
  /// 丟棄未上屏內容，然後切英文。
  /// Discard the composition, then switch to ASCII.
  case clear = "clear"
  /// 屏蔽 Shift，不切中英。
  /// Disable the Shift switch entirely.
  case noop = "noop"

  /// 沒有寫過 patch 時 librime 的實際預設值，見 data/default.yaml。
  /// librime's effective default when no patch is present; see data/default.yaml.
  static let fallback: ShiftSwitchBehavior = .commitCode

  var localizedTitle: String {
    switch self {
    case .commitCode: NSLocalizedString("shift_switch_commit_code", comment: "Shift switch behavior")
    case .commitText: NSLocalizedString("shift_switch_commit_text", comment: "Shift switch behavior")
    case .inlineAscii: NSLocalizedString("shift_switch_inline_ascii", comment: "Shift switch behavior")
    case .clear: NSLocalizedString("shift_switch_clear", comment: "Shift switch behavior")
    case .noop: NSLocalizedString("shift_switch_noop", comment: "Shift switch behavior")
    }
  }
}

/// 讀寫 `~/Library/Rime/default.custom.yaml` 裡的 `ascii_composer/switch_key/Shift_L`。
///
/// 刻意用文本編輯而不是 YAML 序列化：用戶的 default.custom.yaml 通常帶著自己的註釋和
/// 其他 patch，整份讀出再寫回會把註釋和鍵序全部抹掉。這裡只動 Shift_L 那一行。
///
/// 另外注意不要改寫成整個 switch_key map 的 patch —— librime 的 PatchLiteral::Resolve
/// 以 merge_tree: false 套用 patch（見 librime config_compiler.cc），整個 map 是「覆蓋」
/// 而不是「合併」，那樣會靜默清掉用戶的 Caps_Lock / Shift_R 設定。單一葉子路徑才安全。
///
/// Deliberately text-based rather than YAML round-tripping: users' files carry comments
/// and unrelated patches that a parse-and-rewrite would flatten. Only the Shift_L line moves.
///
/// Also note we patch the single leaf path, never the whole switch_key map: librime applies
/// patches with merge_tree: false, so a whole-map patch overwrites rather than merges and
/// would silently drop the user's Caps_Lock / Shift_R bindings.
struct ShiftSwitchConfigFile {
  private static let leafKey = "ascii_composer/switch_key/Shift_L"
  private static let mapKey = "ascii_composer/switch_key"

  let url: URL

  init(url: URL) {
    self.url = url
  }

  /// 從文件裡讀出當前生效的 Shift_L 取值；讀不到（沒文件／沒這個鍵）回 nil。
  /// Read the effective Shift_L value; nil when absent or unparseable.
  func read() -> ShiftSwitchBehavior? {
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    return Self.parse(text)
  }

  /// 把選擇寫回文件，保留其餘內容。寫入前先備份成 `<name>.bak`。
  /// Persist the choice, preserving everything else. Backs up to `<name>.bak` first.
  func write(_ behavior: ShiftSwitchBehavior) throws {
    let original = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    let updated = Self.apply(behavior, to: original)
    if updated == original { return }

    if !original.isEmpty {
      let backup = url.appendingPathExtension("bak")
      try? original.write(to: backup, atomically: true, encoding: .utf8)
    }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try updated.write(to: url, atomically: true, encoding: .utf8)
  }
}

// MARK: - 純文本變換（無 I/O，便於測試）/ Pure text transforms, no I/O, testable

extension ShiftSwitchConfigFile {
  /// 支援兩種書寫形式：展開的 map（`switch_key:` 下縮進一行 `Shift_L:`）
  /// 和單行葉子路徑（`ascii_composer/switch_key/Shift_L: x`）。
  /// Handles both the expanded map form and the single-line leaf-path form.
  static func parse(_ text: String) -> ShiftSwitchBehavior? {
    var insideSwitchKeyMap = false
    var mapIndent = 0

    // 與 apply 用同一種切分方式，免得 CRLF 存檔的文件讀得出卻改不動。
    // Split the same way apply() does, so a CRLF file can't parse-but-fail-to-rewrite.
    for rawLine in text.components(separatedBy: "\n") {
      let line = stripComment(rawLine)
      if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
      let indent = line.prefix { $0 == " " }.count

      // 葉子路徑寫法優先，出現就直接採用。/ Leaf-path form wins outright.
      if let value = value(inLine: line, forKey: leafKey) {
        return ShiftSwitchBehavior(rawValue: value)
      }

      if insideSwitchKeyMap {
        // 縮進退回到 map 這一層或更淺，說明 map 結束了。/ Dedent ends the map.
        if indent <= mapIndent {
          insideSwitchKeyMap = false
        } else if let value = value(inLine: line, forKey: "Shift_L") {
          return ShiftSwitchBehavior(rawValue: value)
        }
      }

      if !insideSwitchKeyMap, isMapHeader(line, key: mapKey) {
        insideSwitchKeyMap = true
        mapIndent = indent
      }
    }
    return nil
  }

  /// 就地改寫已有的取值；沒有現成的鍵就在 `patch:` 下補一行葉子路徑。
  /// Rewrite in place when the key exists; otherwise append a leaf-path line under `patch:`.
  static func apply(_ behavior: ShiftSwitchBehavior, to text: String) -> String {
    var lines = text.components(separatedBy: "\n")
    var insideSwitchKeyMap = false
    var mapIndent = 0

    for (offset, rawLine) in lines.enumerated() {
      let line = stripComment(rawLine)
      if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
      let indent = line.prefix { $0 == " " }.count

      if value(inLine: line, forKey: leafKey) != nil {
        lines[offset] = replaceValue(in: rawLine, with: behavior.rawValue)
        return lines.joined(separator: "\n")
      }

      if insideSwitchKeyMap {
        if indent <= mapIndent {
          insideSwitchKeyMap = false
        } else if value(inLine: line, forKey: "Shift_L") != nil {
          lines[offset] = replaceValue(in: rawLine, with: behavior.rawValue)
          return lines.joined(separator: "\n")
        }
      }

      if !insideSwitchKeyMap, isMapHeader(line, key: mapKey) {
        insideSwitchKeyMap = true
        mapIndent = indent
      }
    }
    return insert(behavior, into: lines)
  }
}

// MARK: - 私有輔助 / Private helpers

private extension ShiftSwitchConfigFile {
  /// 找到頂層 `patch:` 就插在它後面，否則整個補一份最小文件。
  /// Insert after a top-level `patch:`, or synthesize a minimal file.
  static func insert(_ behavior: ShiftSwitchBehavior, into lines: [String]) -> String {
    let entry = "  \(leafKey): \(behavior.rawValue)"
    var lines = lines

    if let patchIndex = lines.firstIndex(where: { stripComment($0).trimmingCharacters(in: .whitespaces) == "patch:" }) {
      lines.insert(entry, at: patchIndex + 1)
      return lines.joined(separator: "\n")
    }

    var body = lines.joined(separator: "\n")
    if !body.isEmpty && !body.hasSuffix("\n") { body += "\n" }
    return body + "patch:\n" + entry + "\n"
  }

  /// 去掉行內註釋，但保留引號裡的 `#`。/ Drop inline comments, respecting quotes.
  static func stripComment(_ line: String) -> String {
    var inSingle = false
    var inDouble = false
    for (index, char) in zip(line.indices, line) {
      switch char {
      case "'" where !inDouble: inSingle.toggle()
      case "\"" where !inSingle: inDouble.toggle()
      case "#" where !inSingle && !inDouble:
        return String(line[line.startIndex..<index])
      default: continue
      }
    }
    return line
  }

  /// 匹配 `key:` 且後面沒有取值（即這是個 map 頭）。/ Match `key:` with no scalar after it.
  /// 用 whitespacesAndNewlines 是為了容忍 CRLF 存檔留下的 `\r`。
  /// Trims newlines too, tolerating a stray `\r` from a CRLF-saved file.
  static func isMapHeader(_ line: String, key: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix(key + ":") else { return false }
    return trimmed.dropFirst(key.count + 1).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// 匹配 `key: value` 並取出 value（去引號）。/ Match `key: value` and unquote.
  static func value(inLine line: String, forKey key: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix(key + ":") else { return nil }
    let raw = trimmed.dropFirst(key.count + 1).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return nil }
    return unquote(String(raw))
  }

  static func unquote(_ value: String) -> String {
    for quote in ["\"", "'"] where value.hasPrefix(quote) && value.hasSuffix(quote) && value.count >= 2 {
      return String(value.dropFirst().dropLast())
    }
    return value
  }

  /// 只換取值，保留原有縮進、鍵名和行尾註釋。
  /// Swap only the value, keeping indentation, key spelling and trailing comment.
  static func replaceValue(in rawLine: String, with value: String) -> String {
    let code = stripComment(rawLine)
    let comment = String(rawLine.dropFirst(code.count))
    // 兩種鍵名（`Shift_L`、`ascii_composer/switch_key/Shift_L`）都不含冒號，
    // 所以第一個冒號就是分隔符，取值裡萬一有冒號也不會被誤切。
    // Neither key form contains a colon, so the first one is the separator.
    guard let separator = code.firstIndex(of: ":") else { return rawLine }

    let key = String(code[code.startIndex...separator])
    let afterColon = code[code.index(after: separator)...]
    let leading = afterColon.prefix { $0 == " " }
    let padding = leading.isEmpty ? " " : String(leading)

    // 舊取值和行尾註釋之間的空格算在 code 這一段裡，要原樣接回去，
    // 否則新取值會和 `#` 黏在一起。
    // The gap between the old value and the trailing comment lives in `code`;
    // carry it over or the new value collides with the `#`.
    let gap = String(afterColon.dropFirst(leading.count).reversed().prefix { $0 == " " }.reversed())
    return key + padding + value + gap + comment
  }
}
