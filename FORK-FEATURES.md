Read this before merging upstream. Every item must still work after the merge.

# Fork features

What `djnesmith/herdr-notch` changes from `advpropsys/herdr-notch`. The list comes from
`git log upstream/main..djnesmith`. Rule: every change adds its entry here and a line to the
fork block at the top of `README.md`, in the same commit.

After a merge, run `swift test`, then `./build.sh /Applications` and
`"/Applications/Herdr Notch.app/Contents/MacOS/HerdrNotch" --dump`, then the checks below.
Upstream has no updater and no network code, so there is nothing to remove for that rule.

## Security

### 1. David's signing identity and bundle ID
`build.sh` signs with `$SIGN_IDENTITY`, else this Mac's one "Apple Development" identity (it stops if
it finds none or several), with the hardened runtime, instead of upstream's ad hoc signature.
Upstream ignores a failed signature (`|| true`); here a failed signature stops the build. The bundle ID is `com.djnesmith.herdr-notch`. No entitlements.
`SIGN_IDENTITY=- ./build.sh` still gives an ad hoc build. Install with `./build.sh /Applications`.
- Files: `build.sh`, `Support/Info.plist`
- Check: `codesign -dv --verbose=2 "/Applications/Herdr Notch.app"` shows
  `Identifier=com.djnesmith.herdr-notch`, `TeamIdentifier=` your team (read it with `codesign -dv`) and `flags=0x10000(runtime)`.

## Features

### 2. Terminal herdr as a source
Upstream reads the desktop Herdr app's herdr-core (`hc`, `herdr-app`). Agents run in terminal herdr
(the `herdr` TUI) live in a separate server that `hc` never lists. Each poll now tries terminal herdr
first and uses the desktop app only when it doesn't answer. Upstream's source still works as before.
- Reads only, with fixed arguments and no shell: `herdr agent list` and `herdr workspace list` every 3 s,
  and `herdr agent read <pane> --lines 20` every 2 s while a detail card is open. A click runs
  `herdr workspace focus <id>` and then `herdr agent focus <pane>`. It never sends keys or text, and it
  never creates or closes anything. The binary is `/opt/homebrew/bin/herdr` or `/usr/local/bin/herdr`.
- Status: herdr's `working`, `blocked`, `done` and `idle` map to the same states. `unknown` and any new
  value show as idle. herdr gives no time for a status, so the app notes when it first sees a change;
  an agent already in a state at launch counts from "unknown time" and isn't news.
- The "you" lane follows herdr's focused workspace while a terminal app (iTerm2, Ghostty, Terminal,
  kitty, WezTerm, Alacritty, Warp) is in front. It can't tell which terminal window shows herdr.
- To force a source: `defaults write com.djnesmith.herdr-notch source terminal` (or `desktop`);
  `defaults delete com.djnesmith.herdr-notch source` goes back to automatic. `--dump` prints the source.
- history.json stores the same fields as upstream (no cwd, no terminal text).
- Files: `Sources/HerdrNotch/TerminalHerdr.swift` (new), `Store.swift`, `Model.swift` ("claude" shows
  as Claude Code), `main.swift`, `Package.swift` (test target), `Tests/HerdrNotchTests/TerminalHerdrTests.swift`
- Check: `swift test` passes. With terminal herdr running, `HerdrNotch --dump` prints `source: terminal`
  and counts its agents.

### 3. The menu bar beside the notch stays usable
The counters on each side of the notch (58 or 98 pt) are drawn over the menu bar. Upstream opened the
panel when the pointer rested on them, and the open panel took clicks across its whole width in the
menu bar row. That blocked the menu bar items next to the notch, such as the "<<" button for items
that don't fit. Now only the hardware notch opens the panel. While the pointer is over a counter,
the counters fold back into the notch so the menu bar under them shows; the closed window already
passes every click through. The open panel takes clicks only on itself, its detail card and the
notch-wide strip above it.
- Files: `Sources/HerdrNotch/Window.swift` (`Zones`, `tick`), `Store.swift` (`peek`), `NotchView.swift`,
  `Tests/HerdrNotchTests/ZonesTests.swift`
- Check: `swift test` passes. Rest the pointer on a menu bar item next to the notch: the counters fold
  away, the panel stays closed and the item works. Rest on the notch itself: the panel opens.
