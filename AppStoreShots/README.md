# App Store marketing panels

Hero panels for the App Store listing, built as HTML and rendered by headless
Chrome at exactly the store's pixel size — no image editor, no rescaling step.
Everything is a variable, so copy and colour changes are seconds, not redraws.

## Layout

- `make_panels.py` — single-device hero panels (one screenshot + headline).
- `make_family_panel.py` — the "Powered by iCloud." device-family panel
  (iPad + iPhone + Watch under one line).
- `render.sh` — renders every generated `.html` in a directory to PNG.

Captures and rendered panels are **not** tracked (large binaries); only these
generators are. Regenerate the panels from the captures in the sibling folders.

## Usage

```bash
# single-device heroes
python3 make_panels.py ./out dusk iphone69 && ./render.sh "$PWD/out" 1320 2868
python3 make_panels.py ./out dusk ipad13   && ./render.sh "$PWD/out" 2064 2752

# the device-family panel
python3 make_family_panel.py ./out dusk iphone69 && ./render.sh "$PWD/out" 1320 2868
python3 make_family_panel.py ./out dusk ipad13   && ./render.sh "$PWD/out" 2064 2752
```

`ground` is one of `canvas` / `midnight` / `dusk` / `brass` — dusk violet
(`#2E3A63`) is the shipped choice. Headline copy lives in the `DEVICES` /
`LAYOUTS` dicts at the top of each script.

Device frames take their aspect ratio from the PNG header of the capture they
contain, so swapping a portrait shot for a landscape one re-proportions the
frame automatically rather than squashing the image.

## Capturing screenshots

`xcrun simctl` with `DEVELOPER_DIR` pointed at Xcode-beta:

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcrun simctl create "EphShot-iPad13" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M4-8GB com.apple.CoreSimulator.SimRuntime.iOS-27-0
xcrun simctl boot <udid>
xcodebuild build -scheme Ephoemerous -destination "id=<udid>" -derivedDataPath /tmp/eph_dd
xcrun simctl install <udid> /tmp/eph_dd/Build/Products/Debug-iphonesimulator/Ephoemerous.app
xcrun simctl privacy <udid> grant location-always com.lorep.uk.Ephoemerous
xcrun simctl location <udid> set 51.5074,-0.1278          # London, so the sky is honest
xcrun simctl status_bar <udid> override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3
xcrun simctl launch <udid> com.lorep.uk.Ephoemerous
xcrun simctl io <udid> screenshot out.png
```

The watch app installs the same way onto an `Apple-Watch-Ultra-2-49mm` device
(scheme `EphoemerousWatch`, `Debug-watchsimulator`). Give it ~30s after launch
to build its star field before capturing.

**Known limitation:** this Mac has no `Simulator.app` (the Xcode-beta install
has no `Contents/Developer/Applications`), and headless `simctl` has no
orientation command. So a simulator cannot be rotated — landscape captures have
to come from a real device.
