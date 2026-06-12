# Cursor Input Indicator — Known Issues / 待修復問題

A code review (2026-06-12) of the fork-only cursor input indicator feature found a set of
genuine defects, confirmed by adversarial verification. They are **not yet fixed** — this
document tracks them so they can be addressed later. None is a crash or data-loss bug; most
are lifecycle, energy, or cosmetic issues. Severity is the verified (post-review) rating.

The 15 raw findings collapse into **9 distinct issues** (several findings described the same
root cause from different angles). Estimated total effort to fix all: **2–4 hours** plus manual
on-device verification of the UI-timing ones.

Files: [`sources/SquirrelIndicator.swift`](../../../sources/SquirrelIndicator.swift),
[`sources/SquirrelInputController.swift`](../../../sources/SquirrelInputController.swift),
[`sources/SquirrelApplicationDelegate.swift`](../../../sources/SquirrelApplicationDelegate.swift),
[`data/squirrel.yaml`](../../../data/squirrel.yaml).

---

## I1 — `mouseTracker` timer runs forever, even when the feature is off  ·  low
*(consolidates raw findings #1, #3, #15)*

`SquirrelIndicator.init()` calls `startMouseTracking()`, which schedules a repeating
`Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true)`. `stopMouseTracking()` is defined
but **has zero callers**, and the class has **no `deinit`**. The indicator is an app-lifetime
singleton, so the timer fires 10×/second for the whole process life — including when
`show_input_indicator` is `false` (the default), where `checkMouseProximity()` just early-returns.
No retain cycle (`[weak self]`), no leak; it's continuous wasted run-loop wakeups (battery/CPU on
a background IME). Minor extra: the timer is added in `.default` mode, so proximity-hiding silently
pauses during modal/tracking loops.

**Fix:** don't start the timer in `init()`. Gate it on `enabled`/visibility — start in
`show()`/`update()` when `enabled`, invalidate via `stopMouseTracking()` in `hide()`/`fadeOut()`.
Add `deinit { stopMouseTracking() }`. Guard against scheduling a second timer if `mouseTracker != nil`.
If proximity-hiding must work during tracking loops, add the timer with
`RunLoop.main.add(timer, forMode: .common)` instead of `scheduledTimer`.

---

## I2 — NotificationCenter observers in `SquirrelInputController` are never removed  ·  medium
*(raw finding #2)*

`init` registers two block-based observers via
`NotificationCenter.default.addObserver(forName:object:queue:using:)` for
`SquirrelSetASCIIModeNotification` and `SquirrelReportASCIIModeNotification`. That API returns an
opaque observer **token** (the real registered observer), and both return values are discarded.
`deinit` only calls `destroySession()`. IMK creates a new controller per client session and
destroys them repeatedly, so the shared `NotificationCenter.default` observer list grows without
bound. `[weak self]` means the leaked closures no-op (no crash), but it's an unbounded registration
leak plus a tiny growing per-post cost.

**Fix:** store both tokens in instance properties (`private var asciiModeObserver: NSObjectProtocol?`,
`private var reportModeObserver: NSObjectProtocol?`), assign them from the `addObserver` calls, and
remove them in `deinit`. Or switch to the target/selector form and `removeObserver(self)` in `deinit`.

---

## I3 — Indicator AppKit update from the C `notificationHandler` is not main-thread-dispatched  ·  medium
*(raw finding #11)*

In the `@convention(c) notificationHandler`, the sibling status-icon update (line ~329) defensively
routes through `updateStatusIcon`, which wraps its AppKit work in `DispatchQueue.main.async`. The
indicator update (line ~317) calls `indicator?.update(...)` **directly** on whatever thread librime
invoked the handler on. `update()` does main-thread-only AppKit work (`setFrame(_:display:)`,
`orderFront`, `NSAnimationContext`). librime can fire notifications off the main thread (e.g. the
deploy path runs via `std::async`), so this can mutate `NSPanel`/`NSView` off-main = undefined behavior.
In the common ascii_mode-toggle flow the message is emitted synchronously on the key-handling thread,
so an actual off-main crash is a latent edge case, not guaranteed — but the path is unprotected while
its twin was deliberately guarded.

**Fix (preferred):** add a main-thread hop inside `SquirrelIndicator.update()` itself —
`if !Thread.isMainThread { DispatchQueue.main.async { self.update(asciiMode: asciiMode, cursorRect: cursorRect) }; return }` —
so every caller is protected. Alternatively wrap the call site at line ~317 in `DispatchQueue.main.async`.

---

## I4 — Disabling the feature at runtime leaves the panel on screen / lets it re-show  ·  medium
*(consolidates raw findings #7, #10, #12, #14)*

`loadSettings()` sets `indicator?.enabled = showIndicator` but, when `showIndicator` is false, never
calls `indicator?.hide()` and never resets `cursorRect`. Compare the status icon, which calls
`refreshStatusItem()` to actually add/remove itself. Two consequences after a focus-preserving
`Squirrel --reload` with the feature toggled off:

1. A currently-visible indicator stays frozen at its last frame/alpha (`update()`, `hide()`,
   `fadeOut()` have **no `enabled` guard**; only `show()` and `checkMouseProximity()` do).
2. The C `notificationHandler` ascii_mode path (line ~317) calls `update()` with **no `enabled`
   guard**, and `update()`'s fade-in branch calls `orderFront(nil)` directly. With a stale non-zero
   `cursorRect`, a later Shift/ascii toggle **re-shows** the disabled indicator.

**Fix:** add `guard enabled else { hide(); return }` at the top of `SquirrelIndicator.update()`
(protects all callers, including the fade-in branch). Plus, in `loadSettings()`, add an
`else { indicator?.hide(); indicator?.cursorRect = .zero }` branch. Optionally also guard the
call site at delegate line ~317 for consistency with the other two call sites.

---

## I5 — Fixed-mode indicator never shows when the client returns a zero cursor rect at activation  ·  medium
*(raw finding #4; affects only `indicator_follow_cursor: false`)*

In fixed mode the indicator is pinned to `indicator.fixedRect`, captured **once** in `activateServer`
from `client?.attributes(forCharacterIndex: 0, lineHeightRectangle:)`. Many IMK clients (terminals,
web/Electron views, not-yet-laid-out fields) return `.zero` there at activation. `fixedRect` is then
stored as `.zero`, and every `rimeUpdate` calls `update(cursorRect: indicator.fixedRect)`, which
begins `if cursorRect == .zero { hide(); return }`. So fixed mode is silently non-functional for a
whole class of apps. Follow-cursor mode (the default) self-heals because it re-reads `inputPos` each
time.

**Fix:** in the fixed-mode branch of `rimeUpdate`, fall back to live `inputPos` when `fixedRect == .zero`,
and lazily seed `fixedRect` the first time a non-zero rect is seen. Also make the `activateServer`
capture conditional: only assign `indicator.fixedRect = inputPos` when `inputPos != .zero`.

---

## I6 — Mouse-proximity restore animation fights `fadeOut()`, leaving the badge stuck over candidates  ·  medium
*(raw finding #13; timing-dependent)*

When candidates appear, `showPanel` calls `fadeOut()` (200 ms alpha→0; completion calls `orderOut`
only if `alphaValue < 0.01`). During that 200 ms `isVisible` is still true, so the timer keeps
running `checkMouseProximity()`. If the cursor had been near the indicator (`isMouseHidden == true`)
and moves away during the fade, the restore branch animates `alphaValue` back to `0.9`, cancelling the
fade-to-0. The stale `fadeOut` completion then sees `alphaValue ≈ 0.9`, skips `orderOut`, and the
indicator is left floating on top of the candidate panel until the next state change. Narrow race, but
the badge sits right at the caret where the pointer often is.

**Fix:** make `fadeOut()` and proximity logic mutually exclusive — in `fadeOut()` call
`stopMouseTracking()` (or set an `isFadingForPanel` flag), reset `isMouseHidden = false`, and call
`orderOut(nil)` unconditionally in the completion handler. Re-arm tracking on next `show()`/`update()`.
Also reset `isMouseHidden` in `hide()` so a fresh show starts clean.

---

## I7 — Indicator `color_space` is read from a non-existent config path  ·  low
*(raw finding #8)*

`loadSettings` reads `config?.getString("style/color_space")`, but `color_space` only ever exists
**per color preset** (e.g. `preset_color_schemes/solarized_light/color_space`), never at
`style/color_space`. So it's always nil → `RimeColorSpace.from(name: "")` → `.sRGB`, and the
`indicator_*_color` keys are always parsed sRGB even under a display_p3 scheme. Dead/wrong lookup.

**Fix:** either drop the lookup and pass `.sRGB` explicitly (matches the sRGB-built defaults), or add
a real `style/indicator_color_space` key (and document it) if display_p3 indicator colors are wanted.

---

## I8 — `calculatePosition` can place a stray badge at (0,0) on a degenerate screen rect  ·  low
*(raw finding #6; very narrow trigger)*

The clamp applies the max-edge correction before the min-edge correction. When `currentScreenRect()`
hits its `?? .zero` fallback (e.g. `NSScreen.main == nil` during display sleep/wake while a non-zero
`cursorRect` is in flight), the result is `NSPoint(0,0)` and a 20×20 badge is placed at the primary-display
origin instead of being suppressed. Transient and cosmetic; outside the property tests' ≥100×100 contract.

**Fix:** in `currentScreenRect()` use `NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero`,
and in `update()` bail out when the screen can't contain the indicator:
`guard screenRect.width >= indicatorSize.width, screenRect.height >= indicatorSize.height else { hide(); return }`.
Add a property-test case asserting suppression (not origin placement) on a `.zero`/sub-20 screen rect.

---

## I9 — Follow-cursor jump threshold is a hardcoded 100 px on `.origin`  ·  low
*(raw finding #5; UX-quality refinement, self-recovering)*

Jump detection uses a literal `100` px on `inputPos.origin` vs `lastPos.origin`. Problems: it compares
`.origin` (so a line-height change can trip the y-threshold), the threshold isn't scaled to line height
(a legitimate newline on large fonts >100 px freezes the badge at the old caret), and a monitor change
yields a huge delta that always trips it (badge pinned on the old monitor until a preedit is typed). The
suppression exists to stop the badge teleporting on Cmd+A/select-all; it degrades gracefully (corrects on
next keystroke).

**Fix:** scale the threshold to line height (e.g. `max(inputPos.height, lastPos.height, 16) * 3`), compare
`midX`/`midY` instead of `.origin`, and add a same-screen guard so a real monitor move re-anchors immediately.

---

## Also noted (not a code bug)

**Config example value wrong** *(raw finding #9, [`data/squirrel.yaml`](../../../data/squirrel.yaml) ~line 51):*
the commented example `indicator_chinese_color: 0x0000FF` parses (BGR) to **red**, contradicting the blue
default. Fix the comment to `0xFFB266` (the BGR encoding of the blue default). The ASCII example `0x00A5FF`
(orange) is correct. Parser is fine; only the example is misleading.

---

## Suggested fix order

1. **I4 + I2 + I3** — the real lifecycle/correctness ones (`enabled` guard in `update()` knocks out most
   of I4; observer cleanup; main-thread hop). Highest value.
2. **I1** — gate the timer on enabled/visibility (pairs naturally with I4's `enabled` work).
3. **I5, I6** — need on-device verification (fixed-mode clients; fade/proximity race).
4. **I7, I8, I9 + the yaml example** — low-priority polish, batch them.
