Read this before merging upstream. Every item must still work after the merge.

# Fork features

What `djnesmith/herdr-notch` changes from `advpropsys/herdr-notch`. The list comes from
`git log upstream/main..djnesmith`. Rule: every change adds its entry here and a line to the
fork block at the top of `README.md`, in the same commit.

Upstream has no tests. After a merge, run `./build.sh /Applications` and
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
