# App Store marketing panels

Hero panels for the App Store listing, built as HTML and rendered by headless
Chrome at exactly the store's pixel size — no image editor, no rescaling step.
Everything is a variable, so copy and colour changes are seconds, not redraws.

## Where the captures live

    Current/          the shots that match the SHIPPING build
      iPhone-6.9/       1320x2868   + heroes/ (rendered panels)
      iPad-13/          2064x2752   + heroes/
      AppleWatch-Ultra/ 410x502
      Widgets/          pristine tiles from WidgetArtExporter, 4x
    Deprecated/       earlier versions, kept for reference only
      iPhone-6.9/  iPhone-6.5/  iPad-13/   (+ their heroes/)
      Raw/              the phone-dump folder: photos, artwork, video

A capture belongs in `Current/` only while it shows the build you would
ship today. Two kinds can only come from a REAL DEVICE, never from this
Mac: anything **landscape** (no Simulator.app here, and simctl has no
orientation command) and any **Home Screen** (widgets can't be arranged
headlessly). Both are in `Current/` now, supplied from Gidan and Lulu —
if they ever go stale, they have to be re-shot the same way.

`AppleWatch-41mm/` is a real Series 8 capture at 352x430, the store's
41mm size; `AppleWatch-Ultra/` is the 410x502 simulator set.

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
