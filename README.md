# Herdr Notch

<!-- fork: djnesmith — one block, so upstream merges stay easy -->
## What this fork changes

`djnesmith/herdr-notch` changes upstream Herdr Notch. Details and checks are in
[FORK-FEATURES.md](FORK-FEATURES.md).

- **Signed with the fork's own identity** and the hardened runtime, bundle ID
  `com.djnesmith.herdr-notch`. Install with `./build.sh /Applications`.
- **Terminal herdr:** shows the agents running in the `herdr` TUI, not only the desktop app's. It
  picks whichever answers, terminal first; `defaults write com.djnesmith.herdr-notch source desktop`
  (or `terminal`) forces one. Still read and focus only.
- **Nothing over the menu bar while closed:** no counters or trace beside the notch; hover the notch
  to open the panel. Menu bar items next to the notch stay visible and clickable.
- **A "needs you" strip:** when an agent starts waiting on you in a space you're not looking at, a
  small strip shows below the menu bar for 5 s; click it to jump there.
- **An app icon** (upstream has none), drawn by `Support/make-icon.swift`.
- **A menu bar icon:** shows the app is running; click it to open the panel. A number beside it
  counts agents waiting on you. ⌘-drag it to move it.
<!-- /fork -->

Your [Herdr](https://herdr.dev) agents, in the MacBook notch. See what needs you, what is running and what just
finished, across every workspace and every machine, without switching windows.

This is an unofficial companion app. It is not made by or affiliated with the Herdr project.

![The open panel with a workspace's detail card](docs/list.png)

## What it shows

**Closed**, beside the notch:

- how many agents need you, and how long the oldest has been waiting
- how many are working
- how many finished since you last looked
- a mini trace of the last hour
- one line for a few seconds when an agent finishes or starts needing you

**Open**, when you rest the pointer on the notch:

- every workspace with agents, grouped by machine, most urgent first
- a selector to show one machine or all of them
- a detail card for the workspace under the pointer: its agents, and the last things the most urgent one said
- click a workspace or an agent to jump to it in Herdr

**Trace**, the panel's second view, laid out like a profiler:

![The trace view](docs/trace.png)

- a lane for you: which Herdr workspace you had in front of you, and when
- a lane per agent: red while it needs you, amber while it works, a thin blue trail once it has finished
- a white line under an agent's bar where your attention overlapped it
- helper agents as thinner lanes under the agent that started them
- sorted by what cost you the most: agents waiting on you first, longest wait on top

The screenshots are composites, not screen captures. What is written on the panels is drawn by the app itself
with invented data (`--render --demo`); the frosted glass, wallpaper and notch around it are illustrated, because
the app's live blur cannot be captured offscreen.

## Requirements

- macOS 13 or later. It is built for a MacBook with a notch; on other displays it sits at the top centre.
- Herdr installed, with its `hc` and `herdr-app` commands in `~/.local/bin` (where Herdr puts them).
- The Xcode command line tools to build: `xcode-select --install`.

## Install

```sh
git clone https://github.com/advpropsys/herdr-notch
cd herdr-notch
./build.sh
open ~/Applications/"Herdr Notch.app"
```

`./build.sh /Applications` installs somewhere else. The app has no Dock icon; quit it from the panel's footer.
To start it at login, add it under System Settings, General, Login Items.

## How it works

- **Statuses** come from `hc events --json`, which reports the terminals on this Mac and on every machine Herdr is
  connected to. The app asks every 3 seconds.
- **The detail card** reads the agent's terminal with `hc read` and rebuilds its hard-wrapped lines into paragraphs,
  leaving out borders, prompts, tool calls and status bars. This is a heuristic and will sometimes get a line wrong.
- **The trace** needs history, and Herdr only reports what each agent is doing now. So the app records every change
  itself, from the first time it runs, and keeps 24 hours in
  `~/Library/Application Support/Herdr Notch/history.json`.
- **Your lane** is sampled from `herdr-app status` every 3 seconds, and only while Herdr is the front app. Short
  visits can be missed, and time in other apps shows as a gap.
- **Jumping** to an agent runs `herdr-app do space.select` and `herdr-app do pane.focus`.

Nothing leaves your Mac: the app makes no network requests and only runs the two Herdr commands above.

## Limits

- "Waiting on another agent" is not a state Herdr reports. You read it from a parent's bar above its helpers' bars.
- Herdr does not expose token use, cost or progress, so the app shows none of them.
- The app is not signed with a developer certificate. You build it yourself, so macOS runs it without a warning.

## Development

```sh
swift build                                        # compile
.build/debug/HerdrNotch --dump                     # print what the notch would show
.build/debug/HerdrNotch --render docs --demo       # draw the views to PNG files with invented data
HERDR_NOTCH_OPEN=1 .build/debug/HerdrNotch         # run with the panel held open
```

| File | What it holds |
|---|---|
| `Model.swift` | agents, workspaces, machines |
| `Store.swift` | polling Herdr and the state every view reads |
| `Recorder.swift`, `Trace.swift` | recorded history and the trace built from it |
| `NotchView.swift`, `DetailCard.swift`, `TraceView.swift` | the views |
| `Design.swift` | sizes, colours, motion, the frosted surface |
| `Window.swift` | the borderless window and pointer tracking |
| `Demo.swift` | invented data for screenshots |

## Licence

MIT. See [LICENSE](LICENSE).
