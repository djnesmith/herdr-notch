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

### 3. Almost nothing over the menu bar while closed
Upstream draws counters (left of the notch), a small last-hour trace (right of it) and a one-line
announcement under it, over the menu bar. The right side hid the status icons next to the notch,
including macOS's "<<" button for icons that don't fit, and both sides opened the panel when the
pointer rested on them. Here the closed state
is the hardware notch and nothing else: the window is the notch's own rectangle, nothing is drawn
(the notch is the camera cutout, so nothing drawn there would show), and no status shows until the
panel opens, except for the "needs you" strip (#5) below the menu bar and one small mark left of the
notch (#6). Nothing is ever drawn right of the notch. Only the notch, or a click on the mark, opens the panel. The open panel floats below the menu bar and takes
clicks only on itself, its detail card and the notch-wide strip above it.
- Files: `Sources/HerdrNotch/NotchView.swift` (`RootView.size`), `Window.swift` (`Zones`, `smallFrame`,
  `tick`), `main.swift` (render size), `Tests/HerdrNotchTests/ZonesTests.swift`
- After an upstream merge, keep `RootView.size` returning the notch size while closed, whatever upstream
  adds to the closed view.
- Check: `swift test` passes (`testClosedNotchIsTheHardwareNotchWhateverTheAgentsDo`). With agents
  running, nothing shows right of the notch; status items and "<<" click normally; resting on the
  notch opens the panel.

### 4. App icon
Upstream ships no icon, so Finder, Spotlight and System Settings showed the generic app icon. The
fork's icon is original: a dark rounded square with the notch at its top edge and three dots in the
app's status colors. `Support/make-icon.swift` draws it; `Support/AppIcon.icns` is its output, which
`build.sh` copies into `Contents/Resources`, and `Support/Info.plist` names it (`CFBundleIconFile`).
- Rebuild the icon: `swift Support/make-icon.swift && iconutil -c icns Support/AppIcon.iconset -o Support/AppIcon.icns && rm -r Support/AppIcon.iconset`
- Files: `Support/make-icon.swift`, `Support/AppIcon.icns`, `Support/Info.plist`, `build.sh`
- Check: `ls "/Applications/Herdr Notch.app/Contents/Resources/AppIcon.icns"`; Finder shows the icon.

### 5. A "needs you" strip
The closed notch shows nothing (#3), so when an agent starts waiting on David a small strip drops in
below the menu bar, where the open panel sits, with one row per agent: "<space> needs you". Clicking a
row jumps there (the same `workspace focus` + `agent focus` as the panel). It goes after 5 s, but not
while the pointer is on it. Several at once share one strip (4 rows, then "and N more"). No sound.
- Trigger: an agent entering herdr's `blocked` state. herdr sets it from on-screen prompts (its built-in
  rules include `permission_prompt`, `question_prompt`, `trust_prompt`, `approval_prompt`,
  `tool_permission`). `done`, `idle`, `working` and `unknown` never fire. Once per transition: no
  repeat while it stays blocked; again only after it leaves and comes back. Agents already blocked when
  the app starts don't fire.
- Not for the space in front of you: herdr's focused workspace while a terminal app is in front. If
  focus can't be read (another app in front), it shows.
- Only agents in `herdr agent list` can fire. Workspaces that only view another machine over ssh (they
  read `unknown`) have no agents there, so they never fire.
- Nothing goes in the menu bar row: the strip's top edge is below it, and while it shows the window
  takes clicks only on the strip.
- Files: `Sources/HerdrNotch/NeedsYou.swift` (new), `Store.swift` (`strip`, `showStrip`), `Window.swift`
  (`stripTick`, `Zones.strip`), `NotchView.swift`, `Tests/HerdrNotchTests/NeedsYouTests.swift`
- Check: `swift test` passes.

### 6. A mark left of the notch
Nothing was drawn while closed (#3), so there was no sign the app was running. Upstream's left ear
(counts for waiting and working agents, 58-98 pt wide) comes back trimmed to one 8 pt dot in a 32 pt
strip flush against the notch's left edge, in the menu bar row. The dot is red with the number of
waiting agents while any agent is in herdr's `blocked` state, amber while any works, dim otherwise.
A click on it opens the panel; hovering the notch still does. Only its own 32 pt strip takes clicks.
- Nothing is drawn right of the notch, where the status icons and the "<<" overflow button live.
- App menus share the left side. A long menu runs up to the notch, and the mark sits above it, so it
  covers up to 32 pt of the last menu title's end, and clicks there open the panel. Upstream's wider ear
  did the same.
- Hidden while the panel is open, on a screen with no notch, and while the menu bar is hidden: when
  "always hide the menu bar" (`_HIHideMenuBar`) is on, or when a window covers the whole display, menu bar
  row included, which only full-screen apps and full-screen video do. It reads window bounds and layers
  only (`CGWindowListCopyWindowInfo`, no titles, no pixels), once a second and on every Space or app switch.
- Files: `Sources/HerdrNotch/LeftMark.swift` (new), `Window.swift` (`markTick`, `layoutForScreen`, `open`),
  `Tests/HerdrNotchTests/LeftMarkTests.swift`
- Check: `swift test` passes. The dot shows left of the notch; a click opens the panel; it is gone in a
  full-screen app.
